-- Golden Auto - RLS helper functions and initial SELECT policies
-- Phase: 0003
-- Notes:
--   * Adds reusable helper functions for future RLS policies.
--   * Enables RLS and adds SELECT-only policies.
--   * No INSERT/UPDATE/DELETE policies in this migration.

create or replace function public.current_user_is_active_tenant_member(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and exists (
      select 1
      from public.tenant_members tm
      where tm.tenant_id = p_tenant_id
        and tm.user_id = auth.uid()
        and tm.membership_status = 'active'
    );
$$;

create or replace function public.current_user_has_tenant_role(p_tenant_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and exists (
      select 1
      from public.tenant_members tm
      where tm.tenant_id = p_tenant_id
        and tm.user_id = auth.uid()
        and tm.membership_status = 'active'
        and tm.role = any(coalesce(p_roles, array[]::text[]))
    );
$$;

create or replace function public.current_user_has_workshop_access(p_tenant_id uuid, p_workshop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and exists (
      select 1
      from public.workshop_members wm
      where wm.tenant_id = p_tenant_id
        and wm.workshop_id = p_workshop_id
        and wm.user_id = auth.uid()
        and wm.membership_status = 'active'
    );
$$;

create or replace function public.current_user_has_workshop_role(
  p_tenant_id uuid,
  p_workshop_id uuid,
  p_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and exists (
      select 1
      from public.workshop_members wm
      where wm.tenant_id = p_tenant_id
        and wm.workshop_id = p_workshop_id
        and wm.user_id = auth.uid()
        and wm.membership_status = 'active'
        and wm.role = any(coalesce(p_roles, array[]::text[]))
    );
$$;

grant execute on function public.current_user_is_active_tenant_member(uuid) to authenticated;
grant execute on function public.current_user_has_tenant_role(uuid, text[]) to authenticated;
grant execute on function public.current_user_has_workshop_access(uuid, uuid) to authenticated;
grant execute on function public.current_user_has_workshop_role(uuid, uuid, text[]) to authenticated;

alter table public.tenants enable row level security;
alter table public.workshops enable row level security;
alter table public.profiles enable row level security;
alter table public.tenant_members enable row level security;
alter table public.workshop_members enable row level security;
alter table public.customers enable row level security;
alter table public.vehicles enable row level security;
alter table public.bookings enable row level security;
alter table public.work_orders enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_items enable row level security;
alter table public.receipts enable row level security;
alter table public.tire_hotel enable row level security;

drop policy if exists tenant_select_scoped on public.tenants;
create policy tenant_select_scoped
on public.tenants
for select
to authenticated
using (public.current_user_is_active_tenant_member(id));

drop policy if exists workshops_select_scoped on public.workshops;
create policy workshops_select_scoped
on public.workshops
for select
to authenticated
using (public.current_user_has_workshop_access(tenant_id, id));

drop policy if exists profiles_select_scoped on public.profiles;
create policy profiles_select_scoped
on public.profiles
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.tenant_members tm_target
    join public.tenant_members tm_self
      on tm_self.tenant_id = tm_target.tenant_id
    where tm_target.user_id = profiles.user_id
      and tm_target.membership_status = 'active'
      and tm_self.user_id = auth.uid()
      and tm_self.membership_status = 'active'
  )
);

drop policy if exists tenant_members_select_scoped on public.tenant_members;
create policy tenant_members_select_scoped
on public.tenant_members
for select
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
);

drop policy if exists workshop_members_select_scoped on public.workshop_members;
create policy workshop_members_select_scoped
on public.workshop_members
for select
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_has_workshop_role(tenant_id, workshop_id, array['owner', 'admin']::text[])
  or public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
);

drop policy if exists customers_select_scoped on public.customers;
create policy customers_select_scoped
on public.customers
for select
to authenticated
using (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    workshop_id is null
    or public.current_user_has_workshop_access(tenant_id, workshop_id)
  )
);

drop policy if exists vehicles_select_scoped on public.vehicles;
create policy vehicles_select_scoped
on public.vehicles
for select
to authenticated
using (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    workshop_id is null
    or public.current_user_has_workshop_access(tenant_id, workshop_id)
  )
);

drop policy if exists bookings_select_scoped on public.bookings;
create policy bookings_select_scoped
on public.bookings
for select
to authenticated
using (
  public.current_user_has_workshop_access(tenant_id, workshop_id)
);

drop policy if exists work_orders_select_scoped on public.work_orders;
create policy work_orders_select_scoped
on public.work_orders
for select
to authenticated
using (
  public.current_user_has_workshop_access(tenant_id, workshop_id)
);

drop policy if exists quotes_select_scoped on public.quotes;
create policy quotes_select_scoped
on public.quotes
for select
to authenticated
using (
  public.current_user_has_workshop_access(tenant_id, workshop_id)
);

drop policy if exists quote_items_select_scoped on public.quote_items;
create policy quote_items_select_scoped
on public.quote_items
for select
to authenticated
using (
  exists (
    select 1
    from public.quotes q
    where q.id = quote_items.quote_id
      and q.tenant_id = quote_items.tenant_id
      and public.current_user_has_workshop_access(q.tenant_id, q.workshop_id)
  )
);

drop policy if exists receipts_select_scoped on public.receipts;
create policy receipts_select_scoped
on public.receipts
for select
to authenticated
using (
  public.current_user_has_workshop_access(tenant_id, workshop_id)
);

drop policy if exists tire_hotel_select_scoped on public.tire_hotel;
create policy tire_hotel_select_scoped
on public.tire_hotel
for select
to authenticated
using (
  public.current_user_has_workshop_access(tenant_id, workshop_id)
);
