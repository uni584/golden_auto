-- RLS write policy tests for migration 0005 (synthetic data only)
--
-- Assumptions:
--   * Runs after migrations 0001–0005.
--   * Seed INSERTs run as session superuser (RLS bypass). DML tests use SET LOCAL ROLE authenticated.
--   * Receptionist write in 0005 requires BOTH:
--       - tenant_members.role = 'receptionist' AND membership_status = 'active'
--       - workshop_members with active access to the target workshop_id
--     (tenant role comes from tenant_members, not from workshop_members.role alone.)
--
-- Run:
--   npx supabase db reset
--   npx supabase test db

begin;

create extension if not exists pgtap with schema extensions;

select set_config('search_path', 'extensions, public, pg_temp', true);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function pg_temp.run_as(p_uid uuid, p_sql text)
returns void
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  execute p_sql;
  reset role;
exception
  when others then
    begin
      reset role;
    exception
      when others then null;
    end;
    raise;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Synthetic UUIDs (hex-only)
-- ---------------------------------------------------------------------------
-- tenant_a: 70000001-0000-4000-8000-000000000001
-- tenant_b: 70000002-0000-4000-8000-000000000002
-- ws_a1:    70100001-0000-4000-8000-000000000001
-- ws_a2:    70200001-0000-4000-8000-000000000002
-- ws_b1:    7b100001-0000-4000-8000-000000000001

-- ---------------------------------------------------------------------------
-- auth.users
-- ---------------------------------------------------------------------------
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  x.id,
  coalesce((select id from auth.instances limit 1), '00000000-0000-0000-0000-000000000000'::uuid),
  'authenticated', 'authenticated', x.email,
  crypt('fake-password-not-used', gen_salt('bf')),
  now(), '{}'::jsonb, '{}'::jsonb, now(), now()
from (
  values
    ('f7000001-0000-4000-8000-000000000001'::uuid, 'owner.a.write@example.test'),
    ('f7000002-0000-4000-8000-000000000001'::uuid, 'admin.a.write@example.test'),
    ('f7000003-0000-4000-8000-000000000001'::uuid, 'receptionist.a1.write@example.test'),
    ('f7000004-0000-4000-8000-000000000001'::uuid, 'mechanic.a1.write@example.test'),
    ('f7000005-0000-4000-8000-000000000001'::uuid, 'viewer.a2.write@example.test'),
    ('f70000b1-0000-4000-8000-000000000001'::uuid, 'owner.b.write@example.test'),
    ('e7000001-0000-4000-8000-000000000001'::uuid, 'no.membership.write@example.test'),
    ('a700eed1-0000-4000-8000-000000000001'::uuid, 'suspended.write@example.test'),
    ('a700eed2-0000-4000-8000-000000000001'::uuid, 'revoked.write@example.test')
) as x(id, email);

insert into public.tenants (id, slug, legal_name, display_name)
values
  ('70000001-0000-4000-8000-000000000001', 'write-tenant-a', 'Synth Tenant A', 'Tenant A'),
  ('70000002-0000-4000-8000-000000000002', 'write-tenant-b', 'Synth Tenant B', 'Tenant B');

insert into public.workshops (id, tenant_id, code, name)
values
  ('70100001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', 'WA1', 'Workshop A1'),
  ('70200001-0000-4000-8000-000000000002', '70000001-0000-4000-8000-000000000001', 'WA2', 'Workshop A2'),
  ('7b100001-0000-4000-8000-000000000001', '70000002-0000-4000-8000-000000000002', 'WB1', 'Workshop B1');

