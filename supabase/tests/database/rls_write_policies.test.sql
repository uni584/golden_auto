-- RLS write policy tests for migrations 0005–0010 (synthetic data only)
--
-- Assumptions:
--   * Runs after migrations 0001–0010.
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

create or replace function pg_temp.run_as_count(p_uid uuid, p_sql text)
returns bigint
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
declare
  v_count bigint;
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  execute p_sql into v_count;
  reset role;
  return coalesce(v_count, 0);
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

-- Quote mismatched for receipt RPC tests (A1 workshop but A2 customer/vehicle pair)
insert into public.quotes (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, quote_number, status)
values (
  'f8e00bad-0000-4000-8000-00000000bad1',
  '70000001-0000-4000-8000-000000000001',
  '70100001-0000-4000-8000-000000000001',
  null,
  'c7000002-0000-4000-8000-000000000002',
  'd7000002-0000-4000-8000-000000000002',
  'WQT-BAD-REC',
  'draft'
);

-- ---------------------------------------------------------------------------
-- pgTAP plan: lives_ok / throws_matching / is (32 SELECT-svit ar separat fil)
-- ---------------------------------------------------------------------------
select plan(129);

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

-- vehicles (0006): owner/admin/receptionist scoped; mechanic/viewer blocked
select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.vehicles (id, tenant_id, customer_id, workshop_id, make, model, reg_number_ciphertext, reg_number_hash, reg_number_last4)
     values ('d7000a01-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', 'c7000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'Synth', 'VehOwn', 'enc-vo', decode('a1a1a1', 'hex'), 'vo01');$i$
  );$q$,
  'W37: owner inserts vehicle in A1'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.vehicles (id, tenant_id, customer_id, workshop_id, make, model, reg_number_ciphertext, reg_number_hash, reg_number_last4)
     values ('d7000a02-0000-4000-8000-000000000002', '70000001-0000-4000-8000-000000000001', 'c7000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'Synth', 'VehRec', 'enc-vr', decode('a2a2a2', 'hex'), 'vr01');$i$
  );$q$,
  'W38: receptionist inserts vehicle in A1 (workshop access)'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.vehicles (id, tenant_id, customer_id, workshop_id, make, model, reg_number_ciphertext, reg_number_hash, reg_number_last4)
     values ('d7000a03-0000-4000-8000-000000000003', '70000001-0000-4000-8000-000000000001', 'c7000002-0000-4000-8000-000000000002', '70200001-0000-4000-8000-000000000002',
             'Synth', 'Bad', 'enc', decode('a3a3a3', 'hex'), 'xx01');$i$
  );$q$,
  'row-level security',
  'W39: receptionist cannot insert vehicle for A2 (no workshop access)'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.vehicles (id, tenant_id, customer_id, workshop_id, make, model, reg_number_ciphertext, reg_number_hash, reg_number_last4)
     values ('d7000a04-0000-4000-8000-000000000004', '70000001-0000-4000-8000-000000000001', 'c7000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'Synth', 'Mech', 'enc', decode('a4a4a4', 'hex'), 'm401');$i$
  );$q$,
  'row-level security',
  'W40: mechanic cannot insert vehicle'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000005-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.vehicles (id, tenant_id, customer_id, workshop_id, make, model, reg_number_ciphertext, reg_number_hash, reg_number_last4)
     values ('d7000a05-0000-4000-8000-000000000005', '70000001-0000-4000-8000-000000000001', 'c7000002-0000-4000-8000-000000000002', '70200001-0000-4000-8000-000000000002',
             'Synth', 'View', 'enc', decode('a5a5a5', 'hex'), 'vw01');$i$
  );$q$,
  'row-level security',
  'W41: viewer cannot insert vehicle'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.vehicles (id, tenant_id, customer_id, workshop_id, make, model, reg_number_ciphertext, reg_number_hash, reg_number_last4)
     values ('d7000a06-0000-4000-8000-000000000006', '70000001-0000-4000-8000-000000000001', 'c7000003-0000-4000-8000-000000000003', '70100001-0000-4000-8000-000000000001',
             'Synth', 'Xtn', 'enc', decode('a6a6a6', 'hex'), 'xt01');$i$
  );$q$,
  'row-level security',
  'W42: vehicle insert blocked when customer is from tenant B'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.vehicles set color = 'Blue' where id = 'd7000a01-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W43: owner updates vehicle'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.vehicles set tenant_id = '70000002-0000-4000-8000-000000000002' where id = 'd7000a01-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  '(row-level security policy|tenant_id cannot be changed)',
  'W44: vehicle tenant_id immutable'
);

