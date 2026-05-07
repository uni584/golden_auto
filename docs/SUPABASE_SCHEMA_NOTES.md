# SUPABASE SCHEMA NOTES (DRAFT 0001)

Detta dokument beskriver antaganden och avgransningar for det forsta schemautkastet i `supabase/migrations/0001_initial_schema.sql`.

## Omfattning

- Endast databas-schema (DDL) for Supabase/Postgres.
- Ingen frontend- eller backend-koppling.
- Inga RLS-policies i detta steg.
- Ingen service-role logik i detta steg.

## Multi-tenant modell

- `tenants` ar overordnad SaaS-entitet.
- `workshops` tillhor en tenant och fungerar som operativ underenhet.
- Alla centrala domantabeller ar tenant-scopade via `tenant_id`:
  - `customers`
  - `vehicles`
  - `bookings`
  - `work_orders`
  - `quotes`
  - `quote_items`
  - `receipts`
  - `tire_hotel`
- Tenant-lokal unikhet anvands for nummer/identifierare som `booking_number`, `work_order_number`, `quote_number` och `receipt_number`.

## Kanslig data: registreringsnummer

- Registreringsnummer lagras inte i klartext i schemat.
- `vehicles` innehaller:
  - `reg_number_ciphertext` (krypterad representation)
  - `reg_number_hash` (deterministisk hash for sok/unikhet inom tenant)
  - `reg_number_last4` (maskerad visning/loggning)
- Detta gor att framtida implementation kan:
  - visa maskerade data i UI/logg
  - gora jamforelser via hash
  - hantera dekryptering kontrollerat i applikations- eller DB-lager senare

**Nasta steg (sakerhet, dokumentation):** `docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md` beskriver strategi for **kvitton** och **regnr**; migration **`0007_registration_number_security_foundation.sql`** inför `update_vehicle_registration_fields` + trigger som blockerar direkt `UPDATE` av `reg_number_*` (ingen full kryptering an). Migration **`0008_receipts_rpc_foundation.sql`** inför `create_receipt` (RPC-first; ingen fri klient-`INSERT`/`UPDATE`/`DELETE` pa tabellen). Migration **`0009_audit_events_foundation.sql`** inför `audit_events` + intern append och audit-koppling till de två känsligaste RPC-flödena. Migration **`0010_customer_vehicle_audit_triggers.sql`** inför trigger-audit for customers/vehicles med metadata-begransning. Migration **`0011_booking_work_order_audit_triggers.sql`** inför operativ trigger-audit för bookings/work_orders. Migration **`0012_quote_tire_hotel_audit_triggers.sql`** inför operativ trigger-audit för quotes/quote_items/tire_hotel med parent-scope för quote_items.

## Audit-forberedelse

- Alla centrala tabeller har `created_at` och `updated_at`.
- Trigger-funktion `set_updated_at()` uppdaterar `updated_at` automatiskt vid `UPDATE`.
- Falt for framtida actorsporning finns som `created_by` och `updated_by` (UUID) pa relevanta tabeller.
- **Append-only audit implementerad i `0009` + utokad i `0010`/`0011`/`0012`:** `audit_events`, owner/admin-READ i tenant, ingen klient-write, intern `append_audit_event` med metadata-guardrails samt trigger-audit for `customer.*`, `vehicle.*`, `booking.*`, `work_order.*`, `quote.*`, `quote_item.*`, `tire_hotel.*`.
- Full revisionshistorik per falt och extern actor-resolution skjuts till senare migrationer (**`0013+`**).

## Affarsantaganden i utkastet

- En `vehicle` tillhor en `customer` inom samma tenant.
- Bokning kan finnas utan definitiv kund/fordonskoppling initialt (`customer_id`/`vehicle_id` kan vara null).
- Arbetsorder och kvitto kraver kund + fordon.
- `quote_items` har egen `tenant_id` for att forenkla framtida RLS/filtering och analytiska fragor.
- Belopp lagras i `numeric(12,2)` och valuta defaultar till `SEK`.
- Tidsfalt anvander `timestamptz` for robust tidszonshantering.

## Avsiktliga avgransningar (for fas 2+)

- Inga RLS-policies eller grants.
- Auth-grund lagd i `0002`, men inga policies/grants ar aktiverade an.
- Ingen soft-delete standardisering (t.ex. `deleted_at`) i alla tabeller an.
- Inga avancerade constraints for tenant-konsistens over flera FK-led (kan hardnas i senare migrationer).

