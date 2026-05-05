-- RLS SELECT isolation tests (synthetic data only)
--
-- Assumptions:
--   * Runs after migrations 0001–0004 on local Supabase (Docker).
--   * auth.uid() reads JWT claim `request.jwt.claim.sub` (Supabase local).
--   * Tests use SET LOCAL ROLE authenticated for RLS evaluation.
--   * All emails are *.example.test; reg fields are fake placeholders.
--
-- Run:
--   npx supabase start
--   npx supabase db reset
--   npx supabase test db

begin;

create extension if not exists pgtap with schema extensions;

select set_config('search_path', 'extensions, public, pg_temp', true);

-- ---------------------------------------------------------------------------
-- Synthetic IDs (deterministic)
-- ---------------------------------------------------------------------------
-- tenant_a: 10000000-0000-4000-8000-000000000001
-- tenant_b: 20000000-0000-4000-8000-000000000002
-- ws_a1:     11000000-0000-4000-8000-000000000001
-- ws_a2:     12000000-0000-4000-8000-000000000002
-- ws_b1:     21000000-0000-4000-8000-000000000001

create or replace function pg_temp.rls_scalar_bigint(p_uid uuid, p_sql text)
returns bigint
language plpgsql
security invoker
set search_path = public
as $fn$
declare
  v bigint;
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  execute p_sql into strict v;
  reset role;
  return v;
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
-- Seed auth.users (minimal; local dev instance)
-- ---------------------------------------------------------------------------
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
select
  x.id,
  coalesce((select id from auth.instances limit 1), '00000000-0000-0000-0000-000000000000'::uuid),
  'authenticated',
  'authenticated',
  x.email,
  crypt('fake-password-not-used', gen_salt('bf')),
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
from (
  values
    ('a0000001-0000-4000-8000-000000000001'::uuid, 'owner.a@example.test'),
    ('a0000001-0000-4000-8000-000000000002'::uuid, 'owner.a.tenantonly@example.test'),
    ('a0000002-0000-4000-8000-000000000001'::uuid, 'admin.a@example.test'),
    ('a0000003-0000-4000-8000-000000000001'::uuid, 'mechanic.a1@example.test'),
    ('a0000004-0000-4000-8000-000000000001'::uuid, 'viewer.a2@example.test'),
    ('b0000001-0000-4000-8000-000000000001'::uuid, 'mechanic.b1@example.test'),
    ('e0000001-0000-4000-8000-000000000001'::uuid, 'no.membership@example.test'),
    ('5bad0001-0000-4000-8000-000000000001'::uuid, 'suspended.a@example.test'),
    ('6bad0001-0000-4000-8000-000000000001'::uuid, 'revoked.a@example.test')
) as x(id, email);

-- ---------------------------------------------------------------------------
-- Tenants & workshops
-- ---------------------------------------------------------------------------
insert into public.tenants (id, slug, legal_name, display_name)
values
  ('10000000-0000-4000-8000-000000000001', 'tenant-a-synth', 'Tenant A Synth AB', 'Tenant A'),
  ('20000000-0000-4000-8000-000000000002', 'tenant-b-synth', 'Tenant B Synth AB', 'Tenant B');