insert into public.profiles (user_id, full_name)
values
  ('f7000001-0000-4000-8000-000000000001', 'Synth Owner A'),
  ('f7000002-0000-4000-8000-000000000001', 'Synth Admin A'),
  ('f7000003-0000-4000-8000-000000000001', 'Synth Receptionist A1'),
  ('f7000004-0000-4000-8000-000000000001', 'Synth Mechanic A1'),
  ('f7000005-0000-4000-8000-000000000001', 'Synth Viewer A2'),
  ('f70000b1-0000-4000-8000-000000000001', 'Synth Owner B'),
  ('e7000001-0000-4000-8000-000000000001', 'Synth No Mem'),
  ('a700eed1-0000-4000-8000-000000000001', 'Synth Suspended'),
  ('a700eed2-0000-4000-8000-000000000001', 'Synth Revoked');

insert into public.tenant_members (tenant_id, user_id, role, membership_status, is_default_tenant)
values
  ('70000001-0000-4000-8000-000000000001', 'f7000001-0000-4000-8000-000000000001', 'owner', 'active', false),
  ('70000001-0000-4000-8000-000000000001', 'f7000002-0000-4000-8000-000000000001', 'admin', 'active', false),
  ('70000001-0000-4000-8000-000000000001', 'f7000003-0000-4000-8000-000000000001', 'receptionist', 'active', false),
  ('70000001-0000-4000-8000-000000000001', 'f7000004-0000-4000-8000-000000000001', 'mechanic', 'active', false),
  ('70000001-0000-4000-8000-000000000001', 'f7000005-0000-4000-8000-000000000001', 'viewer', 'active', false),
  ('70000002-0000-4000-8000-000000000002', 'f70000b1-0000-4000-8000-000000000001', 'owner', 'active', false),
  ('70000001-0000-4000-8000-000000000001', 'a700eed1-0000-4000-8000-000000000001', 'receptionist', 'suspended', false),
  ('70000001-0000-4000-8000-000000000001', 'a700eed2-0000-4000-8000-000000000001', 'mechanic', 'revoked', false);

