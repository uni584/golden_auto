-- Golden Auto - Registration number write path foundation (not full crypto/KMS)
-- Phase: 0007
--
-- Goals:
--   * Centralize UPDATE of reg_number_ciphertext / reg_number_hash / reg_number_last4 via RPC.
--   * Block ad-hoc client UPDATE of those columns (RLS alone still allowed arbitrary payloads).
--   * Same role/workshop rules as vehicles_update_scoped (owner/admin; receptionist + workshop access).
--   * No plaintext registration numbers in this migration; no logging of sensitive values.
--
-- Not in this migration: encryption, KMS, Edge Functions, column REVOKE, INSERT hardening.

-- ---------------------------------------------------------------------------
-- Session flag: only update_vehicle_registration_fields() may change reg fields
-- ---------------------------------------------------------------------------

create or replace function public.tg_vehicles_reg_fields_guard()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;
  if old.reg_number_ciphertext is not distinct from new.reg_number_ciphertext
     and old.reg_number_hash is not distinct from new.reg_number_hash
     and old.reg_number_last4 is not distinct from new.reg_number_last4 then
    return new;
  end if;
  if coalesce(current_setting('app.vehicle_registration_internal_update', true), '') = '1' then
    return new;
  end if;
  raise exception 'vehicle registration fields must be updated via update_vehicle_registration_fields()'
    using errcode = 'check_violation';
end;
$$;

create trigger trg_vehicles_reg_fields_guard
before update on public.vehicles
for each row execute function public.tg_vehicles_reg_fields_guard();

-- ---------------------------------------------------------------------------
-- RPC: controlled update (placeholder-safe payload; real crypto belongs in backend later)
-- ---------------------------------------------------------------------------

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
end;
$fn$;

comment on function public.update_vehicle_registration_fields(uuid, text, bytea, varchar) is
  'Placeholder-safe update of vehicles reg_number_* columns. Does not encrypt or normalize; future backend/RPC should supply ciphertext+hash. Direct UPDATE of these columns is blocked by trg_vehicles_reg_fields_guard unless this GUC path is used.';

revoke all on function public.update_vehicle_registration_fields(uuid, text, bytea, varchar) from public;
revoke all on function public.update_vehicle_registration_fields(uuid, text, bytea, varchar) from anon;
grant execute on function public.update_vehicle_registration_fields(uuid, text, bytea, varchar) to authenticated;
