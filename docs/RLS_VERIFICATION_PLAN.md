# RLS VERIFICATION PLAN (PRE-WRITE POLICIES)

Detta dokument beskriver en saker verifieringsfas for RLS SELECT-lagret (`0003` + hardning `0004`) innan write-policies byggs, och **uppdateras lopande** nar nya migrationer och pgTAP-tester tillkommer.

**Aktuell automatiserad regression (repo-miljo, efter migration `0012`):**

- `npx supabase db reset` tillampar **`0001`–`0012`**.
- `npx supabase test db`: **`178/178 PASS`** totalt — **SELECT 32/32**, **WRITE 146/146** (`plan(146)` i `rls_write_policies.test.sql`).
- **`0007` — registreringsnummer:** `UPDATE` av `reg_number_ciphertext` / `reg_number_hash` / `reg_number_last4` pa `vehicles` **maste** ga via `public.update_vehicle_registration_fields(...)`; **direkt** `UPDATE` av dessa kolumner **blockeras** (trigger + intern GUC). **`INSERT`** av `reg_number_*` kan fortfarande ske under befintlig RLS — **kvarstaende risk**, se `docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md` §2.
- **Nya write-fall (reg, W46–W52):** W46 direkt reg-`UPDATE` nekad; W47–W48 owner/receptionist via RPC; W49–W50 mechanic/viewer nekad; W51 cross-tenant nekad; W52 hash-konflikt inom tenant.
- **`0008` — receipts:** ingen fri klient-`INSERT`; skapande via **`public.create_receipt(...)`** for **owner**/**admin**; direkt `UPDATE`/`DELETE` nekas med **`receipts_deny_client_*`**-policies (RAISE). **W71–W90:** happy path, rollnekanden, cross-tenant/workshop, fel bokning/AO/offert, belopp/status, `created_by`.
- **`0009` — audit foundation:** `public.audit_events` + RLS `SELECT` endast owner/admin i tenant; intern `append_audit_event(...)` (ej klient-anropbar); audit kopplad till `update_vehicle_registration_fields` och `create_receipt`. **W91–W118** verifierar direct write-nekande, role-based SELECT, cross-tenant, RPC-genererade audit-rader och metadata-minimering.
- **`0010` — customer/vehicle audit triggers:** `customer.created`, `customer.updated`, `vehicle.created`, `vehicle.updated` via triggers; metadata begransas till `changed_fields` (update) och `{}` (insert). Reg-falt exkluderas i vehicle-trigger och RPC-handelser for `vehicle.registration_updated` forblir primara.
- **`0011` — booking/work_order audit triggers:** `booking.created`, `booking.updated`, `work_order.created`, `work_order.updated` via triggers; INSERT metadata `{}`, UPDATE metadata `changed_fields`; fritextfalt exkluderas.
- **`0012` — quote/quote_item/tire_hotel audit triggers:** `quote.created/updated`, `quote_item.created/updated`, `tire_hotel.created/updated` via triggers; metadata fortsatt minimal (`{}` för INSERT, `changed_fields` för UPDATE), utan snapshots/fritext.
- **Planerad `0013+` audit rollout:** enligt `docs/AUDIT_LOGGING_PLAN.md` — membership/admin, backend `correlation_id`, retention/export.
- **Innan produktionsklar regnr:** backend/Edge-normalisering, riktig hash/kryptering, KMS/Vault och nyckelrotation, INSERT-hardning (ev. RPC/kolumnprivilegier), audit-loggning — se `docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`.
- **Receipts (produktion):** void/betalnings-RPC, Edge/backend, audit — se **`docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`**.

### Planerad verifiering for audit rollout (`0013+`)

- Bekrafta att metadata fortsatt **inte** innehaller `reg_number_*`, tokens, hemligheter eller fulla row snapshots.
- Bekrafta fortsatt read-modell pa `audit_events`: owner/admin kan lasa egen tenant; mechanic/receptionist/viewer far 0 rader; cross-tenant nekas.
- Hall `npx supabase test db` gron efter varje delsteg (undvik stor "allt pa en gang"-migration).

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
- `0005_initial_write_policies.sql`
- `0006_operational_write_policies.sql`
- `0007_registration_number_security_foundation.sql`
- `0008_receipts_rpc_foundation.sql`
- `0009_audit_events_foundation.sql`
- `0010_customer_vehicle_audit_triggers.sql`
- `0011_booking_work_order_audit_triggers.sql`
- `0012_quote_tire_hotel_audit_triggers.sql`

Log-notiser som ar forvantade och ofarliga:

- `DROP POLICY IF EXISTS ... does not exist, skipping` i `0003` vid forsta reset: policies fanns annu inte; kommandot ar idempotent.

Log-notiser som inte blockerar:

- `WARN: no files matched pattern: supabase/seed.sql`: ingen seed-fil ar checkad in; reset lyckades anda. Lagg till `supabase/seed.sql` senare om syntetisk testdata ska laddas automatiskt.

Sakerhet och data:

- Ingen riktig kunddata anvandes; endast schema/migrationer applicerades.

Nasta steg (efter lyckad reset):

- Kor `npx supabase test db` for **178/178** pgTAP-regression (SELECT + WRITE), komplettera manuellt dar tabellen markerar **Nej** (t.ex. T17).

**Obs:** Reset bevisar att SQL-migrationerna ar syntaktiskt tillampningsbara och att databasen startar; den ersatter inte full RLS-testkorning med impersonering/JWT.

## Automatiserad SELECT-RLS testsvit (pgTAP)

Fil: `supabase/tests/database/rls_select_policies.test.sql`

- Forsta automatiserade regressionssviten for SELECT-RLS (syntetiska `auth.users`, tenants, workshops, domandata).
- **32** pgTAP-test (plan 32); anvander `SET LOCAL ROLE authenticated` + JWT-claims (`request.jwt.claim.sub` / `role`) via hjalpfunktion i samma fil.
- All data ar fejk (`*.example.test`, placeholder `reg_number_ciphertext` / `digest(...)` for hash); ingen riktig kunddata.
- `receptionist` ar inte en separat testidentitet; samma profil-RLS som for `viewer`/`mechanic` (icke owner/admin) avrads via gemensamma policies och tas ut av **T8** (viewer ser inte kollegas profil).

### Korning (lokal Supabase)

1. `npx supabase start` (Docker Desktop igang)
2. `npx supabase db reset` (tillampar `0001`–`0012`)
3. `npx supabase test db`

Senast kord i repo-miljo: **32/32 PASS** for SELECT-sviten (pg_prove mot lokal databas); **178/178 PASS** tillsammans med WRITE-sviten (se nedan).

### WRITE-RLS testsvit (pgTAP, migration 0005 + 0006 + 0007 + 0008 + 0009 + 0010 + 0011 + 0012)

Fil: `supabase/tests/database/rls_write_policies.test.sql`

- **146** pgTAP-test (`plan(146)`); syntetisk data, `rollback` i slutet; samma JWT/impersoneringsmonster som SELECT-sviten (`SET LOCAL ROLE authenticated` + `request.jwt.claim.sub` / `role`).
- Tacker `INSERT`/`UPDATE` for `profiles`, `customers`, `bookings`, `quotes`, `quote_items`, `vehicles`, `work_orders`, `tire_hotel` samt nekad `INSERT` dar policies saknas (`tenants`, `workshops`, membership, direkt `INSERT` pa `receipts`, m.m.); se `docs/RLS_WRITE_POLICY_PLAN.md`.
- **`0007` (W46–W52):** registreringsfalt — direkt `UPDATE` av `reg_number_*` nekad; godkand vag via `update_vehicle_registration_fields`; mechanic/viewer/cross-tenant/hash-konflikt nekad.
- **`0008` (W69, W71–W90):** `receipts` — direkt `INSERT` nekad; `create_receipt` for owner/admin; ovriga roller och fel kontext nekas; belopp/`payment_status`; direkt `UPDATE`/`DELETE` nekas; `created_by`.
- **`0009` (W91–W118):** `audit_events` — direkt `INSERT` nekad; `UPDATE`/`DELETE` effektivt nekade utan write-policies; owner/admin kan lasa tenant-audit; mechanic/receptionist/viewer och cross-tenant far 0 rader; RPC-floden skriver audit; metadata innehaller inte reg-raw/hash/ciphertext/last4.
- **`0010` (W95a–W95d, W98a–W98c m.fl.):** trigger-audit for customer/vehicle; metadata utan PII payload och utan `reg_number_*`; `vehicle.registration_updated` via RPC kvarstar som primar reg-handelese.
- **`0011` (W95f–W95i, W98d–W98f m.fl.):** trigger-audit for bookings/work_orders; INSERT metadata `{}` och UPDATE metadata `changed_fields`; inga snapshots eller fritextpayload i metadata.
- **`0012` (W95j–W95o, W98g–W98i m.fl.):** trigger-audit for quotes/quote_items/tire_hotel; `quote_items` scope härleds från parent quote; metadata fortsatt minimal.

**Korning:** `npx supabase start` (vid behov), `npx supabase db reset` (tillampar **`0001`–`0012`**), `npx supabase test db`.

**Resultat (senast i repo-miljo):** **178/178 PASS** totalt (**32** SELECT + **146** write). **0005**–**0012** ar regressionstestade for det sviten tacker; kvarstaende manuell risk (t.ex. anon/helper T17) ar oforandrad.

**Receptionist:** implementation kraver aktiv `tenant_members.role = 'receptionist'` **och** `workshop_members` som ger `current_user_has_workshop_access` — se write-planen for eventuell produkt-jamforelse mot "enbart workshop-receptionist".

### Tackning mot manuella T1–T17 ( dokumentationsmatris )

| Manuellt fall i denna fil | Automatiserat? | Kommentar |
|---------------------------|----------------|-----------|
| T1–T2 (tenant isolering) | Ja | T1–T2 |
| T3–T4 (workshop isolering) | Ja | T3–T4 |
| T5–T6 (suspended) | Ja | T11–T12 |
| T7 (no membership) | Ja | T14 |
| T8 (`quote_items` annan tenant) | Ja | T20 |
| T9–T10 (vehicles/customers) | Ja | T15–T16 |
| T11–T12 (membership listing) | Delvis | T25–T27; admin/owner utokad listing |
| T13–T14 (profiler owner/admin) | Ja | T7–T10, T24 |
| T15 (owner utan workshop ser workshops) | Ja | T5–T6 |
| T16 (bokningar fortfarande workshop) | Ja | T6, T17a–T17b |
| T17 (anon/helper execute) | **Nej** | Krav manuellt eller separat testrigg |

Ovriga manuella/kompletterande tester (ej i pgTAP-filen an):

- **T17 (anon):** `REVOKE EXECUTE` pa helpers for `anon` — verifiera i staging med `anon`-JWT eller policy-debug.
- **Receptionist som egen roll:** valfritt; policy-skillnad mot `viewer` ar idag minimal for `profiles` (icke owner/admin).
- **B_owner** som separat identitet: valfritt; cross-tenant profil testas med **T24** (B-mechanic).
- **Last/ prestanda / audit-write:** utanfor SELECT-scope.

### Nasta steg

- Anvand `npx supabase test db` som **lopande regression** efter varje migrations-/testandring (nu: **178/178** efter **0012**).
- Komplettera manuellt med T17 (anon) om krav finns i er sakerhetsmodell.
- **Receipts** och **full regnr-produktion:** se `docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`.
- For app-read-only onboarding: se `docs/SUPABASE_READONLY_INTEGRATION_PLAN.md` (customers forst, vehicles sen; inga writes).

## Read-only verifiering for planerad app-integration

Denna punkt kompletterar migrations-/RLS-regressionen med appnara read-only kontroller.

- Scope fas 1:
  - `customers` read-only forst
  - `vehicles` read-only i senare steg
- Testdata:
  - endast syntetisk data
  - ingen riktig kunddata
- Sakerhetskrav i verifiering:
  - ingen service role i frontend
  - inga writes mot Supabase
  - inga `reg_number_*` i listvyer
  - explicit kolumnlista (ingen `select *`)
- Scope-kontroller:
  - owner/admin/receptionist/mechanic/viewer testas mot tenant/workshop-isolering
  - cross-tenant och cross-workshop ska returnera 0 rader
- Driftmodell:
  - MongoDB fortsatter som aktiv kalla tills read-only verifierats i praktiken
  - Supabase-lasning introduceras bakom feature flag i backend

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

**Historiskt:** RLS SELECT-lagret var redo for write-policies nar SELECT-sviten var gron.

**Nuvarande lage:** Write-sviten omfattar **0005–0012**; total pgTAP-regression **178/178** (32 SELECT + 146 write) i nuvarande repo-miljo.

RLS SELECT-lagret och pafoljande write-lager anses fortsatt **validerade** om:

- `npx supabase test db` ar **gron** (**178/178** i nuvarande testsvit, eller motsvarande om fler tester laggs till), **och**
- manuella kompletteringar som organisationen krav (t.ex. anon/helper T17) ar hanterade eller accepterat risk, **och**
- ovriga manuella T1-T17 dar tabellen markerar **Nej** ar korda eller medvetet scope-utelamnade.
- Inga cross-tenant/cross-workshop rader returneras.
- Suspended/revoked/no-membership ar konsekvent blockerade.
- Inga recursion- eller policy-evalueringsfel uppstar.

Om nagon kritisk test faller:

- Stoppa write-policy-arbete.
- Harda helper/policy-design forst.
- Kor om verifieringssviten innan nya migrationer.