select throws_matching(
  $q$select pg_temp.run_as('e7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.vehicles (id, tenant_id, customer_id, workshop_id, make, model, reg_number_ciphertext, reg_number_hash, reg_number_last4)
     values ('d7000a07-0000-4000-8000-000000000007', '70000001-0000-4000-8000-000000000001', 'c7000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'Synth', 'Nomem', 'enc', decode('a7a7a7', 'hex'), 'nm01');$i$
  );$q$,
  'row-level security',
  'W45: no membership cannot insert vehicle'
);

-- registration fields (0007): direct UPDATE blocked; use update_vehicle_registration_fields
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.vehicles
       set reg_number_ciphertext = 'direct-bad',
           reg_number_hash = decode('bad1', 'hex'),
           reg_number_last4 = 'db01'
     where id = 'd7000a01-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'update_vehicle_registration_fields',
  'W46: direct client UPDATE of reg fields blocked'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.update_vehicle_registration_fields(
      'd7000a01-0000-4000-8000-000000000001'::uuid,
      'enc-rpc-owner',
      decode('c0c0c0', 'hex'),
      'rp01'
    );$i$
  );$q$,
  'W47: owner updates reg fields via RPC'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$select public.update_vehicle_registration_fields(
      'd7000a02-0000-4000-8000-000000000002'::uuid,
      'enc-rpc-rec',
      decode('d1d1d1', 'hex'),
      'rp02'
    );$i$
  );$q$,
  'W48: receptionist updates reg fields via RPC (A1 vehicle)'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$select public.update_vehicle_registration_fields(
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'enc-mech',
      decode('e1e1e1', 'hex'),
      'me01'
    );$i$
  );$q$,
  'not authorized',
  'W49: mechanic cannot update reg fields via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000005-0000-4000-8000-000000000001'::uuid,
    $i$select public.update_vehicle_registration_fields(
      'd7000a01-0000-4000-8000-000000000001'::uuid,
      'enc-view',
      decode('f1f1f1', 'hex'),
      'vw99'
    );$i$
  );$q$,
  'not authorized',
  'W50: viewer cannot update reg fields via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.update_vehicle_registration_fields(
      'd7000003-0000-4000-8000-000000000003'::uuid,
      'enc-cross',
      decode('c2c2c2', 'hex'),
      'cr01'
    );$i$
  );$q$,
  'not authorized',
  'W51: owner A cannot update reg fields on tenant B vehicle via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.update_vehicle_registration_fields(
      'd7000a01-0000-4000-8000-000000000001'::uuid,
      'enc-dup',
      (select reg_number_hash from public.vehicles where id = 'd7000001-0000-4000-8000-000000000001'::uuid),
      'du01'
    );$i$
  );$q$,
  'registration hash conflict',
  'W52: RPC rejects duplicate reg_number_hash within tenant'
);

