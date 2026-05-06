-- Golden Auto - Audit events foundation (0009)
--
-- Scope:
--   * Create append-only audit table with tenant/workshop scope.
--   * Enable RLS read model for owner/admin only.
--   * Add internal SECURITY DEFINER append function (not client-callable).
--   * Wire audit writes into:
--       - update_vehicle_registration_fields(...)
--       - create_receipt(...)
--   * No broad triggers across all tables in this migration.

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  workshop_id uuid references public.workshops(id) on delete set null,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  resource_type text not null,
  resource_id uuid not null,
  metadata jsonb not null default '{}'::jsonb,
  correlation_id text,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_events_tenant_created_at
  on public.audit_events (tenant_id, created_at desc);
create index if not exists idx_audit_events_resource
  on public.audit_events (resource_type, resource_id);
create index if not exists idx_audit_events_actor_user_id
  on public.audit_events (actor_user_id);
create index if not exists idx_audit_events_action
  on public.audit_events (action);

alter table public.audit_events enable row level security;

drop policy if exists audit_events_select_owner_admin on public.audit_events;
create policy audit_events_select_owner_admin
on public.audit_events
for select
to authenticated
using (
  public.current_user_is_active_tenant_member(tenant_id)
  and public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
);

create or replace function public.append_audit_event(
  p_tenant_id uuid,
  p_workshop_id uuid,
  p_actor_user_id uuid,
  p_action text,
  p_resource_type text,
  p_resource_id uuid,
  p_metadata jsonb default '{}'::jsonb,
  p_correlation_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id uuid;
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
begin
  if p_tenant_id is null or p_resource_id is null then
    raise exception 'invalid audit event context';
  end if;
  if p_action is null or btrim(p_action) = '' then
    raise exception 'invalid audit event action';
  end if;
  if p_resource_type is null or btrim(p_resource_type) = '' then
    raise exception 'invalid audit event resource type';
  end if;

  if p_workshop_id is not null and not exists (
    select 1
    from public.workshops w
    where w.id = p_workshop_id
      and w.tenant_id = p_tenant_id
  ) then
    raise exception 'invalid audit event context';
  end if;

  if jsonb_typeof(v_metadata) is distinct from 'object' then
    raise exception 'invalid audit metadata';
  end if;

  if v_metadata ?| array[
    'reg_number',
    'registration_number',
    'reg_number_ciphertext',
    'reg_number_hash',
    'reg_number_last4',
    'token',
    'access_token',
    'refresh_token',
    'password',
    'secret'
  ] then
    raise exception 'sensitive metadata keys are not allowed';
  end if;

  insert into public.audit_events (
    tenant_id,
    workshop_id,
    actor_user_id,
    action,
    resource_type,
    resource_id,
    metadata,
    correlation_id
  )
  values (
    p_tenant_id,
    p_workshop_id,
    p_actor_user_id,
    btrim(p_action),
    btrim(p_resource_type),
    p_resource_id,
    v_metadata,
    p_correlation_id
  )
  returning id into v_id;

  return v_id;
end;
$fn$;

comment on function public.append_audit_event(uuid, uuid, uuid, text, text, uuid, jsonb, text) is
  'Internal append-only audit helper. Not exposed for direct client use.';

revoke all on function public.append_audit_event(uuid, uuid, uuid, text, text, uuid, jsonb, text) from public;
revoke all on function public.append_audit_event(uuid, uuid, uuid, text, text, uuid, jsonb, text) from anon;
revoke all on function public.append_audit_event(uuid, uuid, uuid, text, text, uuid, jsonb, text) from authenticated;

create or replace function public.update_vehicle_registration_fields(
  p_vehicle_id uuid,
  p_reg_number_ciphertext text,
  p_reg_number_hash bytea,
  p_reg_number_last4 varchar(4)
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_tenant_id uuid;
  v_workshop_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_reg_number_ciphertext is null or btrim(p_reg_number_ciphertext) = '' then
    raise exception 'invalid registration payload';
  end if;
  if p_reg_number_hash is null then
    raise exception 'invalid registration payload';
  end if;

  select v.tenant_id, v.workshop_id
    into v_tenant_id, v_workshop_id
  from public.vehicles v
  where v.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'vehicle not found';
  end if;

  if not public.current_user_is_active_tenant_member(v_tenant_id) then
    raise exception 'not authorized';
  end if;

  if not (
    public.current_user_has_tenant_role(v_tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(v_tenant_id, array['receptionist']::text[])
      and v_workshop_id is not null
      and public.current_user_has_workshop_access(v_tenant_id, v_workshop_id)
    )
  ) then
    raise exception 'not authorized';
  end if;

  if exists (
    select 1
    from public.vehicles v
    where v.tenant_id = v_tenant_id
      and v.reg_number_hash = p_reg_number_hash
      and v.id <> p_vehicle_id
  ) then
    raise exception 'registration hash conflict';
  end if;

  perform set_config('app.vehicle_registration_internal_update', '1', true);
  begin
    update public.vehicles
    set
      reg_number_ciphertext = p_reg_number_ciphertext,
      reg_number_hash = p_reg_number_hash,
      reg_number_last4 = p_reg_number_last4
    where id = p_vehicle_id;
    perform set_config('app.vehicle_registration_internal_update', '', true);
  exception
    when others then
      perform set_config('app.vehicle_registration_internal_update', '', true);
      raise;
  end;

  perform public.append_audit_event(
    v_tenant_id,
    v_workshop_id,
    auth.uid(),
    'vehicle.registration_updated',
    'vehicle',
    p_vehicle_id,
    jsonb_build_object(
      'changed_fields',
      to_jsonb(array['reg_number_ciphertext', 'reg_number_hash', 'reg_number_last4']::text[])
    ),
    null
  );
end;
$fn$;

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

  perform public.append_audit_event(
    p_tenant_id,
    p_workshop_id,
    auth.uid(),
    'receipt.created',
    'receipt',
    v_id,
    jsonb_build_object(
      'payment_status', p_payment_status,
      'currency', v_currency
    ),
    null
  );

  return v_id;
end;
$fn$;
