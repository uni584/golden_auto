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

## Audit-forberedelse

- Alla centrala tabeller har `created_at` och `updated_at`.
- Trigger-funktion `set_updated_at()` uppdaterar `updated_at` automatiskt vid `UPDATE`.
- Falt for framtida actorsporning finns som `created_by` och `updated_by` (UUID) pa relevanta tabeller.
- Full auditlogg-tabell, revisionshistorik och actor-resolution skjuts till senare fas.

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

## Syntax och kvalitet

- SQL ar skriven for Postgres/Supabase med `pgcrypto` extension.
- Utkastet ar avsett som stabil startpunkt for vidare hardning:
  - RLS
  - auditlogg
  - tenant-sakerhet i FK/constraints
  - ev. krypteringsnyckelhantering och dekrypteringsstrategi