-- work_orders (0006): owner/admin + mechanic (workshop); receptionist/viewer blocked
select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.work_orders (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, work_order_number, status)
     values ('ab700001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'b7000001-0000-4000-8000-000000000001', 'c7000001-0000-4000-8000-000000000001', 'd7000a01-0000-4000-8000-000000000001', 'WWO-OWN', 'draft');$i$
  );$q$,
  'W53: owner inserts work_order A1'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.work_orders (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, work_order_number, status)
     values ('ab700002-0000-4000-8000-000000000002', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             null, 'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WWO-MEC', 'draft');$i$
  );$q$,
  'W54: mechanic inserts work_order in A1'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.work_orders (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, work_order_number, status)
     values ('ab700003-0000-4000-8000-000000000003', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             null, 'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WWO-REC', 'draft');$i$
  );$q$,
  'row-level security',
  'W55: receptionist cannot insert work_order'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000005-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.work_orders (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, work_order_number, status)
     values ('ab700004-0000-4000-8000-000000000004', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             null, 'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WWO-VWR', 'draft');$i$
  );$q$,
  'row-level security',
  'W56: viewer cannot insert work_order in A1'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.work_orders (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, work_order_number, status)
     values ('ab700005-0000-4000-8000-000000000005', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             null, 'c7000001-0000-4000-8000-000000000001', 'd7000003-0000-4000-8000-000000000003', 'WWO-BAD', 'draft');$i$
  );$q$,
  'row-level security',
  'W57: work_order insert blocked when vehicle is from tenant B'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.work_orders (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, work_order_number, status)
     values ('ab700006-0000-4000-8000-000000000006', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'b70000a2-0000-4000-8000-0000000000a2', 'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WWO-BKG', 'draft');$i$
  );$q$,
  'row-level security',
  'W58: work_order insert blocked when booking workshop mismatches'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.work_orders (id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, work_order_number, status)
     values ('ab700007-0000-4000-8000-000000000007', '70000001-0000-4000-8000-000000000001', '70200001-0000-4000-8000-000000000002',
             null, 'c7000002-0000-4000-8000-000000000002', 'd7000002-0000-4000-8000-000000000002', 'WWO-A2X', 'draft');$i$
  );$q$,
  'row-level security',
  'W59: mechanic cannot insert work_order in A2 (no access)'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.work_orders set notes = 'wo note' where id = 'ab700001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W60: owner updates work_order'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.work_orders set tenant_id = '70000002-0000-4000-8000-000000000002' where id = 'ab700001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  '(row-level security policy|tenant_id cannot be changed)',
  'W61: work_order tenant_id immutable'
);

-- tire_hotel (0006)
select lives_ok(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.tire_hotel (id, tenant_id, workshop_id, customer_id, vehicle_id, storage_code, season, status)
     values ('ac700001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'TH-R01', 'winter', 'stored');$i$
  );$q$,
  'W62: receptionist inserts tire_hotel A1'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.tire_hotel (id, tenant_id, workshop_id, customer_id, vehicle_id, storage_code, season, status)
     values ('ac700002-0000-4000-8000-000000000002', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'TH-M01', 'summer', 'stored');$i$
  );$q$,
  'W63: mechanic inserts tire_hotel A1'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000005-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.tire_hotel (id, tenant_id, workshop_id, customer_id, vehicle_id, storage_code, season, status)
     values ('ac700003-0000-4000-8000-000000000003', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'TH-V01', 'winter', 'stored');$i$
  );$q$,
  'row-level security',
  'W64: viewer cannot insert tire_hotel A1'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.tire_hotel (id, tenant_id, workshop_id, customer_id, vehicle_id, storage_code, season, status)
     values ('ac700004-0000-4000-8000-000000000004', '70000001-0000-4000-8000-000000000001', '70200001-0000-4000-8000-000000000002',
             'c7000002-0000-4000-8000-000000000002', 'd7000002-0000-4000-8000-000000000002', 'TH-A2X', 'winter', 'stored');$i$
  );$q$,
  'row-level security',
  'W65: receptionist cannot insert tire_hotel A2 (no access)'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.tire_hotel (id, tenant_id, workshop_id, customer_id, vehicle_id, storage_code, season, status)
     values ('ac700005-0000-4000-8000-000000000005', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000003-0000-4000-8000-000000000003', 'd7000001-0000-4000-8000-000000000001', 'TH-BAD', 'winter', 'stored');$i$
  );$q$,
  'row-level security',
  'W66: tire_hotel insert blocked when customer from tenant B'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.tire_hotel set rack = 'R12' where id = 'ac700001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W67: owner updates tire_hotel'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.tire_hotel set tenant_id = '70000002-0000-4000-8000-000000000002' where id = 'ac700001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  '(row-level security policy|tenant_id cannot be changed)',
  'W68: tire_hotel tenant_id immutable'
);

