-- Golden Auto - Initial RLS write policies (limited scope)
-- Phase: 0005
-- Tables: profiles, customers, bookings, quotes, quote_items
-- No DELETE policies. No writes to membership, vehicles, receipts, etc.

-- ---------------------------------------------------------------------------
-- Triggers: immutable tenant_id (prevents cross-tenant row moves on UPDATE)
-- ---------------------------------------------------------------------------

create or replace function public.tg_reject_tenant_id_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'update' and new.tenant_id is distinct from old.tenant_id then
    raise exception 'tenant_id cannot be changed';
  end if;
  return new;
end;
$$;

create trigger trg_customers_reject_tenant_change
before update on public.customers
for each row execute function public.tg_reject_tenant_id_change();

create trigger trg_bookings_reject_tenant_change
before update on public.bookings
for each row execute function public.tg_reject_tenant_id_change();

create trigger trg_quotes_reject_tenant_change
before update on public.quotes
for each row execute function public.tg_reject_tenant_id_change();

create trigger trg_quote_items_reject_tenant_change
before update on public.quote_items
for each row execute function public.tg_reject_tenant_id_change();

-- ---------------------------------------------------------------------------
-- Triggers: created_by / updated_by from auth.uid() (no client spoofing)
-- ---------------------------------------------------------------------------

create or replace function public.tg_set_audit_actor()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'insert' then
    new.created_by := auth.uid();
    new.updated_by := auth.uid();
  elsif tg_op = 'update' then
    new.created_by := old.created_by;
    new.updated_by := auth.uid();
  end if;
  return new;
end;
$$;

create trigger trg_customers_audit_actor
before insert or update on public.customers
for each row execute function public.tg_set_audit_actor();

create trigger trg_bookings_audit_actor
before insert or update on public.bookings
for each row execute function public.tg_set_audit_actor();

create trigger trg_quotes_audit_actor
before insert or update on public.quotes
for each row execute function public.tg_set_audit_actor();

-- quote_items has no created_by/updated_by columns in 0001

-- ---------------------------------------------------------------------------
-- profiles: self UPDATE only
-- ---------------------------------------------------------------------------

drop policy if exists profiles_update_self on public.profiles;

create policy profiles_update_self
on public.profiles
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- customers: owner/admin/receptionist; receptionist requires workshop_id + access
-- ---------------------------------------------------------------------------

drop policy if exists customers_insert_scoped on public.customers;
drop policy if exists customers_update_scoped on public.customers;

create policy customers_insert_scoped
on public.customers
for insert
to authenticated
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and workshop_id is not null
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
  )
  and (
    workshop_id is null
    or exists (
      select 1
      from public.workshops w
      where w.id = workshop_id
        and w.tenant_id = tenant_id
    )
  )
);

create policy customers_update_scoped
on public.customers
for update
to authenticated
using (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and workshop_id is not null
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
  )
)
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and workshop_id is not null
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
  )
  and (
    workshop_id is null
    or exists (
      select 1
      from public.workshops w
      where w.id = workshop_id
        and w.tenant_id = tenant_id
    )
  )
);

-- ---------------------------------------------------------------------------
-- bookings: owner/admin/receptionist; workshop must belong to tenant; FKs consistent
-- ---------------------------------------------------------------------------

drop policy if exists bookings_insert_scoped on public.bookings;
drop policy if exists bookings_update_scoped on public.bookings;

create policy bookings_insert_scoped
on public.bookings
for insert
to authenticated
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
  )
  and exists (
    select 1
    from public.workshops w
    where w.id = workshop_id
      and w.tenant_id = tenant_id
  )
  and (
    customer_id is null
    or exists (
      select 1
      from public.customers c
      where c.id = customer_id
        and c.tenant_id = tenant_id
    )
  )
  and (
    vehicle_id is null
    or exists (
      select 1
      from public.vehicles v
      where v.id = vehicle_id
        and v.tenant_id = tenant_id
    )
  )
);