## Auth- och membership-grund (0002)

Migration: `supabase/migrations/0002_auth_membership_foundation.sql`

Tillagda tabeller:

- `profiles`
  - 1:1 med `auth.users` via `profiles.user_id -> auth.users.id`
  - Basprofil for intern personalanvandare (ej kundtabell)
- `tenant_members`
  - Kopplar anvandare till tenant
  - FK: `tenant_id -> tenants.id`
  - FK: `user_id -> auth.users.id`
  - Roller: `owner`, `admin`, `mechanic`, `receptionist`, `viewer`
  - Har `membership_status` samt `is_default_tenant` for framtida contextval
- `workshop_members`
  - Kopplar anvandare till workshop inom tenant
  - FK: `(tenant_id, workshop_id) -> workshops(tenant_id, id)` for att undvika cross-tenant access
  - FK: `(tenant_id, user_id) -> tenant_members(tenant_id, user_id)` for att krava tenant-medlemskap innan workshop-atkomst
  - Egen roll + medlemsstatus per workshop

Tekniska tillagg for integrity:

- Unikt index pa `workshops (tenant_id, id)` lades till for komposit-FK.
- Partial unique index pa `tenant_members` sakerstaller max en aktiv default-tenant per anvandare.
- `updated_at`-trigger lagd pa alla nya membership/auth-tabeller.

## Varfor detta behovs for framtida RLS

- `auth.uid()` kan matchas direkt mot `tenant_members.user_id` for tenant-scope.
- Workshop-atkomst kan utvarderas mot `workshop_members` och valideras mot tenant via komposit-FK.
- Rollbaserade policies kan byggas med enkel kontroll pa `role` i `tenant_members`/`workshop_members`.
- Operativa tabeller som innehaller kanslig data (t.ex. fordon och registreringsnummer) ar redan tenant/workshop-scopade och kan darfor isoleras med medlemskapstabellerna som policy-bas.

## Antaganden for 0002

- Endast interna workshop-anvandare hanteras i auth/membership (inte slutkundsinloggning).
- En anvandare kan tillhora flera tenants och flera workshops.
- Workshop-roll kan skilja sig fran tenant-roll vid behov.
- Roller representeras som text + check constraints (ingen enum i detta steg for enkel migrering).

## Vad som aterstar innan RLS-policies kan skapas

- Definiera policystrategi per tabell (SELECT/INSERT/UPDATE/DELETE) och roll.
- Besluta om helper-funktioner (t.ex. `is_tenant_member()`, `has_workshop_access()`) ska anvandas i policies.
- Faststalla om alla `created_by`/`updated_by` ska hard-kopplas mot `auth.users` i senare migration.
- Definiera hur systemaktorer/bakgrundsjobb ska representeras utan service-role-bypass.
- Lasa ner skrivrattigheter sa att auditlogg i senare fas skrivs server-side/saker RPC, inte direkt fran klient.

## RLS helper + SELECT isolation (0003)

Migration: `supabase/migrations/0003_rls_helpers_and_select_policies.sql`

Kort sammanfattning:

- Fyra helper-funktioner tillagda for RLS:
  - `current_user_is_active_tenant_member(tenant_id uuid)`
  - `current_user_has_tenant_role(tenant_id uuid, roles text[])`
  - `current_user_has_workshop_access(tenant_id uuid, workshop_id uuid)`
  - `current_user_has_workshop_role(tenant_id uuid, workshop_id uuid, roles text[])`
- Funktionerna bygger pa `auth.uid()` och returnerar endast true for `active` medlemskap.
- Funktionerna ar skapade som `stable security definer` med satt `search_path` for robust RLS-anvandning.
- RLS ar nu `enabled` pa tenant-, membership- och domantabeller.
- Endast `SELECT`-policies ar tillagda i detta steg; write-policies ar avsiktligt utelamnat.
- Tenant/workshop-isolering ar nu forberedd for kanslig data (inkl. fordon/registreringsnummer) via medlemskap och workshop-access.

## Sakerhetsgranskning och verifieringsfas (pre-write)