-- receipts: no INSERT/UPDATE RLS; foundation via create_receipt RPC (0008)
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.receipts (id, tenant_id, workshop_id, customer_id, vehicle_id, receipt_number, payment_status)
     values ('02700001-0000-4000-8000-000000000001', '70000001-0000-4000-8000-000000000001', '70100001-0000-4000-8000-000000000001',
             'c7000001-0000-4000-8000-000000000001', 'd7000001-0000-4000-8000-000000000001', 'WRCP-1', 'unpaid');$i$
  );$q$,
  'row-level security',
  'W69: cannot insert receipt as authenticated'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-1',
      100::numeric,
      25::numeric,
      125::numeric,
      'unpaid',
      'SEK',
      null::uuid,
      null::uuid,
      null::uuid,
      '{}'::jsonb
    );$i$
  );$q$,
  'W71: owner creates receipt via create_receipt'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000002-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-2',
      200::numeric,
      50::numeric,
      250::numeric,
      'unpaid',
      'SEK',
      'b7000001-0000-4000-8000-000000000001'::uuid,
      'ab700002-0000-4000-8000-000000000002'::uuid,
      'f8e00001-0000-4000-8000-000000000001'::uuid,
      '{}'::jsonb
    );$i$
  );$q$,
  'W72: admin creates receipt via RPC with booking, work_order, quote'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000003-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-RX',
      0::numeric,
      0::numeric,
      0::numeric
    );$i$
  );$q$,
  'not authorized',
  'W73: receptionist cannot create receipt via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000004-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-MX',
      0::numeric,
      0::numeric,
      0::numeric
    );$i$
  );$q$,
  'not authorized',
  'W74: mechanic cannot create receipt via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000005-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70200001-0000-4000-8000-000000000002'::uuid,
      'c7000002-0000-4000-8000-000000000002'::uuid,
      'd7000002-0000-4000-8000-000000000002'::uuid,
      'WRCP-RPC-VX',
      0::numeric,
      0::numeric,
      0::numeric
    );$i$
  );$q$,
  'not authorized',
  'W75: viewer cannot create receipt via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('e7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-NM',
      0::numeric,
      0::numeric,
      0::numeric
    );$i$
  );$q$,
  'not authorized',
  'W76: no membership cannot create receipt via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('a700eed1-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-SU',
      0::numeric,
      0::numeric,
      0::numeric
    );$i$
  );$q$,
  'not authorized',
  'W77: suspended cannot create receipt via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('a700eed2-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-RV',
      0::numeric,
      0::numeric,
      0::numeric
    );$i$
  );$q$,
  'not authorized',
  'W78: revoked cannot create receipt via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000002-0000-4000-8000-000000000002'::uuid,
      '7b100001-0000-4000-8000-000000000001'::uuid,
      'c7000003-0000-4000-8000-000000000003'::uuid,
      'd7000003-0000-4000-8000-000000000003'::uuid,
      'WRCP-RPC-XT',
      0::numeric,
      0::numeric,
      0::numeric
    );$i$
  );$q$,
  'not authorized',
  'W79: owner A cannot create receipt for tenant B via RPC'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70200001-0000-4000-8000-000000000002'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-XW',
      0::numeric,
      0::numeric,
      0::numeric
    );$i$
  );$q$,
  'invalid receipt context',
  'W80: receipt blocked when customer/workshop mismatch'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000002-0000-4000-8000-000000000002'::uuid,
      'WRCP-RPC-VC',
      0::numeric,
      0::numeric,
      0::numeric
    );$i$
  );$q$,
  'invalid receipt context',
  'W81: receipt blocked when vehicle does not belong to customer'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-BK',
      0::numeric,
      0::numeric,
      0::numeric,
      'unpaid',
      'SEK',
      'b70000a2-0000-4000-8000-0000000000a2'::uuid,
      null::uuid,
      null::uuid,
      '{}'::jsonb
    );$i$
  );$q$,
  'invalid receipt context',
  'W82: receipt blocked when booking does not match workshop/customer/vehicle'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-WO',
      0::numeric,
      0::numeric,
      0::numeric,
      'unpaid',
      'SEK',
      null::uuid,
      'ab700001-0000-4000-8000-000000000001'::uuid,
      null::uuid,
      '{}'::jsonb
    );$i$
  );$q$,
  'invalid receipt context',
  'W83: receipt blocked when work_order does not match customer/vehicle'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-QT',
      0::numeric,
      0::numeric,
      0::numeric,
      'unpaid',
      'SEK',
      null::uuid,
      null::uuid,
      'f8e00bad-0000-4000-8000-00000000bad1'::uuid,
      '{}'::jsonb
    );$i$
  );$q$,
  'invalid receipt context',
  'W84: receipt blocked when quote does not match customer/vehicle'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-NEG',
      -1::numeric,
      0::numeric,
      -1::numeric
    );$i$
  );$q$,
  'amounts must be non-negative',
  'W85: create_receipt rejects negative amounts'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-PD',
      0::numeric,
      0::numeric,
      0::numeric,
      'paid',
      'SEK'
    );$i$
  );$q$,
  'invalid payment status for create',
  'W86: create_receipt rejects non-unpaid payment_status'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$select public.create_receipt(
      '70000001-0000-4000-8000-000000000001'::uuid,
      '70100001-0000-4000-8000-000000000001'::uuid,
      'c7000001-0000-4000-8000-000000000001'::uuid,
      'd7000001-0000-4000-8000-000000000001'::uuid,
      'WRCP-RPC-TOT',
      10::numeric,
      5::numeric,
      10::numeric
    );$i$
  );$q$,
  'total must equal subtotal plus vat',
  'W87: create_receipt rejects total not equal subtotal+vat'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.receipts set total_amount = 999::numeric where receipt_number = 'WRCP-RPC-1';$i$
  );$q$,
  'receipt updates must use a future RPC',
  'W88: direct receipt UPDATE denied'
);