insert into public.workshop_members (tenant_id, workshop_id, user_id, role, membership_status)
values
  ('70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'f7000001-0000-4000-8000-000000000001', 'owner', 'active'),
  ('70000001-0000-4000-8000-000000000001', '70200001-0000-4000-8000-000000000002', 'f7000001-0000-4000-8000-000000000001', 'owner', 'active'),
  ('70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'f7000002-0000-4000-8000-000000000001', 'admin', 'active'),
  ('70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'f7000003-0000-4000-8000-000000000001', 'receptionist', 'active'),
  ('70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'f7000004-0000-4000-8000-000000000001', 'mechanic', 'active'),
  ('70000001-0000-4000-8000-000000000001', '70200001-0000-4000-8000-000000000002', 'f7000005-0000-4000-8000-000000000001', 'viewer', 'active'),
  ('70000002-0000-4000-8000-000000000002', '7b100001-0000-4000-8000-000000000001', 'f70000b1-0000-4000-8000-000000000001', 'owner', 'active');

-- Base customers + vehicles (superuser; no RLS write on vehicles)
insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name, email)
values
  ('c7000001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'WCA1-001', 'Synth Cust A1', 'c1@example.test'),
  ('c7000002-0000-4000-8000-000000000002', '70000001-0000-4000-8000-000000000001', '70200001-0000-4000-8000-000000000002', 'WCA2-001', 'Synth Cust A2', 'c2@example.test'),
  ('c7000003-0000-4000-8000-000000000003', '70000002-0000-4000-8000-000000000002', '7b100001-0000-4000-8000-000000000001', 'WCB1-001', 'Synth Cust B1', 'c3@example.test');

insert into public.vehicles (
  id, tenant_id, customer_id, workshop_id, make, model,
  reg_number_ciphertext, reg_number_hash, reg_number_last4
)
values
  (
    'd7000001-0000-4000-8000-000000000001',
    '70000001-0000-4000-8000-000000000001',
    'c7000001-0000-4000-8000-000000000001',
    '70100001-0000-4000-8000-000000000001',
    'Synth', 'Car1', 'enc-w1', digest('SYNTH-W-VEH-A1', 'sha256'), 'aa11'
  ),
  (
    'd7000002-0000-4000-8000-000000000002',
    '70000001-0000-4000-8000-000000000001',
    'c7000002-0000-4000-8000-000000000002',
    '70200001-0000-4000-8000-000000000002',
    'Synth', 'Car2', 'enc-w2', digest('SYNTH-W-VEH-A2', 'sha256'), 'aa22'
  ),
  (
    'd7000003-0000-4000-8000-000000000003',
    '70000002-0000-4000-8000-000000000002',
    'c7000003-0000-4000-8000-000000000003',
    '7b100001-0000-4000-8000-000000000001',
    'Synth', 'CarB', 'enc-wb', digest('SYNTH-W-VEH-B1', 'sha256'), 'bb11'
  );

-- ---------------------------------------------------------------------------
-- pgTAP plan: lives_ok / throws_matching / is (32 SELECT-svit ar separat fil)
-- ---------------------------------------------------------------------------
select plan(44);

-- profiles: self update OK
select lives_ok(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$update public.profiles set full_name = 'Synth Mechanic Updated' where user_id = 'f7000004-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W01: mechanic updates own profile'
);

-- profiles: cannot update other user (Postgres: 0 matching rows => no error; assert target row unchanged)
select lives_ok(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$update public.profiles set full_name = 'Nope' where user_id = 'f7000001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W02a: cross-user profile update attempt does not throw'
);
select is(
  (select full_name from public.profiles where user_id = 'f7000001-0000-4000-8000-000000000001'::uuid),
  'Synth Owner A',
  'W02b: owner profile unchanged after mechanic update attempt'
);

-- profiles: cannot change user_id (WITH CHECK fails)
select throws_matching(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$update public.profiles set user_id = 'f7000001-0000-4000-8000-000000000001'::uuid where user_id = 'f7000004-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'row-level security',
  'W03: cannot change user_id on profile'
);

-- customers: owner insert
select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name)
     values ('c70000e1-0000-4000-8000-0000000000e1', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'WNEW-O1', 'Synth New Owner');$i$
  );$q$,
  'W04: owner inserts customer in A / A1'
);

-- customers: admin insert (null workshop allowed for owner/admin)
select lives_ok(
  $q$select pg_temp.run_as('f7000002-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name)
     values ('c70000e2-0000-4000-8000-0000000000e2', '70000001-0000-4000-8000-000000000001', null, 'WNEW-AD', 'Synth Admin Cust');$i$
  );$q$,
  'W05: admin inserts customer with null workshop'
);

-- customers: receptionist insert in own workshop
select lives_ok(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name)
     values ('c70000e3-0000-4000-8000-0000000000e3', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'WNEW-R1', 'Synth Rec Cust');$i$
  );$q$,
  'W06: receptionist inserts customer in A1 (tenant role + workshop_members)'
);

-- customers: receptionist cannot insert in A2 (no workshop access)
select throws_matching(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name)
     values ('c70000e4-0000-4000-8000-0000000000e4', '70000001-0000-4000-8000-000000000001', '70200001-0000-4000-8000-000000000002', 'WNEW-R2', 'Bad');$i$
  );$q$,
  'row-level security',
  'W07: receptionist blocked on A2 customer insert'
);

-- customers: mechanic cannot insert
select throws_matching(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name)
     values ('c70000e5-0000-4000-8000-0000000000e5', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'WNEW-M1', 'Bad');$i$
  );$q$,
  'row-level security',
  'W08: mechanic cannot insert customer'
);

-- customers: viewer cannot insert
select throws_matching(
  $q$select pg_temp.run_as('f7000005-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name)
     values ('c70000e6-0000-4000-8000-0000000000e6', '70000001-0000-4000-8000-000000000001', '70200001-0000-4000-8000-000000000002', 'WNEW-V1', 'Bad');$i$
  );$q$,
  'row-level security',
  'W09: viewer cannot insert customer'
);