create policy bookings_update_scoped
on public.bookings
for update
to authenticated
using (
  public.current_user_has_workshop_access(tenant_id, workshop_id)
)
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
  )
  and exists (
    select 1
    from public.workshops w
    where w.id = workshop_id
      and w.tenant_id = tenant_id
  )
  and (
    customer_id is null
    or exists (
      select 1
      from public.customers c
      where c.id = customer_id
        and c.tenant_id = tenant_id
    )
  )
  and (
    vehicle_id is null
    or exists (
      select 1
      from public.vehicles v
      where v.id = vehicle_id
        and v.tenant_id = tenant_id
    )
  )
);

-- ---------------------------------------------------------------------------
-- quotes: owner/admin/receptionist; link rows must match tenant + workshop
-- ---------------------------------------------------------------------------

drop policy if exists quotes_insert_scoped on public.quotes;
drop policy if exists quotes_update_scoped on public.quotes;

create policy quotes_insert_scoped
on public.quotes
for insert
to authenticated
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
  )
  and exists (
    select 1
    from public.workshops w
    where w.id = workshop_id
      and w.tenant_id = tenant_id
  )
  and exists (
    select 1
    from public.customers c
    where c.id = customer_id
      and c.tenant_id = tenant_id
  )
  and exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and v.tenant_id = tenant_id
  )
  and (
    booking_id is null
    or exists (
      select 1
      from public.bookings b
      where b.id = booking_id
        and b.tenant_id = tenant_id
        and b.workshop_id = quotes.workshop_id
    )
  )
);

create policy quotes_update_scoped
on public.quotes
for update
to authenticated
using (
  public.current_user_has_workshop_access(tenant_id, workshop_id)
)
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
  )
  and exists (
    select 1
    from public.workshops w
    where w.id = workshop_id
      and w.tenant_id = tenant_id
  )
  and exists (
    select 1
    from public.customers c
    where c.id = customer_id
      and c.tenant_id = tenant_id
  )
  and exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and v.tenant_id = tenant_id
  )
  and (
    booking_id is null
    or exists (
      select 1
      from public.bookings b
      where b.id = booking_id
        and b.tenant_id = tenant_id
        and b.workshop_id = quotes.workshop_id
    )
  )
);

-- ---------------------------------------------------------------------------
-- quote_items: write only with parent quote in same tenant; role via parent workshop
-- ---------------------------------------------------------------------------

drop policy if exists quote_items_insert_scoped on public.quote_items;
drop policy if exists quote_items_update_scoped on public.quote_items;

create policy quote_items_insert_scoped
on public.quote_items
for insert
to authenticated
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and exists (
    select 1
    from public.quotes q
    where q.id = quote_id
      and q.tenant_id = quote_items.tenant_id
  )
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and exists (
        select 1
        from public.quotes q
        where q.id = quote_id
          and q.tenant_id = quote_items.tenant_id
          and public.current_user_has_workshop_access(q.tenant_id, q.workshop_id)
      )
    )
  )
);

create policy quote_items_update_scoped
on public.quote_items
for update
to authenticated
using (
  exists (
    select 1
    from public.quotes q
    where q.id = quote_items.quote_id
      and q.tenant_id = quote_items.tenant_id
      and (
        public.current_user_has_tenant_role(q.tenant_id, array['owner', 'admin']::text[])
        or (
          public.current_user_has_tenant_role(q.tenant_id, array['receptionist']::text[])
          and public.current_user_has_workshop_access(q.tenant_id, q.workshop_id)
        )
      )
  )
)
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and exists (
    select 1
    from public.quotes q
    where q.id = quote_id
      and q.tenant_id = quote_items.tenant_id
  )
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and exists (
        select 1
        from public.quotes q
        where q.id = quote_id
          and q.tenant_id = quote_items.tenant_id
          and public.current_user_has_workshop_access(q.tenant_id, q.workshop_id)
      )
    )
  )
);