select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$delete from public.receipts where receipt_number = 'WRCP-RPC-1';$i$
  );$q$,
  'receipt delete is not allowed for client sessions',
  'W89: direct receipt DELETE denied'
);

select is(
  (
    select created_by
    from public.receipts
    where receipt_number = 'WRCP-RPC-1'
  ),
  'f7000001-0000-4000-8000-000000000001'::uuid,
  'W90: receipt created_by set from auth.uid()'
);

-- audit_events (0009): no direct client write
select throws_matching(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$insert into public.audit_events (tenant_id, workshop_id, actor_user_id, action, resource_type, resource_id, metadata)
      values (
        '70000001-0000-4000-8000-000000000001'::uuid,
        '70100001-0000-4000-8000-000000000001'::uuid,
        'f7000001-0000-4000-8000-000000000001'::uuid,
        'manual.bad',
        'vehicle',
        'd7000001-0000-4000-8000-000000000001'::uuid,
        '{}'::jsonb
      );$i$
  );$q$,
  'row-level security',
  'W91: direct client INSERT to audit_events denied'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events
    where tenant_id = '70000001-0000-4000-8000-000000000001'::uuid
  ),
  11::bigint,
  'W92: audit events include RPC + customer/vehicle trigger flow rows'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$update public.audit_events set action = 'tamper' where tenant_id = '70000001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W93a: direct client UPDATE attempt on audit_events does not throw'
);

select is(
  (select count(*)::bigint from public.audit_events where action = 'tamper'),
  0::bigint,
  'W93b: direct client UPDATE on audit_events is effectively denied'
);

select lives_ok(
  $q$select pg_temp.run_as('f7000001-0000-4000-8000-000000000001'::uuid,
    $i$delete from public.audit_events where tenant_id = '70000001-0000-4000-8000-000000000001'::uuid;$i$
  );$q$,
  'W94a: direct client DELETE attempt on audit_events does not throw'
);

select is(
  (select count(*)::bigint from public.audit_events where tenant_id = '70000001-0000-4000-8000-000000000001'::uuid),
  11::bigint,
  'W94b: direct client DELETE on audit_events is effectively denied'
);

