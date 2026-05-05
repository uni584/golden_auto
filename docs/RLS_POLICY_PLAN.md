# RLS POLICY PLAN (PHASE 0003)

Detta dokument beskriver den forsta RLS-implementeringen och nasta steg.

## Tabeller med RLS aktiverat

- `tenants`
- `workshops`
- `profiles`
- `tenant_members`
- `workshop_members`
- `customers`
- `vehicles`
- `bookings`
- `work_orders`
- `quotes`
- `quote_items`
- `receipts`
- `tire_hotel`

## Helper functions for policy-evaluering

- `current_user_is_active_tenant_member(tenant_id uuid)`
  - True endast om `auth.uid()` har `active` medlemskap i tenant.
- `current_user_has_tenant_role(tenant_id uuid, roles text[])`
  - True endast om `auth.uid()` har `active` medlemskap + efterfragad tenant-roll.
- `current_user_has_workshop_access(tenant_id uuid, workshop_id uuid)`
  - True endast om `auth.uid()` har `active` workshop-medlemskap for given tenant/workshop.
- `current_user_has_workshop_role(tenant_id uuid, workshop_id uuid, roles text[])`
  - True endast om `auth.uid()` har `active` workshop-medlemskap + efterfragad workshop-roll.

Varfor helper functions behovs:

- Undviker duplicerad och svargranskad policylogik pa varje tabell.
- Ger enhetlig tolkning av `active` medlemskap for tenant/workshop.
- Minskar risk for policyglapp nar fler write-policies tillkommer.
- Gor framtida policyhardning enklare (rollregler, helper-funktioner, constraints).

## SELECT-policies som skapats

- `tenant_select_scoped` pa `tenants`
  - Lasning tillaten endast for tenants dar anvandaren ar `active` tenant-member.

- `workshops_select_scoped` pa `workshops` (0003; se hardning i `0004`)
  - Bas: `active` workshop-medlemskap ger lasning av den workshopen.
  - Efter `0004`: `owner`/`admin` med aktivt tenant-medlemskap far lasa alla workshops inom samma tenant aven utan `workshop_members`-rad (SaaS-/tenant-admin).

- `profiles_select_scoped` pa `profiles` (0003; se hardning i `0004`)
  - Efter `0004`: egen profil alltid; andras profiler endast om mal-anvandaren har `active` tenant-medlemskap och lasaren ar `owner`/`admin` i samma tenant. Ovriga roller far inte automatiskt lasa kollegors profiler.

- `tenant_members_select_scoped` pa `tenant_members`
  - Anvandaren kan lasa egna medlemskapsrader.
  - `owner/admin` pa tenant kan lasa alla tenant-members i tenant.

- `workshop_members_select_scoped` pa `workshop_members`
  - Anvandaren kan lasa egna workshop-medlemskap.
  - `owner/admin` pa workshop eller tenant kan lasa workshop-members.

- `customers_select_scoped` pa `customers`
- `vehicles_select_scoped` pa `vehicles`
  - Kraver aktivt tenant-medlemskap.
  - Om `workshop_id` finns kravs dessutom workshop-access.
  - Om `workshop_id` ar `null` tillats tenant-scope-lasning.

- `bookings_select_scoped` pa `bookings`
- `work_orders_select_scoped` pa `work_orders`
- `quotes_select_scoped` pa `quotes`
- `receipts_select_scoped` pa `receipts`
- `tire_hotel_select_scoped` pa `tire_hotel`
  - Lasning tillaten endast med workshop-access i korrekt tenant/workshop.

- `quote_items_select_scoped` pa `quote_items`
  - Lasning styrs via kopplad `quotes`-rad med workshop-access.

## Roller och lasa-atkomst i detta steg

Roller: `owner`, `admin`, `mechanic`, `receptionist`, `viewer`.

- Alla roller kan lasa domandata inom scope dar de har aktiv membership och workshop-access.
- `owner/admin` har utokad lasratt till membership-tabeller inom egen tenant/workshop.
- Inga rollspecifika begransningar for domanlasning utover tenant/workshop-scope ar tillagda an.

## Medvetet ej gjort i 0003

- Inga `INSERT/UPDATE/DELETE`-policies.
- Inga service-role-antaganden i klientflode.
- Ingen policy for audit-logg-skrivning fran klient.
- Ingen kolumnniva-masking av kansliga falt (t.ex. regnr-ciphertext/last4) i SQL-vyer an.

## SELECT-hardning (0004)

Migration: `supabase/migrations/0004_rls_select_hardening.sql`

