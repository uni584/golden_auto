# RLS VERIFICATION PLAN (PRE-WRITE POLICIES)

Detta dokument beskriver en saker verifieringsfas for RLS SELECT-lagret (`0003` + hardning `0004`) innan write-policies byggs.

## Lokal migreringsverifiering (genomford)

Miljo och kommando:

- Docker Desktop var igang (lokal Postgres for Supabase-stacken).
- Supabase CLI anropades via `npx supabase` (ingen global `supabase`-binary kravdes).
- `npx supabase db reset` kordes fran PowerShell pa branch `main`.

Resultat (migrationer applicerade utan avbrott):

- `0001_initial_schema.sql`
- `0002_auth_membership_foundation.sql`
- `0003_rls_helpers_and_select_policies.sql`
- `0004_rls_select_hardening.sql`

Log-notiser som ar forvantade och ofarliga:

- `DROP POLICY IF EXISTS ... does not exist, skipping` i `0003` vid forsta reset: policies fanns annu inte; kommandot ar idempotent.

Log-notiser som inte blockerar:

- `WARN: no files matched pattern: supabase/seed.sql`: ingen seed-fil ar checkad in; reset lyckades anda. Lagg till `supabase/seed.sql` senare om syntetisk testdata ska laddas automatiskt.

Sakerhet och data:

- Ingen riktig kunddata anvandes; endast schema/migrationer applicerades.

Nasta steg (efter lyckad reset):

- Ladda **syntetisk** RLS-testdata och kor testsviten (T1–T17) i denna fil, **eller** fortsatt planering av write-policies (`INSERT`/`UPDATE`/`DELETE`) i separat migration nar SELECT-verifieringen ar gron.

**Obs:** Reset bevisar att SQL-migrationerna ar syntaktiskt tillampningsbara och att databasen startar; den ersatter inte full RLS-testkorning med impersonering/JWT.

## 1) Mal med verifieringsfasen

- Bekrafta tenant-isolering for alla SELECT-policies.
- Bekrafta workshop-isolering dar `workshop_id` finns.
- Bekrafta att endast `active` membership ger access.
- Bekrafta att `suspended` och `revoked` nekas.
- Bekrafta att `quote_items` inte kan lasas via annan tenant.
- Bekrafta att kanslig fordonsdata (inkl. registreringsnummer-falt) ar RLS-isolerad.

## 2) Testmiljo och testidentiteter

Skapa endast syntetiska testdata:

- Tenant A
- Tenant B
- Workshop A1, A2 (under Tenant A)
- Workshop B1 (under Tenant B)

Anvandarprofiler (auth.users + membership):

- A_owner (owner, tenant A, workshop A1+A2)
- A_admin (admin, tenant A, workshop A1+A2)
- A_mechanic_A1 (mechanic, tenant A, workshop A1)
- A_receptionist_A2 (receptionist, tenant A, workshop A2)
- A_viewer_A1 (viewer, tenant A, workshop A1)
- A_tenant_owner_no_workshop (owner, tenant A, **saknar** `workshop_members`-rader; endast `tenant_members`)
- B_owner (owner, tenant B, workshop B1)
- No_membership_user (ingen tenant_members rad)
- Suspended_user_A (tenant_members/workshop_members = suspended)
- Revoked_user_A (tenant_members/workshop_members = revoked)

## 3) Testmetod (utan destruktiva tester)

- Kor endast SELECT-verifiering och metadata-kontroller.
- Inga DELETE/TRUNCATE/drop-kommandon.
- Inga write-policies testas i denna fas.

Om Supabase CLI finns:

- Anvand lokal dev-db och kor migrationer i ordning.
- Kor testfallen via SQL (impersonering per user-sub).

Om Supabase CLI saknas:

- Kor tester senare i staging/projektets Supabase SQL Editor.
- Impersonera anvandare med JWT-claims per session:
  - satt `request.jwt.claim.role = authenticated`
  - satt `request.jwt.claim.sub = <test_user_uuid>`
- Exempel:
  - `select set_config('request.jwt.claim.role', 'authenticated', true);`
  - `select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);`

## 4) Kritiska tabeller/policies att validera

Maste testas:

- `tenants` / `tenant_select_scoped`
- `workshops` / `workshops_select_scoped`
- `tenant_members` / `tenant_members_select_scoped`
- `workshop_members` / `workshop_members_select_scoped`
- `customers` / `customers_select_scoped`
- `vehicles` / `vehicles_select_scoped`
- `bookings` / `bookings_select_scoped`
- `work_orders` / `work_orders_select_scoped`
- `quotes` / `quotes_select_scoped`
- `quote_items` / `quote_items_select_scoped`
- `receipts` / `receipts_select_scoped`
- `tire_hotel` / `tire_hotel_select_scoped`

Hogst prioritet (mest kritiska):

- `vehicles_select_scoped` (kanslig regnr-data i tabellen)
- `quote_items_select_scoped` (indirekt scope via `quotes`)
- `profiles_select_scoped` (risk for for bred intern persondata-lasning)
- `tenant_members_select_scoped` + `workshop_members_select_scoped` (RLS-karnan)

## 5) Testfall for SELECT (med PASS/FAIL)

### T1: Aktiv tenant-medlem kan lasa egen tenant
- User: A_owner
- Query: `select id from public.tenants where id = <tenant_a_id>;`
- PASS: 1 rad (tenant A)
- FAIL: 0 rader