-- customers: no membership cannot insert
select throws_matching(
  $q$select pg_temp.run_as('e7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name)
     values ('c70000e7-0000-4000-8000-0000000000e7', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'WNEW-N1', 'Bad');$i$
  );$q$,
  'row-level security',
  'W10: no membership cannot insert customer'
);

-- customers: suspended cannot insert
select throws_matching(
  $q$select pg_temp.run_as('a700eed1-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name)
     values ('c70000e8-0000-4000-8000-0000000000e8', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'WNEW-S1', 'Bad');$i$
  );$q$,
  'row-level security',
  'W11: suspended cannot insert customer'
);

-- customers: cross-tenant insert blocked (owner A inserts with tenant B)
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name)
     values ('c70000e9-0000-4000-8000-0000000000e9', '70000002-0000-4000-8000-000000000002', '7b100001-0000-4000-8000-000000000001', 'WX-TNT', 'Bad');$i$
  );$q$,
  'row-level security',
  'W12: owner A cannot insert customer in tenant B'
);

-- customers: update OK (owner)
select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.customers set full_name = 'Synth Cust A1 Upd' where id = 'c7000001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W13: owner updates customer in tenant A'
);

-- customers: tenant_id change blocked (RLS WITH CHECK often fails first; trigger also rejects if reached)
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.customers set tenant_id = '70000002-0000-4000-8000-000000000002' where id = 'c7000001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  '(row-level security policy|tenant_id cannot be changed)',
  'W14: customer tenant_id immutable'
);

-- bookings: owner insert
select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.bookings (id, tenant_id, workshop_id, customer_id, vehicle_id, booking_number, service_category, service_name, starts_at)
     values ('b7000001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WBK-O1', 'verkstad', 'Synth', now());$i$
  );$q$,
  'W15: owner inserts booking A1'
);

-- bookings: receptionist insert A1
select lives_ok(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.bookings (id, tenant_id, workshop_id, customer_id, vehicle_id, booking_number, service_category, service_name, starts_at)
     values ('b7000002-0000-4000-8000-000000000002', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c70000e3-0000-4000-8000-0000000000e3', 'd7000001-0000-4000-8000-000000000001', 'WBK-R1', 'service', 'Synth', now());$i$
  );$q$,
  'W16: receptionist inserts booking A1'
);

-- bookings: mechanic cannot insert
select throws_matching(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.bookings (id, tenant_id, workshop_id, customer_id, vehicle_id, booking_number, service_category, service_name, starts_at)
     values ('b7000003-0000-4000-8000-000000000003', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WBK-M1', 'verkstad', 'Synth', now());$i$
  );$q$,
  'row-level security',
  'W17: mechanic cannot insert booking'
);

-- bookings: wrong vehicle tenant
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.bookings (id, tenant_id, workshop_id, customer_id, vehicle_id, booking_number, service_category, service_name, starts_at)
     values ('b7000004-0000-4000-8000-000000000004', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000003-0000-4000-8000-000000000003', 'WBK-BAD', 'verkstad', 'Synth', now());$i$
  );$q$,
  'row-level security',
  'W18: booking insert blocked with vehicle from tenant B'
);

-- bookings: update with workshop access
select lives_ok(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$update public.bookings set notes = 'rec note' where id = 'b7000002-0000-4000-8000-000000000002'::uuid;$i$
  );$q$,
  'W19: receptionist updates booking in A1'
);

-- baseline for W21 (viewer cross-workshop update yields 0 rows, no exception)
update public.bookings
set notes = 'baseline-w21'
where id = 'b7000001-0000-4000-8000-000000000001'::uuid;

-- bookings: tenant_id change trigger
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.bookings set tenant_id = '70000002-0000-4000-8000-000000000002' where id = 'b7000001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  '(row-level security policy|tenant_id cannot be changed)',
  'W20: booking tenant_id immutable'
);