insert into public.workshops (id, tenant_id, code, name)
values
  ('11000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'A1', 'Workshop A1'),
  ('12000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'A2', 'Workshop A2'),
  ('21000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000002', 'B1', 'Workshop B1');

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
insert into public.profiles (user_id, full_name)
values
  ('a0000001-0000-4000-8000-000000000001', 'Synth Owner A'),
  ('a0000001-0000-4000-8000-000000000002', 'Synth Owner A Tenant Only'),
  ('a0000002-0000-4000-8000-000000000001', 'Synth Admin A'),
  ('a0000003-0000-4000-8000-000000000001', 'Synth Mechanic A1'),
  ('a0000004-0000-4000-8000-000000000001', 'Synth Viewer A2'),
  ('b0000001-0000-4000-8000-000000000001', 'Synth Mechanic B1'),
  ('e0000001-0000-4000-8000-000000000001', 'Synth No Membership'),
  ('5bad0001-0000-4000-8000-000000000001', 'Synth Suspended'),
  ('6bad0001-0000-4000-8000-000000000001', 'Synth Revoked');

-- ---------------------------------------------------------------------------
-- tenant_members
-- ---------------------------------------------------------------------------
insert into public.tenant_members (tenant_id, user_id, role, membership_status, is_default_tenant)
values
  ('10000000-0000-4000-8000-000000000001', 'a0000001-0000-4000-8000-000000000001', 'owner', 'active', false),
  ('10000000-0000-4000-8000-000000000001', 'a0000001-0000-4000-8000-000000000002', 'owner', 'active', false),
  ('10000000-0000-4000-8000-000000000001', 'a0000002-0000-4000-8000-000000000001', 'admin', 'active', false),
  ('10000000-0000-4000-8000-000000000001', 'a0000003-0000-4000-8000-000000000001', 'mechanic', 'active', false),
  ('10000000-0000-4000-8000-000000000001', 'a0000004-0000-4000-8000-000000000001', 'viewer', 'active', false),
  ('20000000-0000-4000-8000-000000000002', 'b0000001-0000-4000-8000-000000000001', 'mechanic', 'active', false),
  ('10000000-0000-4000-8000-000000000001', '5bad0001-0000-4000-8000-000000000001', 'mechanic', 'suspended', false),
  ('10000000-0000-4000-8000-000000000001', '6bad0001-0000-4000-8000-000000000001', 'mechanic', 'revoked', false);

-- ---------------------------------------------------------------------------
-- workshop_members (suspended/revoked: none; no_membership: none)
-- ---------------------------------------------------------------------------
insert into public.workshop_members (tenant_id, workshop_id, user_id, role, membership_status)
values
  ('10000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'a0000001-0000-4000-8000-000000000001', 'owner', 'active'),
  ('10000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000002', 'a0000001-0000-4000-8000-000000000001', 'owner', 'active'),
  ('10000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'a0000002-0000-4000-8000-000000000001', 'admin', 'active'),
  ('10000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'a0000003-0000-4000-8000-000000000001', 'mechanic', 'active'),
  ('10000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000002', 'a0000004-0000-4000-8000-000000000001', 'viewer', 'active'),
  ('20000000-0000-4000-8000-000000000002', '21000000-0000-4000-8000-000000000001', 'b0000001-0000-4000-8000-000000000001', 'mechanic', 'active');

-- ---------------------------------------------------------------------------
-- Domain rows (customers, vehicles, operational)
-- ---------------------------------------------------------------------------
insert into public.customers (id, tenant_id, workshop_id, customer_number, full_name, email)
values
  ('c0000001-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'CA1-001', 'Synth Customer A1', 'cust.a1@example.test'),
  ('c0000002-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000002', 'CA2-001', 'Synth Customer A2', 'cust.a2@example.test'),
  ('c0000003-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000002', '21000000-0000-4000-8000-000000000001', 'CB1-001', 'Synth Customer B1', 'cust.b1@example.test');

insert into public.vehicles (
  id, tenant_id, customer_id, workshop_id,
  make, model, reg_number_ciphertext, reg_number_hash, reg_number_last4
)
values
  (
    'd1e00001-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'c0000001-0000-4000-8000-000000000001',
    '11000000-0000-4000-8000-000000000001',
    'SynthMake', 'SynthModel', 'enc-placeholder-a1', digest('SYNTH-REG-A1', 'sha256'), '0001'
  ),
  (
    'd1e00002-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    'c0000002-0000-4000-8000-000000000002',
    '12000000-0000-4000-8000-000000000002',
    'SynthMake', 'SynthModel', 'enc-placeholder-a2', digest('SYNTH-REG-A2', 'sha256'), '0002'
  ),
  (
    'd1e00003-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002',
    'c0000003-0000-4000-8000-000000000003',
    '21000000-0000-4000-8000-000000000001',
    'SynthMake', 'SynthModel', 'enc-placeholder-b1', digest('SYNTH-REG-B1', 'sha256'), '0003'
  );

insert into public.bookings (
  id, tenant_id, workshop_id, customer_id, vehicle_id, booking_number,
  service_category, service_name, starts_at
)
values
  (
    'b0000001-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '11000000-0000-4000-8000-000000000001',
    'c0000001-0000-4000-8000-000000000001',
    'd1e00001-0000-4000-8000-000000000001',
    'BK-A1-001', 'verkstad', 'Synth Service', now()
  ),
  (
    'b0000002-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '12000000-0000-4000-8000-000000000002',
    'c0000002-0000-4000-8000-000000000002',
    'd1e00002-0000-4000-8000-000000000002',
    'BK-A2-001', 'service', 'Synth Service', now()
  ),
  (
    'b0000003-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002',
    '21000000-0000-4000-8000-000000000001',
    'c0000003-0000-4000-8000-000000000003',
    'd1e00003-0000-4000-8000-000000000003',
    'BK-B1-001', 'verkstad', 'Synth Service', now()
  );

insert into public.work_orders (
  id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, work_order_number, status
)
values
  (
    'e1e00001-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '11000000-0000-4000-8000-000000000001',
    'b0000001-0000-4000-8000-000000000001',
    'c0000001-0000-4000-8000-000000000001',
    'd1e00001-0000-4000-8000-000000000001',
    'WO-A1-001', 'in_progress'
  ),
  (
    'e1e00002-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '12000000-0000-4000-8000-000000000002',
    'b0000002-0000-4000-8000-000000000002',
    'c0000002-0000-4000-8000-000000000002',
    'd1e00002-0000-4000-8000-000000000002',
    'WO-A2-001', 'draft'
  ),
  (
    'e1e00003-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002',
    '21000000-0000-4000-8000-000000000001',
    'b0000003-0000-4000-8000-000000000003',
    'c0000003-0000-4000-8000-000000000003',
    'd1e00003-0000-4000-8000-000000000003',
    'WO-B1-001', 'done'
  );

insert into public.quotes (
  id, tenant_id, workshop_id, booking_id, customer_id, vehicle_id, quote_number, status
)
values
  (
    'f1e00001-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '11000000-0000-4000-8000-000000000001',
    'b0000001-0000-4000-8000-000000000001',
    'c0000001-0000-4000-8000-000000000001',
    'd1e00001-0000-4000-8000-000000000001',
    'QT-A1-001', 'sent'
  ),
  (
    'f1e00002-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '12000000-0000-4000-8000-000000000002',
    'b0000002-0000-4000-8000-000000000002',
    'c0000002-0000-4000-8000-000000000002',
    'd1e00002-0000-4000-8000-000000000002',
    'QT-A2-001', 'draft'
  ),
  (
    'f1e00003-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002',
    '21000000-0000-4000-8000-000000000001',
    'b0000003-0000-4000-8000-000000000003',
    'c0000003-0000-4000-8000-000000000003',
    'd1e00003-0000-4000-8000-000000000003',
    'QT-B1-001', 'approved'
  );

insert into public.quote_items (id, tenant_id, quote_id, line_number, description, line_total_amount)
values
  (
    '01e00001-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'f1e00001-0000-4000-8000-000000000001',
    1,
    'Synth line A1',
    100
  ),
  (
    '01e00002-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    'f1e00002-0000-4000-8000-000000000002',
    1,
    'Synth line A2',
    200
  ),
  (
    '01e00003-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002',
    'f1e00003-0000-4000-8000-000000000003',
    1,
    'Synth line B1',
    300
  );

insert into public.receipts (
  id, tenant_id, workshop_id, work_order_id, quote_id, customer_id, vehicle_id, receipt_number, payment_status
)
values
  (
    '02e00001-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '11000000-0000-4000-8000-000000000001',
    'e1e00001-0000-4000-8000-000000000001',
    'f1e00001-0000-4000-8000-000000000001',
    'c0000001-0000-4000-8000-000000000001',
    'd1e00001-0000-4000-8000-000000000001',
    'RC-A1-001',
    'paid'
  ),
  (
    '02e00002-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '12000000-0000-4000-8000-000000000002',
    'e1e00002-0000-4000-8000-000000000002',
    'f1e00002-0000-4000-8000-000000000002',
    'c0000002-0000-4000-8000-000000000002',
    'd1e00002-0000-4000-8000-000000000002',
    'RC-A2-001',
    'unpaid'
  ),
  (
    '02e00003-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002',
    '21000000-0000-4000-8000-000000000001',
    'e1e00003-0000-4000-8000-000000000003',
    'f1e00003-0000-4000-8000-000000000003',
    'c0000003-0000-4000-8000-000000000003',
    'd1e00003-0000-4000-8000-000000000003',
    'RC-B1-001',
    'paid'
  );

insert into public.tire_hotel (
  id, tenant_id, workshop_id, customer_id, vehicle_id, storage_code, season, status
)
values
  (
    '03e00001-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '11000000-0000-4000-8000-000000000001',
    'c0000001-0000-4000-8000-000000000001',
    'd1e00001-0000-4000-8000-000000000001',
    'TH-A1-001',
    'winter',
    'stored'
  ),
  (
    '03e00002-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '12000000-0000-4000-8000-000000000002',
    'c0000002-0000-4000-8000-000000000002',
    'd1e00002-0000-4000-8000-000000000002',
    'TH-A2-001',
    'summer',
    'stored'
  ),
  (
    '03e00003-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002',
    '21000000-0000-4000-8000-000000000001',
    'c0000003-0000-4000-8000-000000000003',
    'd1e00003-0000-4000-8000-000000000003',
    'TH-B1-001',
    'winter',
    'stored'
  );

-- ---------------------------------------------------------------------------
-- pgTAP plan
-- ---------------------------------------------------------------------------
select plan(32);

-- T1 / active tenant member reads own tenant
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.tenants where id = '10000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  1::bigint,
  'T1: mechanic A1 can read tenant A'
);

-- T2 / cannot read other tenant
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.tenants where id = '20000000-0000-4000-8000-000000000002'::uuid $q$
  ),
  0::bigint,
  'T2: mechanic A1 cannot read tenant B'
);

-- T3 / workshop member reads own workshop
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.workshops where id = '11000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  1::bigint,
  'T3: mechanic A1 can read workshop A1'
);

-- T4 / cannot read workshop without access (not tenant owner/admin)
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.workshops where id = '12000000-0000-4000-8000-000000000002'::uuid $q$
  ),
  0::bigint,
  'T4: mechanic A1 cannot read workshop A2'
);

