-- Golden Auto - Quote, quote_item and tire_hotel audit triggers (0012)
--
-- Scope:
--   * Trigger-audit for quotes INSERT/UPDATE.
--   * Trigger-audit for quote_items INSERT/UPDATE (tenant/workshop from parent quote).
--   * Trigger-audit for tire_hotel INSERT/UPDATE.
--   * Minimal metadata:
--       - INSERT: {}
--       - UPDATE: changed_fields (field names only)
--   * No snapshots, no free-text payloads.

create or replace function public.tg_audit_quotes_changes()
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
      'quote.created',
      'quote',
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
      'quote.updated',
      'quote',
      new.id,
      jsonb_build_object('changed_fields', to_jsonb(v_changed_fields)),
      null
    );
    return new;
  end if;

  return new;
end;
$fn$;

create or replace function public.tg_audit_quote_items_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_tenant_id uuid;
  v_workshop_id uuid;
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

  select q.tenant_id, q.workshop_id
    into v_tenant_id, v_workshop_id
  from public.quotes q
  where q.id = coalesce(new.quote_id, old.quote_id);

  if v_tenant_id is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    perform public.append_audit_event(
      v_tenant_id,
      v_workshop_id,
      v_actor,
      'quote_item.created',
      'quote_item',
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
        'description'
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
      v_tenant_id,
      v_workshop_id,
      v_actor,
      'quote_item.updated',
      'quote_item',
      new.id,
      jsonb_build_object('changed_fields', to_jsonb(v_changed_fields)),
      null
    );
    return new;
  end if;

  return new;
end;
$fn$;

create or replace function public.tg_audit_tire_hotel_changes()
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
      'tire_hotel.created',
      'tire_hotel',
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
        'tire_brand_model',
        'tire_dimension',
        'rack'
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
      'tire_hotel.updated',
      'tire_hotel',
      new.id,
      jsonb_build_object('changed_fields', to_jsonb(v_changed_fields)),
      null
    );
    return new;
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_quotes_audit_events on public.quotes;
create trigger trg_quotes_audit_events
after insert or update on public.quotes
for each row execute function public.tg_audit_quotes_changes();

drop trigger if exists trg_quote_items_audit_events on public.quote_items;
create trigger trg_quote_items_audit_events
after insert or update on public.quote_items
for each row execute function public.tg_audit_quote_items_changes();

drop trigger if exists trg_tire_hotel_audit_events on public.tire_hotel;
create trigger trg_tire_hotel_audit_events
after insert or update on public.tire_hotel
for each row execute function public.tg_audit_tire_hotel_changes();