-- bookings: viewer cannot update A1 booking (no workshop access; assert row unchanged)
select lives_ok(
  $q$select pg_temp.run_as('f7000005-0000-4000-8000-000000000001'::uuid,
    $i$update public.bookings set notes = 'viewer-was-here' where id = 'b7000001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W21a: viewer update attempt on A1 booking does not throw'
);
select is(
  (select notes from public.bookings where id = 'b7000001-0000-4000-8000-000000000001'::uuid),
  'baseline-w21',
  'W21b: A1 booking notes unchanged (viewer lacks workshop access)'
);

-- quotes: insert OK owner
select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.quotes (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, quote_number, status)
     values ('f8e00001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'b7000001-0000-4000-8000-000000000001', 'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WQT-O1', 'draft');$i$
  );$q$,
  'W22: owner inserts quote A1'
);

-- quotes: booking_id wrong workshop blocked
select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.bookings (id, tenant_id, workshop_id, customer_id, vehicle_id, booking_number, service_category, service_name, starts_at)
     values ('b70000a2-0000-4000-8000-0000000000a2', '70000001-0000-4000-8000-000000000001', '70200001-0000-4000-8000-000000000002',
             'c7000002-0000-4000-8000-000000000002', 'd7000002-0000-4000-8000-000000000002', 'WBK-A2X', 'verkstad', 'Synth', now());$i$
  );$q$,
  'W23a: seed booking A2 for quote mismatch test'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.quotes (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, quote_number, status)
     values ('f8e00002-0000-4000-8000-000000000002', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'b70000a2-0000-4000-8000-0000000000a2', 'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WQT-BAD', 'draft');$i$
  );$q$,
  'row-level security',
  'W23b: quote insert blocked when booking workshop mismatches quote workshop'
);

-- quotes: customer from other tenant blocked
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.quotes (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, quote_number, status)
     values ('f8e00003-0000-4000-8000-000000000003', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             null, 'c7000003-0000-4000-8000-000000000003', 'd7000001-0000-4000-8000-000000000001', 'WQT-CBAD', 'draft');$i$
  );$q$,
  'row-level security',
  'W24: quote insert blocked with customer from tenant B'
);

-- quotes: mechanic cannot insert
select throws_matching(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.quotes (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, quote_number, status)
     values ('f8e00004-0000-4000-8000-000000000004', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             null, 'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WQT-M1', 'draft');$i$
  );$q$,
  'row-level security',
  'W25: mechanic cannot insert quote'
);

-- quotes: update OK
select lives_ok(
  $q$select pg_temp.run_as('f7000002-0000-4000-8000-000000000001'::uuid,
    $i$update public.quotes set notes = 'admin note' where id = 'f8e00001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W26: admin updates quote with workshop access'
);

-- quotes: tenant_id immutable
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.quotes set tenant_id = '70000002-0000-4000-8000-000000000002' where id = 'f8e00001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  '(row-level security policy|tenant_id cannot be changed)',
  'W27: quote tenant_id immutable'
);

-- quote_items: insert OK
select lives_ok(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.quote_items (id, tenant_id, quote_id, line_number, description, line_total_amount)
     values ('0e700001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', 'f8e00001-0000-4000-8000-000000000001', 1, 'Line 1', 100);$i$
  );$q$,
  'W28: receptionist inserts quote_item for parent quote'
);

-- quote_items: wrong tenant vs quote
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.quote_items (id, tenant_id, quote_id, line_number, description, line_total_amount)
     values ('0e700002-0000-4000-8000-000000000002', '70000002-0000-4000-8000-000000000002', 'f8e00001-0000-4000-8000-000000000001', 2, 'Bad', 50);$i$
  );$q$,
  'row-level security',
  'W29: quote_item blocked when tenant_id mismatches parent quote'
);