-- T5 / tenant owner without workshop_membership lists all workshops in tenant
select is(
  pg_temp.rls_scalar_bigint(
    'a0000001-0000-4000-8000-000000000002'::uuid,
    $q$ select count(*)::bigint from public.workshops where tenant_id = '10000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  2::bigint,
  'T5: tenant-only owner reads both A workshops'
);

-- T6 / tenant-only owner still blocked from workshop-scoped bookings without workshop access
select is(
  pg_temp.rls_scalar_bigint(
    'a0000001-0000-4000-8000-000000000002'::uuid,
    $q$ select count(*)::bigint from public.bookings where workshop_id = '11000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  0::bigint,
  'T6: tenant-only owner cannot read bookings without workshop access'
);

-- T7 / viewer reads own profile
select is(
  pg_temp.rls_scalar_bigint(
    'a0000004-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.profiles where user_id = 'a0000004-0000-4000-8000-000000000001'::uuid $q$
  ),
  1::bigint,
  'T7: viewer A2 reads own profile'
);

-- T8 / viewer cannot read mechanic profile (not owner/admin)
select is(
  pg_temp.rls_scalar_bigint(
    'a0000004-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.profiles where user_id = 'a0000003-0000-4000-8000-000000000001'::uuid $q$
  ),
  0::bigint,
  'T8: viewer A2 cannot read mechanic A1 profile'
);

-- T9 / owner can read active member profile in tenant
select is(
  pg_temp.rls_scalar_bigint(
    'a0000001-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.profiles where user_id = 'a0000003-0000-4000-8000-000000000001'::uuid $q$
  ),
  1::bigint,
  'T9: owner A reads mechanic A1 profile'
);

-- T10 / admin can read active member profile
select is(
  pg_temp.rls_scalar_bigint(
    'a0000002-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.profiles where user_id = 'a0000003-0000-4000-8000-000000000001'::uuid $q$
  ),
  1::bigint,
  'T10: admin A reads mechanic A1 profile'
);

-- T11 / suspended denied tenant
select is(
  pg_temp.rls_scalar_bigint(
    '5bad0001-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.tenants where id = '10000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  0::bigint,
  'T11: suspended user cannot read tenant A'
);

-- T12 / suspended denied workshops
select is(
  pg_temp.rls_scalar_bigint(
    '5bad0001-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.workshops where tenant_id = '10000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  0::bigint,
  'T12: suspended user cannot read workshops'
);

-- T13 / revoked denied tenant
select is(
  pg_temp.rls_scalar_bigint(
    '6bad0001-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.tenants where id = '10000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  0::bigint,
  'T13: revoked user cannot read tenant A'
);

-- T14 / no membership denied
select is(
  pg_temp.rls_scalar_bigint(
    'e0000001-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.tenants $q$
  ),
  0::bigint,
  'T14: user without membership sees no tenants'
);

-- T15 / customers isolation by workshop
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.customers where id = 'c0000002-0000-4000-8000-000000000002'::uuid $q$
  ),
  0::bigint,
  'T15: mechanic A1 cannot read customer scoped to A2'
);

-- T16 / vehicles isolation
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.vehicles where id = 'd1e00002-0000-4000-8000-000000000002'::uuid $q$
  ),
  0::bigint,
  'T16: mechanic A1 cannot read vehicle A2'
);

-- T17 / bookings per workshop
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.bookings where id = 'b0000001-0000-4000-8000-000000000001'::uuid $q$
  ),
  1::bigint,
  'T17a: mechanic A1 reads booking A1'
);