select is(
  (select count(*)::bigint from public.audit_events where action = 'customer.created'),
  3::bigint,
  'W95a: customer INSERT flows produce customer.created audit'
);

select is(
  (select count(*)::bigint from public.audit_events where action = 'customer.updated'),
  1::bigint,
  'W95b: customer UPDATE flow produces customer.updated audit'
);

select is(
  (select count(*)::bigint from public.audit_events where action = 'vehicle.created'),
  2::bigint,
  'W95c: vehicle INSERT flows produce vehicle.created audit'
);

select is(
  (select count(*)::bigint from public.audit_events where action = 'vehicle.updated'),
  1::bigint,
  'W95d: vehicle UPDATE flow produces vehicle.updated audit'
);

select is(
  (select count(*)::bigint from public.audit_events where action = 'vehicle.registration_updated'),
  2::bigint,
  'W95e: vehicle registration RPC writes audit events'
);

select is(
  (select count(*)::bigint from public.audit_events where action = 'receipt.created'),
  2::bigint,
  'W96: create_receipt RPC writes audit events'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events
    where action = 'vehicle.registration_updated'
      and metadata ? 'changed_fields'
      and not (metadata ?| array['reg_number_ciphertext','reg_number_hash','reg_number_last4'])
  ),
  2::bigint,
  'W97: reg audit metadata excludes sensitive registration keys'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events
    where action = 'receipt.created'
      and metadata ? 'payment_status'
      and metadata ? 'currency'
      and not (metadata ?| array['full_name','email','reg_number'])
  ),
  2::bigint,
  'W98: receipt audit metadata remains minimal'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events
    where action in ('customer.created', 'customer.updated')
      and (
        metadata::text ilike '%Synth%'
        or metadata::text ilike '%@example.test%'
        or metadata::text ilike '%phone%'
        or metadata::text ilike '%address%'
      )
  ),
  0::bigint,
  'W98a: customer audit metadata excludes PII payload'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events
    where action in ('vehicle.created', 'vehicle.updated')
      and (
        metadata ?| array['reg_number_ciphertext', 'reg_number_hash', 'reg_number_last4']
        or metadata::text ilike '%reg_number_%'
      )
  ),
  0::bigint,
  'W98b: vehicle trigger audit metadata excludes reg_number_*'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events
    where action = 'vehicle.updated'
      and (
        metadata::text ilike '%reg_number_ciphertext%'
        or metadata::text ilike '%reg_number_hash%'
        or metadata::text ilike '%reg_number_last4%'
      )
  ),
  0::bigint,
  'W98c: no unsafe vehicle.updated metadata from registration updates'
);

select is(
  (select count(*)::bigint from public.audit_events where actor_user_id = 'f7000001-0000-4000-8000-000000000001'::uuid),
  6::bigint,
  'W99: owner actor is captured in audit events'
);

select is(
  (select count(*)::bigint from public.audit_events where actor_user_id = 'f7000002-0000-4000-8000-000000000001'::uuid),
  2::bigint,
  'W100: admin actor is captured in audit events'
);

select is(
  (select count(*)::bigint from public.audit_events where actor_user_id = 'f7000003-0000-4000-8000-000000000001'::uuid),
  3::bigint,
  'W101: receptionist actor captured for allowed reg RPC'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events ae
    where ae.tenant_id = '70000001-0000-4000-8000-000000000001'::uuid
      and ae.resource_type = 'vehicle'
      and ae.resource_id = 'd7000a01-0000-4000-8000-000000000001'::uuid
      and ae.workshop_id = '70100001-0000-4000-8000-000000000001'::uuid
  ),
  3::bigint,
  'W102: vehicle audit row contains tenant/workshop/resource context'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events ae
    where ae.tenant_id = '70000001-0000-4000-8000-000000000001'::uuid
      and ae.resource_type = 'receipt'
      and ae.correlation_id is null
  ),
  2::bigint,
  'W103: receipt audit rows created without backend correlation id in v1'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events ae
    where ae.action in ('vehicle.registration_updated', 'receipt.created')
      and (
        ae.metadata::text ilike '%enc-rpc-owner%'
        or ae.metadata::text ilike '%enc-rpc-rec%'
        or ae.metadata::text ilike '%rp01%'
        or ae.metadata::text ilike '%rp02%'
      )
  ),
  0::bigint,
  'W104: audit metadata does not include raw reg payload values'
);

