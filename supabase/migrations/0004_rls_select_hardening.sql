-- Golden Auto - Harden SELECT RLS layer (pre-write)
-- Phase: 0004
-- Notes:
--   * No write policies.
--   * No FORCE ROW LEVEL SECURITY (see docs).
--   * Tightens helper EXECUTE grants and two SELECT policies.

-- ---------------------------------------------------------------------------
-- 1) Helper function EXECUTE scope
--
-- Default grants on new functions often include PUBLIC. Anonymous clients must
-- not be able to invoke membership helpers (information disclosure / probing).
-- Only authenticated sessions (JWT) should call these; RLS policies use them
-- as SECURITY DEFINER with fixed search_path.
-- ---------------------------------------------------------------------------

revoke execute on function public.current_user_is_active_tenant_member(uuid) from public;
revoke execute on function public.current_user_has_tenant_role(uuid, text[]) from public;
revoke execute on function public.current_user_has_workshop_access(uuid, uuid) from public;
revoke execute on function public.current_user_has_workshop_role(uuid, uuid, text[]) from public;

revoke execute on function public.current_user_is_active_tenant_member(uuid) from anon;
revoke execute on function public.current_user_has_tenant_role(uuid, text[]) from anon;
revoke execute on function public.current_user_has_workshop_access(uuid, uuid) from anon;
revoke execute on function public.current_user_has_workshop_role(uuid, uuid, text[]) from anon;

grant execute on function public.current_user_is_active_tenant_member(uuid) to authenticated;
grant execute on function public.current_user_has_tenant_role(uuid, text[]) to authenticated;
grant execute on function public.current_user_has_workshop_access(uuid, uuid) to authenticated;
grant execute on function public.current_user_has_workshop_role(uuid, uuid, text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) profiles: least-privilege SELECT
--
-- Self always; tenant owner/admin may read profiles of users with active
-- membership in that tenant. No cross-tenant. Non-admin roles do not get
-- blanket peer profile reads.
-- ---------------------------------------------------------------------------

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
    where tm_target.user_id = profiles.user_id
      and tm_target.membership_status = 'active'
      and public.current_user_has_tenant_role(
        tm_target.tenant_id,
        array['owner', 'admin']::text[]
      )
  )
);

-- ---------------------------------------------------------------------------
-- 3) workshops: tenant owner/admin sees all workshops in tenant (SaaS admin)
--
-- Operational roles still require active workshop_membership for workshop rows.
-- Domain tables (bookings, etc.) remain workshop-scoped via existing policies.
-- ---------------------------------------------------------------------------

drop policy if exists workshops_select_scoped on public.workshops;

create policy workshops_select_scoped
on public.workshops
for select
to authenticated
using (
  public.current_user_has_workshop_access(tenant_id, id)
  or public.current_user_has_tenant_role(
    tenant_id,
    array['owner', 'admin']::text[]
  )
);