select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.bookings where id = 'b0000002-0000-4000-8000-000000000002'::uuid $q$
  ),
  0::bigint,
  'T17b: mechanic A1 cannot read booking A2'
);

-- T18 / work_orders
select is(
  pg_temp.rls_scalar_bigint(
    'a0000004-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.work_orders where id = 'e1e00002-0000-4000-8000-000000000002'::uuid $q$
  ),
  1::bigint,
  'T18a: viewer A2 reads work order A2'
);

select is(
  pg_temp.rls_scalar_bigint(
    'a0000004-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.work_orders where id = 'e1e00001-0000-4000-8000-000000000001'::uuid $q$
  ),
  0::bigint,
  'T18b: viewer A2 cannot read work order A1'
);

-- T19 / quotes
select is(
  pg_temp.rls_scalar_bigint(
    'b0000001-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.quotes where id = 'f1e00003-0000-4000-8000-000000000003'::uuid $q$
  ),
  1::bigint,
  'T19a: mechanic B1 reads quote B1'
);

select is(
  pg_temp.rls_scalar_bigint(
    'b0000001-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.quotes where id = 'f1e00001-0000-4000-8000-000000000001'::uuid $q$
  ),
  0::bigint,
  'T19b: mechanic B1 cannot read quote A1'
);

