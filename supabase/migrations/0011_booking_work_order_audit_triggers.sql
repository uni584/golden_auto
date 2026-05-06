-- Golden Auto - Booking and work order audit triggers (0011)
--
-- Scope:
--   * Trigger-audit for bookings INSERT/UPDATE.
--   * Trigger-audit for work_orders INSERT/UPDATE.
--   * Minimal metadata:
--       - INSERT: {}
--       - UPDATE: changed_fields (field names only)
--   * No snapshots, no free-text payloads.

create or replace function public.tg_audit_bookings_changes()
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
  -- Skip seed/superuser writes without authenticated actor context.
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
      'booking.created',
      'booking',
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
        'notes'
      ]) then
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
      'booking.updated',
      'booking',
      new.id,
      jsonb_build_object('changed_fields', to_jsonb(v_changed_fields)),
      null
    );
    return new;
  end if;

  return new;
end;
$fn$;

create or replace function public.tg_audit_work_orders_changes()
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
  -- Skip seed/superuser writes without authenticated actor context.
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
      'work_order.created',
      'work_order',
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
        'notes',
        'assigned_to_label'
      ]) then
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
      'work_order.updated',
      'work_order',
      new.id,
      jsonb_build_object('changed_fields', to_jsonb(v_changed_fields)),
      null
    );
    return new;
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_bookings_audit_events on public.bookings;
create trigger trg_bookings_audit_events
after insert or update on public.bookings
for each row execute function public.tg_audit_bookings_changes();

drop trigger if exists trg_work_orders_audit_events on public.work_orders;
create trigger trg_work_orders_audit_events
after insert or update on public.work_orders
for each row execute function public.tg_audit_work_orders_changes();
