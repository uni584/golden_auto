-- Golden Auto - Operational RLS write policies (vehicles, work_orders, tire_hotel)
-- Phase: 0006
-- No DELETE policies. No receipts, membership, or tenant/workshop admin writes.

-- ---------------------------------------------------------------------------
-- Triggers: immutable tenant_id on UPDATE
-- ---------------------------------------------------------------------------

create trigger trg_vehicles_reject_tenant_change
before update on public.vehicles
for each row execute function public.tg_reject_tenant_id_change();

create trigger trg_work_orders_reject_tenant_change
before update on public.work_orders
for each row execute function public.tg_reject_tenant_id_change();

create trigger trg_tire_hotel_reject_tenant_change
before update on public.tire_hotel
for each row execute function public.tg_reject_tenant_id_change();

-- ---------------------------------------------------------------------------
-- Triggers: created_by / updated_by from auth.uid()
-- ---------------------------------------------------------------------------

create trigger trg_vehicles_audit_actor
before insert or update on public.vehicles
for each row execute function public.tg_set_audit_actor();

create trigger trg_work_orders_audit_actor
before insert or update on public.work_orders
for each row execute function public.tg_set_audit_actor();

create trigger trg_tire_hotel_audit_actor
before insert or update on public.tire_hotel
for each row execute function public.tg_set_audit_actor();

-- ---------------------------------------------------------------------------
-- vehicles: owner/admin/receptionist; receptionist requires workshop_id + access
-- mechanic/viewer: no direct client writes (sensitive reg fields / PII risk)
-- ---------------------------------------------------------------------------

drop policy if exists vehicles_insert_scoped on public.vehicles;
drop policy if exists vehicles_update_scoped on public.vehicles;

create policy vehicles_insert_scoped
on public.vehicles
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
  and exists (
    select 1
    from public.customers c
    where c.id = customer_id
      and c.tenant_id = tenant_id
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

create policy vehicles_update_scoped
on public.vehicles
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
  and exists (
    select 1
    from public.customers c
    where c.id = customer_id
      and c.tenant_id = tenant_id
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
-- work_orders: owner/admin tenant-wide; mechanic workshop-scoped
-- receptionist: no write (minimal privilege; operational WO handled by mechanics / admins)
-- ---------------------------------------------------------------------------

drop policy if exists work_orders_insert_scoped on public.work_orders;
drop policy if exists work_orders_update_scoped on public.work_orders;

create policy work_orders_insert_scoped
on public.work_orders
for insert
to authenticated
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['mechanic']::text[])
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
        and b.workshop_id = work_orders.workshop_id
    )
  )
);

create policy work_orders_update_scoped
on public.work_orders
for update
to authenticated
using (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['mechanic']::text[])
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
  )
)
with check (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['mechanic']::text[])
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
        and b.workshop_id = work_orders.workshop_id
    )
  )
);

-- ---------------------------------------------------------------------------
-- tire_hotel: owner/admin; receptionist + mechanic with workshop access
-- ---------------------------------------------------------------------------

drop policy if exists tire_hotel_insert_scoped on public.tire_hotel;
drop policy if exists tire_hotel_update_scoped on public.tire_hotel;

create policy tire_hotel_insert_scoped
on public.tire_hotel
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
    or (
      public.current_user_has_tenant_role(tenant_id, array['mechanic']::text[])
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
);

create policy tire_hotel_update_scoped
on public.tire_hotel
for update
to authenticated
using (
  public.current_user_is_active_tenant_member(tenant_id)
  and (
    public.current_user_has_tenant_role(tenant_id, array['owner', 'admin']::text[])
    or (
      public.current_user_has_tenant_role(tenant_id, array['receptionist']::text[])
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
    or (
      public.current_user_has_tenant_role(tenant_id, array['mechanic']::text[])
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
      and public.current_user_has_workshop_access(tenant_id, workshop_id)
    )
    or (
      public.current_user_has_tenant_role(tenant_id, array['mechanic']::text[])
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
);