Ny verifieringsplan: `docs/RLS_VERIFICATION_PLAN.md` (senast dokumenterat: **178/178 PASS** — SELECT **32/32**, WRITE **146/146** efter **`0012`**).

Kort bedomning av 0003:

- SELECT-lagret ar i grunden korrekt for tenant/workshop-isolering.
- Inga tydliga direkta cross-tenant-lackor identifierades i policylogiken.
- Foljande risker maste valideras/hardas innan write-policies:
  - helper function execute-scope (revoke fran oonskade roller)
  - eventuell for bred `profiles`-lasning inom tenant
  - recursion-risk om `FORCE RLS` senare aktiveras pa membership-tabeller

Rekommendation:

- Fortsatt till write-policy design ar mojligt, men endast efter att verifieringssviten passerat enligt `docs/RLS_VERIFICATION_PLAN.md`.

## SELECT-hardning (0004)

Migration: `supabase/migrations/0004_rls_select_hardening.sql`

- RLS-helper-funktioner: `REVOKE EXECUTE` fran `PUBLIC` och `anon`; `GRANT EXECUTE` endast till `authenticated`.
- `profiles` SELECT-policy: egen profil alltid; andras profiler endast for tenant `owner`/`admin` nar mal-anvandaren har `active` medlemskap i samma tenant.
- `workshops` SELECT-policy: tenant `owner`/`admin` med aktivt medlemskap far lasa alla workshops i tenant; ovriga roller behover `active` workshop-medlemskap per workshop.
- `FORCE ROW LEVEL SECURITY` infors inte i detta steg (risk for recursion med nuvarande helper-design); se `docs/RLS_POLICY_PLAN.md`.

## Lokal Supabase migrationsverifiering

Genomford lokalt med Docker Desktop igang och `npx supabase db reset` (PowerShell, branch `main`):

- Alla migrationer **`0001`–`0012`** applicerades utan SQL-fel som stoppade loppet.
- Meddelandet `DROP POLICY IF EXISTS ... does not exist, skipping` under `0003` ar forvantat vid forsta korning (idempotent drop).
- Varningen `no files matched pattern: supabase/seed.sql` betyder att ingen seed-fil finns; den blockerar inte reset. Lagg till syntetisk seed senare om onskat.
- Ingen riktig kunddata anvandes.

Nasta steg: kor pgTAP-regression (`npx supabase test db`) enligt `docs/RLS_VERIFICATION_PLAN.md` — **178/178** (32 SELECT + 146 WRITE) efter **`0012`**. Ingen service role i frontend.

## Automatiserad SELECT-RLS regression

- Fil: `supabase/tests/database/rls_select_policies.test.sql` (pgTAP, 32 test).
- Kor lokalt: `npx supabase start` → `npx supabase db reset` → `npx supabase test db`.
- Syntetiska `auth.users` och domandata endast; ingen riktig kunddata.
- Senast kord: **32/32 PASS** (lokal Supabase via `npx`). Se aven `docs/RLS_VERIFICATION_PLAN.md` for tackning mot manuella T1–T17.

## Automatiserad WRITE-RLS regression (0005 + 0006 + 0007 + 0008 + 0009 + 0010 + 0011 + 0012)

- Fil: `supabase/tests/database/rls_write_policies.test.sql` (pgTAP, **146** test).
- Kors av samma `npx supabase test db` som SELECT-sviten efter `db reset`.
- Senast kord: **146/146 PASS** tillsammans med SELECT (**178/178** totalt, 32+146). **`0007`:** **W46–W52** (reg-falt). **`0008`:** **W69**, **W71–W90** (`create_receipt`). **`0009`:** **W91–W118** (`audit_events` + audit via RPC). **`0010`:** customer/vehicle trigger-audit + metadata-skydd. **`0011`:** booking/work_order trigger-audit + metadata-skydd. **`0012`:** quote/quote_item/tire_hotel trigger-audit + metadata-skydd och parent-scope for quote_items. Detaljer: `docs/RLS_WRITE_POLICY_PLAN.md`, `docs/RLS_VERIFICATION_PLAN.md`, `docs/AUDIT_LOGGING_PLAN.md`.

## Write-policies

- Detaljplan: **`docs/RLS_WRITE_POLICY_PLAN.md`** (inkl. `0005`–`0011`).
- Receipts + registreringsnummer (nasta steg): **`docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`**.
- Overgripande: **`docs/RLS_POLICY_PLAN.md`**.

