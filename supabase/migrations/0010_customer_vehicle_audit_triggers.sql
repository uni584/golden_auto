-- Golden Auto - Customer and vehicle audit triggers (0010)
--
-- Scope:
--   * Add trigger-based audit for customers INSERT/UPDATE.
--   * Add trigger-based audit for vehicles INSERT/UPDATE.
--   * Keep registration field audit primary in update_vehicle_registration_fields RPC.
--   * Avoid vehicle.updated audit rows when only reg_number_* (and system audit cols) change.

create or replace function public.tg_audit_customers_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_changed_fields text[] := array[]::text[];
  v_key text;
  v_actor uuid := auth.uid();
begin
  -- Seed/superuser operations without auth context should not produce app audit rows.
  if v_actor is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    perform public.append_audit_event(
      new.tenant_id,
      new.workshop_id,
      v_actor,
      'customer.created',
      'customer',
      new.id,
      '{}'::jsonb,
      null
    );
    return new;
  end if;

  if tg_op = 'UPDATE' then
    for v_key in
      select key
      from jsonb_object_keys(to_jsonb(new)) as key
    loop
      if v_key = any(array['created_at', 'updated_at', 'created_by', 'updated_by']) then
        continue;
      end if;
      if (to_jsonb(old) -> v_key) is distinct from (to_jsonb(new) -> v_key) then
        v_changed_fields := array_append(v_changed_fields, v_key);
      end if;
    end loop;

    if coalesce(array_length(v_changed_fields, 1), 0) = 0 then
      return new;
    end if;

    perform public.append_audit_event(
      new.tenant_id,
      new.workshop_id,
      v_actor,
      'customer.updated',
      'customer',
      new.id,
      jsonb_build_object('changed_fields', to_jsonb(v_changed_fields)),
      null
    );
    return new;
  end if;

  return new;
end;
$fn$;

create or replace function public.tg_audit_vehicles_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_changed_fields text[] := array[]::text[];
  v_key text;
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    perform public.append_audit_event(
      new.tenant_id,
      new.workshop_id,
      v_actor,
      'vehicle.created',
      'vehicle',
      new.id,
      '{}'::jsonb,
      null
    );
    return new;
  end if;

  if tg_op = 'UPDATE' then
    for v_key in
      select key
      from jsonb_object_keys(to_jsonb(new)) as key
    loop
      if v_key = any(array[
        'created_at',
        'updated_at',
        'created_by',
        'updated_by',
        'reg_number_ciphertext',
        'reg_number_hash',
        'reg_number_last4'
      ]) then
        continue;
      end if;
      if (to_jsonb(old) -> v_key) is distinct from (to_jsonb(new) -> v_key) then
        v_changed_fields := array_append(v_changed_fields, v_key);
      end if;
    end loop;

    -- If only registration/system fields changed, skip vehicle.updated.
    if coalesce(array_length(v_changed_fields, 1), 0) = 0 then
      return new;
    end if;

    perform public.append_audit_event(
      new.tenant_id,
      new.workshop_id,
      v_actor,
      'vehicle.updated',
      'vehicle',
      new.id,
      jsonb_build_object('changed_fields', to_jsonb(v_changed_fields)),
      null
    );
    return new;
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_customers_audit_events on public.customers;
create trigger trg_customers_audit_events
after insert or update on public.customers
for each row execute function public.tg_audit_customers_changes();

drop trigger if exists trg_vehicles_audit_events on public.vehicles;
create trigger trg_vehicles_audit_events
after insert or update on public.vehicles
for each row execute function public.tg_audit_vehicles_changes();
