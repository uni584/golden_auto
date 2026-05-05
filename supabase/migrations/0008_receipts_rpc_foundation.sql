-- Golden Auto - Receipts RPC foundation (0008)
--
-- Goals:
--   * Single server-side path to INSERT receipts; no broad INSERT/UPDATE RLS on receipts.
--   * Owner/admin only (active tenant + workshop access); not receptionist/mechanic/viewer in this phase.
--   * Validate tenant/workshop and FK targets (customer, vehicle, optional booking/work_order/quote).
--   * Non-negative amounts; total_amount = subtotal_amount + vat_amount; create only payment_status = unpaid.
--   * created_by / updated_by always set from auth.uid() (not caller-supplied).
--
-- Not in this migration: receipt UPDATE/void/refund, DELETE policies, Edge/backend, frontend.
--
-- RLS: endast SELECT-policy + explicit neka-UPDATE/DELETE policies (USING(...) anropar funktion som
-- alltid RAISE). Annars kan UPDATE utan tillaten rad ge 0 rows utan fel — policies utvarderas pa
-- synliga rader och stoppar klienten. INSERT-policy saknas (klient-INSERT nekas). SECURITY DEFINER
-- create_receipt bypassar RLS vid INSERT.

create or replace function public.receipts_deny_client_update()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $deny$
begin
  raise exception 'receipt updates must use a future RPC; direct client update is not allowed'
    using errcode = 'check_violation';
end;
$deny$;

create or replace function public.receipts_deny_client_delete()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $deny$
begin
  raise exception 'receipt delete is not allowed for client sessions'
    using errcode = 'check_violation';
end;
$deny$;

revoke all on function public.receipts_deny_client_update() from public;
revoke all on function public.receipts_deny_client_update() from anon;
grant execute on function public.receipts_deny_client_update() to authenticated;

revoke all on function public.receipts_deny_client_delete() from public;
revoke all on function public.receipts_deny_client_delete() from anon;
grant execute on function public.receipts_deny_client_delete() to authenticated;

drop policy if exists receipts_deny_client_update on public.receipts;
create policy receipts_deny_client_update
on public.receipts
for update
to authenticated
using (public.receipts_deny_client_update());

drop policy if exists receipts_deny_client_delete on public.receipts;
create policy receipts_deny_client_delete
on public.receipts
for delete
to authenticated
using (public.receipts_deny_client_delete());