select is(
  (
    select pg_temp.run_as_count(
      'f7000001-0000-4000-8000-000000000001'::uuid,
      $i$select count(*)::bigint from public.audit_events$i$
    )
  ),
  11::bigint,
  'W105: owner can SELECT tenant A audit events'
);

select is(
  (
    select pg_temp.run_as_count(
      'f7000002-0000-4000-8000-000000000001'::uuid,
      $i$select count(*)::bigint from public.audit_events$i$
    )
  ),
  11::bigint,
  'W106: admin can SELECT tenant A audit events'
);

select is(
  (
    select pg_temp.run_as_count(
      'f7000003-0000-4000-8000-000000000001'::uuid,
      $i$select count(*)::bigint from public.audit_events$i$
    )
  ),
  0::bigint,
  'W107: receptionist cannot SELECT audit events in v1'
);

select is(
  (
    select pg_temp.run_as_count(
      'f7000004-0000-4000-8000-000000000001'::uuid,
      $i$select count(*)::bigint from public.audit_events$i$
    )
  ),
  0::bigint,
  'W108: mechanic cannot SELECT audit events in v1'
);

select is(
  (
    select pg_temp.run_as_count(
      'f7000005-0000-4000-8000-000000000001'::uuid,
      $i$select count(*)::bigint from public.audit_events$i$
    )
  ),
  0::bigint,
  'W109: viewer cannot SELECT audit events in v1'
);

select is(
  (
    select pg_temp.run_as_count(
      'f70000b1-0000-4000-8000-000000000001'::uuid,
      $i$select count(*)::bigint from public.audit_events$i$
    )
  ),
  0::bigint,
  'W110: tenant B owner cannot SELECT tenant A audit rows'
);

select is(
  (select count(*)::bigint from public.audit_events where tenant_id = '70000002-0000-4000-8000-000000000002'::uuid),
  0::bigint,
  'W111: no cross-tenant audit rows from tested RPC flows'
);

select is(
  (select count(*)::bigint from public.audit_events where action = 'manual.bad'),
  0::bigint,
  'W112: no manual audit tampering row was inserted'
);

select is(
  (select count(*)::bigint from public.audit_events where metadata ? 'token' or metadata ? 'password'),
  0::bigint,
  'W113: audit metadata does not contain secret keys'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events ae
    where ae.action in ('vehicle.registration_updated', 'receipt.created', 'customer.created', 'customer.updated', 'vehicle.created', 'vehicle.updated')
      and ae.resource_id is not null
  ),
  11::bigint,
  'W114: audited RPC rows include resource ids'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events ae
    where ae.action = 'receipt.created'
      and ae.actor_user_id in (
        'f7000001-0000-4000-8000-000000000001'::uuid,
        'f7000002-0000-4000-8000-000000000001'::uuid
      )
  ),
  2::bigint,
  'W115: only owner/admin produce receipt.created audit in v1'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events ae
    join public.tenant_members tm
      on tm.tenant_id = ae.tenant_id
     and tm.user_id = ae.actor_user_id
    where ae.action = 'vehicle.registration_updated'
      and tm.role = 'receptionist'
  ),
  1::bigint,
  'W116: receptionist appears only on allowed registration update audit'
);

select is(
  (
    select count(*)::bigint
    from public.audit_events ae
    where ae.action in ('vehicle.registration_updated', 'receipt.created', 'customer.created', 'customer.updated', 'vehicle.created', 'vehicle.updated')
      and ae.created_at is not null
  ),
  11::bigint,
  'W117: audit rows have created_at timestamps'
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
  'W118: receptionist has both tenant_members and workshop_members for A1'
);

select * from finish();

rollback;