### Migration `0005_initial_write_policies.sql`

- `INSERT`/`UPDATE` RLS for: `profiles` (egen `UPDATE`), `customers`, `bookings`, `quotes`, `quote_items`.
- Roller: `owner`/`admin`/`receptionist` enligt policy (ej `mechanic`/`viewer` for dessa tabeller i detta steg).
- Triggers: immutable `tenant_id` pa `UPDATE` for namnda tabeller dar lampligt; `created_by`/`updated_by` satts fran `auth.uid()` pa `customers`/`bookings`/`quotes`.

### Migration `0006_operational_write_policies.sql`

- `INSERT`/`UPDATE` RLS for: `vehicles`, `work_orders`, `tire_hotel` (se `docs/RLS_WRITE_POLICY_PLAN.md` for rollmatris och regnr-risk).
- Triggers: `tenant_id` immutable + audit pa samma tabeller.
- **Inga** `DELETE`-policies (operationellt); **inga** fria klient-writes till `receipts` (skapande via **`create_receipt`** i **`0008`**); **inga** klient-writes till membership, `tenants`, `workshops`.

### Migration `0007_registration_number_security_foundation.sql`

- Registreringsfalt pa `vehicles`: direkt `UPDATE` av `reg_number_ciphertext` / `reg_number_hash` / `reg_number_last4` blockeras (trigger + intern GUC); andring **maste** ga via `public.update_vehicle_registration_fields(...)` (se `docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`).
- **`INSERT`** av `reg_number_*` under befintlig RLS ar fortfarande en **dokumenterad risk** (ingen INSERT-sparr i `0007`).
- **Ej** produktionskryptering/KMS.

### Migration `0008_receipts_rpc_foundation.sql`