-- quote_items: mechanic cannot insert
select throws_matching(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.quote_items (id, tenant_id, quote_id, line_number, description, line_total_amount)
     values ('0e700003-0000-4000-8000-000000000003', '70000001-0000-4000-8000-000000000001', 'f8e00001-0000-4000-8000-000000000001', 3, 'Bad', 50);$i$
  );$q$,
  'row-level security',
  'W30: mechanic cannot insert quote_item'
);

-- quote_items: update OK
select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.quote_items set description = 'Line 1 updated' where id = '0e700001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W31: owner updates quote_item'
);

-- quote_items: tenant_id immutable
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.quote_items set tenant_id = '70000002-0000-4000-8000-000000000002' where id = '0e700001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  '(row-level security policy|tenant_id cannot be changed)',
  'W32: quote_item tenant_id immutable'
);

-- Tables without write policies: tenants
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.tenants (id, slug, legal_name, display_name)
     values ('7fffffff-0000-4000-8000-000000000099', 'evil', 'Evil', 'Evil');$i$
  );$q$,
  'row-level security',
  'W33: authenticated cannot insert tenant'
);

-- workshops
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.workshops (id, tenant_id, code, name)
     values ('7fffffff-0000-4000-8000-0000000000aa', '70000001-0000-4000-8000-000000000001', 'ZZ', 'Bad');$i$
  );$q$,
  'row-level security',
  'W34: authenticated cannot insert workshop'
);

-- tenant_members
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.tenant_members (tenant_id, user_id, role, membership_status)
     values ('70000001-0000-4000-8000-000000000001', 'e7000001-0000-4000-8000-000000000001', 'viewer', 'active');$i$
  );$q$,
  'row-level security',
  'W35: cannot insert tenant_members'
);

-- workshop_members
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.workshop_members (tenant_id, workshop_id, user_id, role, membership_status)
     values ('70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001', 'e7000001-0000-4000-8000-000000000001', 'viewer', 'active');$i$
  );$q$,
  'row-level security',
  'W36: cannot insert workshop_members'
);

-- vehicles
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.vehicles (id, tenant_id, customer_id, workshop_id, make, model, reg_number_ciphertext, reg_number_hash, reg_number_last4)
     values ('d70000ff-0000-4000-8000-0000000000ff', '70000001-0000-4000-8000-000000000001', 'c7000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'X', 'Y', 'enc', decode('00ffaa', 'hex'), 'zz99');$i$
  );$q$,
  'row-level security',
  'W37: cannot insert vehicle as authenticated'
);

-- work_orders
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.work_orders (id, tenant_id, workshop_id, customer_id, vehicle_id, work_order_number, status)
     values ('e7000001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WWO-1', 'draft');$i$
  );$q$,
  'row-level security',
  'W38: cannot insert work_order'
);

-- receipts
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.receipts (id, tenant_id, workshop_id, customer_id, vehicle_id, receipt_number, payment_status)
     values ('02700001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WRCP-1', 'unpaid');$i$
  );$q$,
  'row-level security',
  'W39: cannot insert receipt'
);

-- tire_hotel
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.tire_hotel (id, tenant_id, workshop_id, customer_id, vehicle_id, storage_code, season, status)
     values ('03700001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'TH-X', 'winter', 'stored');$i$
  );$q$,
  'row-level security',
  'W40: cannot insert tire_hotel'
);

-- receptionist vs workshop_members role: receptionist tenant role + workshop_members required (documented in header)
select is(
  (
    select count(*)::bigint
    from public.tenant_members tm
    join public.workshop_members wm
      on wm.tenant_id = tm.tenant_id and wm.user_id = tm.user_id
    where tm.user_id = 'f7000003-0000-4000-8000-000000000001'::uuid
      and tm.role = 'receptionist'
      and wm.workshop_id = '70100001-0000-4000-8000-000000000001'::uuid
  ),
  1::bigint,
  'W41: receptionist has both tenant_members and workshop_members for A1'
);

select * from finish();

rollback;
