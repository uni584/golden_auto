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
- Ingen integration mot `auth.users`/profiltabeller.
- Ingen soft-delete standardisering (t.ex. `deleted_at`) i alla tabeller an.
- Inga avancerade constraints for tenant-konsistens over flera FK-led (kan hardnas i senare migrationer).

## Syntax och kvalitet

- SQL ar skriven for Postgres/Supabase med `pgcrypto` extension.
- Utkastet ar avsett som stabil startpunkt for vidare hardning:
  - RLS
  - auditlogg
  - tenant-sakerhet i FK/constraints
  - ev. krypteringsnyckelhantering och dekrypteringsstrategi