- **`public.create_receipt(...)`** — `SECURITY DEFINER`, `search_path = public`: endast **owner**/**admin**, aktiv medlemskap, workshop-access; validerar kund/fordon/valfri bokning/AO/offert; belopp och `payment_status = unpaid` vid skapande; `created_by`/`updated_by` = `auth.uid()`. Valfri `p_booking_id` valideras men **lagras ej** (saknas `booking_id`-kolumn i `0001`).
- Direkt klient-`INSERT` pa `receipts` forblir **nej** (RLS). **`receipts_deny_client_update` / `receipts_deny_client_delete`:** klient-`UPDATE`/`DELETE` nekas med RAISE.
- **Ej** void/betalning/refund-RPC, Edge, frontend, full ekonomisk validering.

### Migration `0009_audit_events_foundation.sql`

- Skapar `public.audit_events` + index (`tenant_id, created_at`, `resource_type/resource_id`, `actor_user_id`, `action`).
- RLS: `SELECT` endast owner/admin i tenant; inga klient-write-policies.
- Intern `append_audit_event(...)` (SECURITY DEFINER, fast `search_path`, `REVOKE` fran `PUBLIC`/`anon`/`authenticated`, metadata-guardrails mot känsliga nycklar).
- Audit kopplas till `update_vehicle_registration_fields(...)` (`vehicle.registration_updated`) och `create_receipt(...)` (`receipt.created`) med minimal metadata.
- Återstår: bredare audit (bookings/quotes/work_orders/tire_hotel), membership/admin-händelser, backend correlation-id, retention/export-policy.

### Migration `0010_customer_vehicle_audit_triggers.sql`

- Trigger-audit for `customers` (`customer.created`, `customer.updated`) och `vehicles` (`vehicle.created`, `vehicle.updated`).
- UPDATE-metadata begransas till `changed_fields` (fältnamn), inga fulla row snapshots eller PII payload.
- `vehicles` trigger exkluderar `reg_number_ciphertext`, `reg_number_hash`, `reg_number_last4`; vid reg-only update loggas ingen `vehicle.updated` (primär event kvar: `vehicle.registration_updated` via RPC).

### Migration `0011_booking_work_order_audit_triggers.sql`

- Trigger-audit for `bookings` (`booking.created`, `booking.updated`) och `work_orders` (`work_order.created`, `work_order.updated`).
- INSERT-metadata: `{}` (ingen payload-dump).
- UPDATE-metadata: `changed_fields` (fältnamn), utan snapshots; fritextfält exkluderas (`notes`, `assigned_to_label`).
- Återstår: membership/admin, backend `correlation_id`, retention/export-policy.

### Migration `0012_quote_tire_hotel_audit_triggers.sql`

- Trigger-audit for `quotes` (`quote.created`, `quote.updated`), `quote_items` (`quote_item.created`, `quote_item.updated`) och `tire_hotel` (`tire_hotel.created`, `tire_hotel.updated`).
- `quote_items` hämtar `tenant_id`/`workshop_id` från parent `quotes` för korrekt audit-scope.
- INSERT-metadata: `{}` (ingen payload-dump).
- UPDATE-metadata: `changed_fields` (fältnamn), utan snapshots; fritextfält exkluderas (`notes`, `description`, `tire_brand_model`, `tire_dimension`, `rack`).
- Återstår: membership/admin, backend `correlation_id`, retention/export-policy.

### Planerad rollout `0013+` (audit)

- Styrd av **`docs/AUDIT_LOGGING_PLAN.md`**.
- Rekommenderad **`0013+`**:
  - membership/admin-audit när säkra skrivvägar finns
  - correlation-id från backend/request-lager
  - retention/export-policy

## Syntax och kvalitet

- SQL ar skriven for Postgres/Supabase med `pgcrypto` extension.
- Utkastet ar avsett som stabil startpunkt for vidare hardning:
  - RLS
  - audit enligt **`docs/AUDIT_LOGGING_PLAN.md`**
  - tenant-sakerhet i FK/constraints
  - ev. krypteringsnyckelhantering och dekrypteringsstrategi

## Planerad app-integration (read-only, ingen kod andrad an)

- Se **`docs/SUPABASE_READONLY_INTEGRATION_PLAN.md`** for forsta steg i app-integration.
- Se **`docs/SUPABASE_AUTH_TRANSITION_PLAN.md`** for auth/JWT-overgang till Supabase RLS-korrekt read.
- Rekommenderad ordning:
  1) `customers` read-only via backend service layer
  2) `vehicles` read-only efter verifierad fas 1
- I integrationsfasen:
  - inga writes mot Supabase
  - ingen service role i frontend
  - MongoDB fortsatter som aktiv kalla tills verifiering ar klar
  - endast syntetisk data i test

### Auth/RLS-forutsattning for backend read-only

- RLS-modellen i Supabase forutsatter riktig user-context (`auth.uid()`), kopplad till `tenant_members` och `workshop_members`.
- Backend har forberedelse for passthrough av inkommande Bearer user-token till Supabase customers-read.
- Backend har dessutom en dev/staging-only smoke-endpoint (`/api/dev/supabase-auth-check`) bakom `SUPABASE_AUTH_CHECK_ENABLED` for att verifiera tokenkedjan utan writes.
- Backend har dessutom en dev/staging-only customers read smoke-endpoint (`/api/dev/supabase-customers-read-check`) bakom `SUPABASE_CUSTOMERS_READ_CHECK_ENABLED` for att verifiera RLS-read med Supabase JWT.
- `SUPABASE_ANON_KEY` anvands som `apikey`, men inte som user `Authorization`.
- For customers read-only anvands explicit select-lista: `id`, `customer_number`, `full_name`, `email`, `phone`, `created_at`, `updated_at` (ingen `select *`).
- `public.customers` saknar `is_active`; select-list mismatch mot `is_active` ger PostgREST-fel och ska behandlas som schema/anropsfel, inte RLS-fel.
- Viktig nulagesnotering: `GET /api/customers` skyddas fortfarande av legacy backend-auth (`Depends(get_current_user)` med `HS256` + lokal `JWT_SECRET`).
- Konsekvens: enbart Supabase access token mot `/api/customers` ger `401 Ogiltig token` innan Supabase-read/RLS exekveras.
- Slutsats: detta ar en auth-kompatibilitetsblocker (forvantar legacy JWT), inte ett schema- eller RLS-fel.
- For smoke-verifiering av customers RLS anvands den separata dev-endpointen utan MongoDB-fallback, sa deny (`401/403`) inte maskeras.
- Pathen ar fortfarande **foundation/steg 1** tills en kontrollerad auth-vag finns for att verifiera Supabase user-token pa utvalda read-only endpoints i staging/dev.
- Ingen service-role bypass far anvandas for vanlig domandata-read.