- **Helper EXECUTE:** `REVOKE EXECUTE` fran `PUBLIC` och `anon` pa alla fyra RLS-helpers; `GRANT EXECUTE` endast till `authenticated`. Motivering: minska anonym/extra yta for membership-probing; helpers ar avsedda for autentiserade klienter och policy-evaluering.
- **`profiles`:** policy ersatt med self + owner/admin for aktiva medlemmar i samma tenant (ingen cross-tenant).
- **`workshops`:** tenant `owner`/`admin` far lista alla workshops i tenant utan workshop_membership; ovriga roller behover `active` workshop-access som tidigare.

## FORCE ROW LEVEL SECURITY (medvetet ej i 0004)

- `FORCE ROW LEVEL SECURITY` aktiveras **inte** har: det kan fa Postgres att tillampa RLS aven for table owner och riskerar svarigheter med `SECURITY DEFINER`-helpers som laser `tenant_members`/`workshop_members` (mojlig policy-recursion eller blokering om policies inte ar omformulerade).
- Innan FORCE RLS:
  - verifiera alla policies som anropar helpers mot `tenant_members`/`workshop_members`;
  - overvag dedikerade `SECURITY DEFINER`-lasvagar eller `BY PASSRLS`-begransade roller endast for kontrollerad server-side drift;
  - testa med staging-data att inga infinite recursion-fel uppstar pa SELECT.
- Framtida strategi: introducera FORCE RLS forst nar write-policies och ev. separata "policy-safe" interna funktioner ar pa plats och verifieringsplanen ar gron.

## Nasta steg: write-policies (0005+)

- Definiera separata write-regler per tabell:
  - `owner/admin`: tenant/workshop administration
  - `mechanic/receptionist`: operativa tabeller enligt arbetsflode
  - `viewer`: normalt read-only
- Lagg till `WITH CHECK`-policies for att forhindra cross-tenant/workshop writes.
- Hard-koppla `created_by`/`updated_by` till `auth.uid()` via policies/triggers dar relevant.
- Overvag `FORCE ROW LEVEL SECURITY` nar drift/setupfloden ar etablerade.

## Sakerhetsrisker och antaganden

- Antagande: medlemskapshantering (invites, revoke, rollbyte) kommer ske via server-side/RPC med strikt write-policy i nasta steg.
- Risk utan write-policies: tabeller blir read-isolerade men writes ar inte oppnade kontrollerat for klient.
- `vehicles` innehaller kanslig registreringsdata; RLS isolerar tenant/workshop men ytterligare datamaskning/least-privilege vyer kan behovas.
- `security definer`-funktioner forutsatter kontrollerad agare och oforandrad deployprocess.

## Sakerhetsgranskning av 0003 (logisk)

Granskad yta:

- Helper functions (`auth.uid()`, `active` status-check, role/workshop checks)
- `security definer` och `search_path`
- grants pa helper functions
- SELECT-policies per tabell
- risk for recursion
- risk for cross-tenant access
- risk for for bred profile/membership-lasning

Identifierade risker/observationer (0003; delvis atgardade i 0004):

- **R1 - Function execute scope:** atgardad i `0004` (revoke fran `PUBLIC`/`anon`, grant endast `authenticated`).
- **R2 - Profile breadth:** atgardad i `0004` (endast owner/admin ser andras profiler, och endast for `active` tenant-medlemmar i samma tenant).
- **R3 - Future FORCE RLS recursion hazard:** oforandrat; FORCE RLS infors inte i `0004` (se avsnitt ovan).
- **R4 - Workshop visibility design tradeoff:** atgardad i `0004` for tenant `owner`/`admin` (workshop-listning inom tenant utan workshop_membership).

Bedomning:

- Ingen uppenbar direkt cross-tenant-lacka i `0003`-logiken.
- `quote_items_select_scoped` ar korrekt kopplad via `quotes` + workshop-access och minskar indirekt tenant-bypass-risk.
- `customers`/`vehicles` ar tenant-isolerade och workshop-isolerade nar `workshop_id` finns; rader med `workshop_id is null` ar medvetet tenant-lasa.

## Rekommendation innan write-policies

Status efter `0004`: **narmare produktion**, fortfarande **krav pa gron verifieringssvit** fore write-policies.

Kvar efter `0004`:

- Kor full testsvit i `docs/RLS_VERIFICATION_PLAN.md` (inkl. nya fall efter hardning).
- Planera FORCE RLS separat (se avsnitt ovan).
- Write-policies (`0005+`) med `WITH CHECK` och rollmatris.
