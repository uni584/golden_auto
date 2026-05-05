-- Golden Auto - Initial Supabase/Postgres schema draft
-- Phase: 0001
-- Notes:
--   * Schema only (no RLS policies yet).
--   * Multi-tenant by `tenant_id` on operational tables.
--   * Vehicle registration number is treated as sensitive data.

create extension if not exists "pgcrypto";

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  legal_name text not null,
  display_name text not null,
  org_number text,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workshops (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  code text not null,
  name text not null,
  timezone text not null default 'Europe/Stockholm',
  email text,
  phone text,
  address jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, code)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  workshop_id uuid references public.workshops(id) on delete set null,
  customer_number text,
  full_name text not null,
  email text,
  phone text,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, customer_number)
);

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  workshop_id uuid references public.workshops(id) on delete set null,
  vin text,
  make text not null,
  model text not null,
  model_year integer,
  color text,
  odometer_km bigint,
  reg_number_ciphertext text not null,
  reg_number_hash bytea not null,
  reg_number_last4 varchar(4),
  reg_country_code char(2) not null default 'SE',
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, reg_number_hash)
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  workshop_id uuid not null references public.workshops(id) on delete restrict,
  customer_id uuid references public.customers(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  booking_number text not null,
  source text not null default 'web',
  service_category text not null,
  service_name text not null,
  status text not null default 'new' check (status in ('new', 'confirmed', 'checked_in', 'in_progress', 'awaiting', 'done', 'delivered', 'cancelled')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, booking_number)
);

create table if not exists public.work_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  workshop_id uuid not null references public.workshops(id) on delete restrict,
  booking_id uuid references public.bookings(id) on delete set null,
  customer_id uuid not null references public.customers(id) on delete restrict,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  work_order_number text not null,
  status text not null default 'draft' check (status in ('draft', 'in_progress', 'done', 'invoiced', 'cancelled')),
  assigned_to_label text,
  labor_minutes integer,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, work_order_number)
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  workshop_id uuid not null references public.workshops(id) on delete restrict,
  booking_id uuid references public.bookings(id) on delete set null,
  customer_id uuid not null references public.customers(id) on delete restrict,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  quote_number text not null,
  status text not null default 'draft' check (status in ('draft', 'sent', 'approved', 'rejected', 'expired', 'cancelled')),
  valid_until date,
  currency char(3) not null default 'SEK',
  subtotal_amount numeric(12,2) not null default 0,
  vat_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, quote_number)
);

create table if not exists public.quote_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  quote_id uuid not null references public.quotes(id) on delete cascade,
  line_number integer not null,
  item_type text not null default 'service' check (item_type in ('service', 'part', 'fee', 'discount', 'other')),
  description text not null,
  quantity numeric(12,2) not null default 1,
  unit_price numeric(12,2) not null default 0,
  vat_rate numeric(5,2) not null default 25,
  line_total_amount numeric(12,2) not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (quote_id, line_number)
);

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  workshop_id uuid not null references public.workshops(id) on delete restrict,
  work_order_id uuid references public.work_orders(id) on delete set null,
  quote_id uuid references public.quotes(id) on delete set null,
  customer_id uuid not null references public.customers(id) on delete restrict,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  receipt_number text not null,
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'paid', 'partially_paid', 'refunded', 'voided')),
  issued_at timestamptz not null default now(),
  paid_at timestamptz,
  currency char(3) not null default 'SEK',
  subtotal_amount numeric(12,2) not null default 0,
  vat_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, receipt_number)
);

create table if not exists public.tire_hotel (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  workshop_id uuid not null references public.workshops(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  storage_code text not null,
  rack text,
  slot integer,
  season text not null check (season in ('winter', 'summer', 'all_season')),
  tire_brand_model text,
  tire_dimension text,
  tread_depth_mm numeric(4,1),
  status text not null default 'stored' check (status in ('stored', 'reserved', 'withdrawn', 'discarded')),
  stored_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, storage_code)
);

create index if not exists idx_workshops_tenant_id on public.workshops (tenant_id);
create index if not exists idx_customers_tenant_id on public.customers (tenant_id);
create index if not exists idx_customers_workshop_id on public.customers (workshop_id);
create index if not exists idx_vehicles_tenant_id on public.vehicles (tenant_id);
create index if not exists idx_vehicles_customer_id on public.vehicles (customer_id);
create index if not exists idx_vehicles_reg_hash on public.vehicles (tenant_id, reg_number_hash);
create index if not exists idx_bookings_tenant_id on public.bookings (tenant_id);
create index if not exists idx_bookings_workshop_id on public.bookings (workshop_id);
create index if not exists idx_bookings_starts_at on public.bookings (starts_at);
create index if not exists idx_bookings_status on public.bookings (status);
create index if not exists idx_work_orders_tenant_id on public.work_orders (tenant_id);
create index if not exists idx_work_orders_booking_id on public.work_orders (booking_id);
create index if not exists idx_work_orders_customer_id on public.work_orders (customer_id);
create index if not exists idx_work_orders_vehicle_id on public.work_orders (vehicle_id);
create index if not exists idx_quotes_tenant_id on public.quotes (tenant_id);
create index if not exists idx_quotes_booking_id on public.quotes (booking_id);
create index if not exists idx_quote_items_quote_id on public.quote_items (quote_id);
create index if not exists idx_receipts_tenant_id on public.receipts (tenant_id);
create index if not exists idx_receipts_work_order_id on public.receipts (work_order_id);
create index if not exists idx_receipts_quote_id on public.receipts (quote_id);
create index if not exists idx_tire_hotel_tenant_id on public.tire_hotel (tenant_id);
create index if not exists idx_tire_hotel_vehicle_id on public.tire_hotel (vehicle_id);
create index if not exists idx_tire_hotel_status on public.tire_hotel (status);

create trigger trg_tenants_updated_at
before update on public.tenants
for each row execute function public.set_updated_at();

create trigger trg_workshops_updated_at
before update on public.workshops
for each row execute function public.set_updated_at();

create trigger trg_customers_updated_at
before update on public.customers
for each row execute function public.set_updated_at();

create trigger trg_vehicles_updated_at
before update on public.vehicles
for each row execute function public.set_updated_at();

create trigger trg_bookings_updated_at
before update on public.bookings
for each row execute function public.set_updated_at();

create trigger trg_work_orders_updated_at
before update on public.work_orders
for each row execute function public.set_updated_at();

create trigger trg_quotes_updated_at
before update on public.quotes
for each row execute function public.set_updated_at();

create trigger trg_quote_items_updated_at
before update on public.quote_items
for each row execute function public.set_updated_at();

create trigger trg_receipts_updated_at
before update on public.receipts
for each row execute function public.set_updated_at();

create trigger trg_tire_hotel_updated_at
before update on public.tire_hotel
for each row execute function public.set_updated_at();