create or replace function public.create_receipt(
  p_tenant_id uuid,
  p_workshop_id uuid,
  p_customer_id uuid,
  p_vehicle_id uuid,
  p_receipt_number text,
  p_subtotal_amount numeric(12,2) default 0,
  p_vat_amount numeric(12,2) default 0,
  p_total_amount numeric(12,2) default 0,
  p_payment_status text default 'unpaid',
  p_currency text default 'SEK',
  p_booking_id uuid default null,
  p_work_order_id uuid default null,
  p_quote_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id uuid;
  v_currency char(3);
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_receipt_number is null or btrim(p_receipt_number) = '' then
    raise exception 'invalid receipt number';
  end if;

  if p_currency is null or length(trim(p_currency)) <> 3 then
    raise exception 'invalid currency';
  end if;
  v_currency := rtrim(ltrim(upper(p_currency)))::char(3);

  if p_subtotal_amount < 0 or p_vat_amount < 0 or p_total_amount < 0 then
    raise exception 'amounts must be non-negative';
  end if;

  if p_total_amount <> p_subtotal_amount + p_vat_amount then
    raise exception 'total must equal subtotal plus vat';
  end if;

  if p_payment_status is distinct from 'unpaid' then
    raise exception 'invalid payment status for create';
  end if;

  if not public.current_user_is_active_tenant_member(p_tenant_id) then
    raise exception 'not authorized';
  end if;

  if not public.current_user_has_tenant_role(p_tenant_id, array['owner', 'admin']::text[]) then
    raise exception 'not authorized';
  end if;

  if not public.current_user_has_workshop_access(p_tenant_id, p_workshop_id) then
    raise exception 'not authorized';
  end if;

  if not exists (
    select 1
    from public.workshops w
    where w.id = p_workshop_id
      and w.tenant_id = p_tenant_id
  ) then
    raise exception 'invalid receipt context';
  end if;

  if not exists (
    select 1
    from public.customers c
    where c.id = p_customer_id
      and c.tenant_id = p_tenant_id
      and c.workshop_id = p_workshop_id
  ) then
    raise exception 'invalid receipt context';
  end if;

  if not exists (
    select 1
    from public.vehicles v
    where v.id = p_vehicle_id
      and v.tenant_id = p_tenant_id
      and v.workshop_id = p_workshop_id
      and v.customer_id = p_customer_id
  ) then
    raise exception 'invalid receipt context';
  end if;

  if p_booking_id is not null then
    if not exists (
      select 1
      from public.bookings b
      where b.id = p_booking_id
        and b.tenant_id = p_tenant_id
        and b.workshop_id = p_workshop_id
        and b.customer_id = p_customer_id
        and b.vehicle_id = p_vehicle_id
    ) then
      raise exception 'invalid receipt context';
    end if;
  end if;

  if p_work_order_id is not null then
    if not exists (
      select 1
      from public.work_orders wo
      where wo.id = p_work_order_id
        and wo.tenant_id = p_tenant_id
        and wo.workshop_id = p_workshop_id
        and wo.customer_id = p_customer_id
        and wo.vehicle_id = p_vehicle_id
    ) then
      raise exception 'invalid receipt context';
    end if;
  end if;

  if p_quote_id is not null then
    if not exists (
      select 1
      from public.quotes q
      where q.id = p_quote_id
        and q.tenant_id = p_tenant_id
        and q.workshop_id = p_workshop_id
        and q.customer_id = p_customer_id
        and q.vehicle_id = p_vehicle_id
    ) then
      raise exception 'invalid receipt context';
    end if;
  end if;

  -- receipts har ej booking_id i schema (0001); validera valfri bokning endast mot ovriga FK.
  insert into public.receipts (
    tenant_id,
    workshop_id,
    customer_id,
    vehicle_id,
    receipt_number,
    payment_status,
    currency,
    subtotal_amount,
    vat_amount,
    total_amount,
    work_order_id,
    quote_id,
    metadata,
    created_by,
    updated_by
  )
  values (
    p_tenant_id,
    p_workshop_id,
    p_customer_id,
    p_vehicle_id,
    btrim(p_receipt_number),
    p_payment_status,
    v_currency,
    p_subtotal_amount,
    p_vat_amount,
    p_total_amount,
    p_work_order_id,
    p_quote_id,
    coalesce(p_metadata, '{}'::jsonb),
    auth.uid(),
    auth.uid()
  )
  returning id into v_id;

  return v_id;
end;
$fn$;

comment on function public.create_receipt(
  uuid, uuid, uuid, uuid, text,
  numeric, numeric, numeric, text, text,
  uuid, uuid, uuid, jsonb
) is
  'Foundation RPC: INSERT receipt as owner/admin with workshop access. No client INSERT/UPDATE on receipts; only payment_status unpaid at create. Future: void/update RPCs, stricter product rules.';

revoke all on function public.create_receipt(
  uuid, uuid, uuid, uuid, text,
  numeric, numeric, numeric, text, text,
  uuid, uuid, uuid, jsonb
) from public;

revoke all on function public.create_receipt(
  uuid, uuid, uuid, uuid, text,
  numeric, numeric, numeric, text, text,
  uuid, uuid, uuid, jsonb
) from anon;

grant execute on function public.create_receipt(
  uuid, uuid, uuid, uuid, text,
  numeric, numeric, numeric, text, text,
  uuid, uuid, uuid, jsonb
) to authenticated;
