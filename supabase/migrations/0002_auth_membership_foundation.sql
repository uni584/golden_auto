-- Golden Auto - Auth and membership foundation for future RLS
-- Phase: 0002
-- Notes:
--   * Adds secure linkage from auth.users to tenant/workshop scopes.
--   * No RLS policies in this migration.

-- Ensure composite FK support for workshop scoping.
create unique index if not exists uq_workshops_tenant_id_id
on public.workshops (tenant_id, id);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tenant_members (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'mechanic', 'receptionist', 'viewer')),
  membership_status text not null default 'active' check (membership_status in ('invited', 'active', 'suspended', 'revoked')),
  is_default_tenant boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, user_id)
);

create table if not exists public.workshop_members (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  workshop_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'mechanic', 'receptionist', 'viewer')),
  membership_status text not null default 'active' check (membership_status in ('invited', 'active', 'suspended', 'revoked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workshop_id, user_id),
  foreign key (tenant_id, workshop_id)
    references public.workshops (tenant_id, id)
    on delete cascade,
  foreign key (tenant_id, user_id)
    references public.tenant_members (tenant_id, user_id)
    on delete cascade
);

create index if not exists idx_profiles_is_active
on public.profiles (is_active);

create index if not exists idx_tenant_members_user_id
on public.tenant_members (user_id);

create index if not exists idx_tenant_members_tenant_role
on public.tenant_members (tenant_id, role);

create unique index if not exists uq_tenant_members_default_tenant
on public.tenant_members (user_id)
where is_default_tenant = true and membership_status = 'active';

create index if not exists idx_workshop_members_user_id
on public.workshop_members (user_id);

create index if not exists idx_workshop_members_workshop_role
on public.workshop_members (workshop_id, role);

create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger trg_tenant_members_updated_at
before update on public.tenant_members
for each row execute function public.set_updated_at();

create trigger trg_workshop_members_updated_at
before update on public.workshop_members
for each row execute function public.set_updated_at();