-- T20 / quote_items cannot be read via other tenant quote
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.quote_items where id = '01e00003-0000-4000-8000-000000000003'::uuid $q$
  ),
  0::bigint,
  'T20: mechanic A1 cannot read quote_item for tenant B quote'
);

-- T21 / receipts
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.receipts where id = '02e00001-0000-4000-8000-000000000001'::uuid $q$
  ),
  1::bigint,
  'T21a: mechanic A1 reads receipt A1'
);

select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.receipts where id = '02e00002-0000-4000-8000-000000000002'::uuid $q$
  ),
  0::bigint,
  'T21b: mechanic A1 cannot read receipt A2'
);

-- T22 / tire_hotel
select is(
  pg_temp.rls_scalar_bigint(
    'a0000004-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.tire_hotel where id = '03e00002-0000-4000-8000-000000000002'::uuid $q$
  ),
  1::bigint,
  'T22a: viewer A2 reads tire_hotel A2'
);

select is(
  pg_temp.rls_scalar_bigint(
    'a0000004-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.tire_hotel where id = '03e00001-0000-4000-8000-000000000001'::uuid $q$
  ),
  0::bigint,
  'T22b: viewer A2 cannot read tire_hotel A1'
);

-- T23 / admin sees all workshops in tenant via tenant role
select is(
  pg_temp.rls_scalar_bigint(
    'a0000002-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.workshops where tenant_id = '10000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  2::bigint,
  'T23: admin A reads both workshops (tenant role path)'
);

-- T24 / cross-tenant profile: B mechanic cannot read A profile
select is(
  pg_temp.rls_scalar_bigint(
    'b0000001-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.profiles where user_id = 'a0000003-0000-4000-8000-000000000001'::uuid $q$
  ),
  0::bigint,
  'T24: mechanic B1 cannot read mechanic A1 profile'
);

-- T25 / tenant_members: viewer sees only self
select is(
  pg_temp.rls_scalar_bigint(
    'a0000004-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.tenant_members where tenant_id = '10000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  1::bigint,
  'T25: viewer A2 sees only own tenant_members row in A'
);

-- T26 / tenant_members: admin sees many
select ok(
  pg_temp.rls_scalar_bigint(
    'a0000002-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.tenant_members where tenant_id = '10000000-0000-4000-8000-000000000001'::uuid $q$
  ) >= 4,
  'T26: admin A sees multiple tenant_members in A'
);

-- T27 / workshop_members: mechanic A1 sees self row(s)
select is(
  pg_temp.rls_scalar_bigint(
    'a0000003-0000-4000-8000-000000000001'::uuid,
    $q$ select count(*)::bigint from public.workshop_members where workshop_id = '11000000-0000-4000-8000-000000000001'::uuid $q$
  ),
  1::bigint,
  'T27: mechanic A1 reads own workshop_members for A1'
);

select * from finish();

rollback;