### T2: Aktiv tenant-medlem kan inte lasa annan tenant
- User: A_owner
- Query: `select id from public.tenants where id = <tenant_b_id>;`
- PASS: 0 rader
- FAIL: >=1 rad

### T3: Workshop-medlem kan lasa sin workshop
- User: A_mechanic_A1
- Query: `select id from public.workshops where id = <workshop_a1_id>;`
- PASS: 1 rad
- FAIL: 0 rader

### T4: Workshop-medlem kan inte lasa annan workshop utan access
- User: A_mechanic_A1
- Query: `select id from public.workshops where id = <workshop_a2_id>;`
- PASS: 0 rader
- FAIL: >=1 rad

### T5: Suspended user nekas tenant/workshop data
- User: Suspended_user_A
- Query: SELECT mot `tenants`, `workshops`, `customers`, `vehicles`
- PASS: 0 rader pa samtliga
- FAIL: nagon rad returneras

### T6: Revoked user nekas tenant/workshop data
- User: Revoked_user_A
- Query: SELECT mot samma tabeller som T5
- PASS: 0 rader pa samtliga
- FAIL: nagon rad returneras

### T7: User utan membership nekas all scoped data
- User: No_membership_user
- Query: SELECT mot alla RLS-tabeller
- PASS: 0 rader pa samtliga
- FAIL: nagon rad returneras

### T8: `quote_items` kan inte lasas via annan tenant
- User: A_owner
- Query: JOIN/SELECT pa quote_items kopplade till Tenant B quote
- PASS: 0 rader
- FAIL: >=1 rad

### T9: `vehicles` isoleras korrekt
- User: A_receptionist_A2
- Query: `select id from public.vehicles where workshop_id = <workshop_a1_id>;`
- PASS: 0 rader (ingen A1-access)
- FAIL: >=1 rad

### T10: `customers` isoleras korrekt
- User: A_viewer_A1
- Query: `select id from public.customers where workshop_id = <workshop_b1_id>;`
- PASS: 0 rader
- FAIL: >=1 rad

### T11: Membership-lasa begransas korrekt
- User: A_viewer_A1
- Query: `select * from public.tenant_members where tenant_id = <tenant_a_id>;`
- PASS: endast egna rader
- FAIL: andra anvandares membership-rader syns

### T12: Admin kan lasa membership inom scope
- User: A_admin
- Query: `select * from public.tenant_members where tenant_id = <tenant_a_id>;`
- PASS: flera rader inom tenant A syns, inga fran tenant B
- FAIL: tenant B rader syns eller tenant A blockerad

### T13: Viewer kan inte lasa annan anvandares profil (samma tenant)
- User: A_viewer_A1
- Query: `select user_id from public.profiles where user_id = <a_mechanic_a1_user_id>;`
- PASS: 0 rader
- FAIL: >=1 rad

### T14: Owner kan lasa aktiv kollegas profil (samma tenant)
- User: A_owner
- Query: `select user_id from public.profiles where user_id = <a_mechanic_a1_user_id>;`
- PASS: 1 rad (mekanikern ar `active` tenant-medlem i A)
- FAIL: 0 rader

### T15: Tenant owner/admin utan workshop_membership kan lista workshops i tenant
- User: A_tenant_owner_no_workshop
- Query: `select id from public.workshops where tenant_id = <tenant_a_id>;`
- PASS: rader for A1 och A2 (minst 2 om tva workshops finns)
- FAIL: 0 rader

### T16: Tenant owner utan workshop_membership har fortfarande inte workshop-scoped domandata
- User: A_tenant_owner_no_workshop
- Query: `select id from public.bookings where workshop_id = <workshop_a1_id>;`
- PASS: 0 rader (policy kraver fortfarande workshop-access)
- FAIL: >=1 rad

### T17: Helper functions ar inte kallbara som anon (om session kan sattas till anon)
- Session: `request.jwt.claim.role = anon` (eller motsvarande test)
- Query: `select public.current_user_is_active_tenant_member('<tenant_a_id>'::uuid);`
- PASS: fel eller nekad execute / inget resultat som avslöjar medlemskap
- FAIL: funktionen returnerar konsekvent true/false for utomstaende

## 6) Kompletterande granskningskontroller

- Kontrollera att helper functions har:
  - `security definer`
  - explicit `set search_path = public`
  - `stable`
- Kontrollera att inga policies innehaller oavsiktlig broad `true`-logik.
- Kontrollera att policy beroenden inte skapar recursion-fel vid SELECT.
- Efter `0004`: kontrollera `REVOKE ... FROM PUBLIC, anon` och `GRANT ... TO authenticated` for alla fyra helpers (t.ex. `\df+` / `information_schema`).

## 7) Beslutskriterier: redo for write-policies

RLS SELECT-lagret ar redo for nasta steg om:

- Samtliga T1-T17 passerar (eller motsvarande minima om T17 inte ar mojlig i vald testrigg).
- Inga cross-tenant/cross-workshop rader returneras.
- Suspended/revoked/no-membership ar konsekvent blockerade.
- Inga recursion- eller policy-evalueringsfel uppstar.

Om nagon kritisk test faller:

- Stoppa write-policy-arbete.
- Harda helper/policy-design forst.
- Kor om verifieringssviten innan nya migrationer.
