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

- `workshops_select_scoped` pa `workshops`
  - Lasning tillaten endast for workshops dar anvandaren har `active` workshop-access.

- `profiles_select_scoped` pa `profiles`
  - Anvandaren kan lasa egen profil.
  - Anvandaren kan lasa profiler for andra anvandare inom samma aktiva tenant.

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

## Nasta steg: write-policies (0004+)

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

Identifierade risker/observationer:

- **R1 - Function execute scope:** helper functions har `grant execute ... to authenticated`, men explicit revoke fran `public`/`anon` ar inte dokumenterad i `0003`. Detta kan ge oonskad boolean-oracle-yta i miljor dar `public` fortfarande har execute.
- **R2 - Profile breadth:** `profiles_select_scoped` later all aktiva medlemmar i samma tenant lasa varandras profiler. Detta kan vara bredare an minsta nodvandiga dataatkomst beroende pa vilka PII-falt som fylls i `profiles`.
- **R3 - Future FORCE RLS recursion hazard:** om `FORCE ROW LEVEL SECURITY` senare aktiveras pa `tenant_members`/`workshop_members` utan separat strategi kan helper-funktioner som laser dessa tabeller trigga recursion/policy-loop.
- **R4 - Workshop visibility design tradeoff:** `workshops_select_scoped` kraver workshop-membership. Tenant owner/admin utan explicit workshop_members-rad far ingen workshop-listning. Detta ar inte datalacka, men kan ge oavsiktlig hard blockering i drift.

Bedomning:

- Ingen uppenbar direkt cross-tenant-lacka i `0003`-logiken.
- `quote_items_select_scoped` ar korrekt kopplad via `quotes` + workshop-access och minskar indirekt tenant-bypass-risk.
- `customers`/`vehicles` ar tenant-isolerade och workshop-isolerade nar `workshop_id` finns; rader med `workshop_id is null` ar medvetet tenant-lasa.

## Rekommendation innan write-policies

Status: **Redo med villkorad hardning**.

Innan eller i samband med write-policy-migrationen bor foljande goras:

- Revoke execute pa helper-funktioner fran roller som inte ska kunna kalla dem (minst `public`, ev. `anon`) och behall explicit grant till `authenticated`.
- Besluta om `profiles` ska vara:
  - self-only for icke-admin roller, eller
  - tenant-shared med faltbegransning via vyer.
- Definiera strategi innan ev. `FORCE RLS` aktiveras pa membership-tabeller for att undvika recursion.
- Verifiera med testsvit i `docs/RLS_VERIFICATION_PLAN.md` och krava full PASS fore write-policies.
