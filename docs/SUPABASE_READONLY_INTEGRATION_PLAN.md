# SUPABASE READ-ONLY INTEGRATION PLAN (PHASE 1)

Detta dokument planerar **forsta sakra read-only integrationen** av Supabase i Golden Auto utan att andra befintliga appfloden.

## Scope och principer

- Fas 1A har nu en **forsta backend-implementation** bakom feature flag.
- MongoDB fortsatter vara aktiv primary source i appen tills read-only verifierats.
- Ingen write mot Supabase i integrationsfas 1.
- Ingen service role i frontend.
- Endast syntetisk testdata i verifiering.

## Fas 1A status (implementerad, backend-only)

- Implementerad i `backend/server.py` pa endpoint `GET /api/customers`.
- Feature flag: `SUPABASE_READONLY_CUSTOMERS_ENABLED` (default `false`).
- Nar flaggan ar `false`: befintlig MongoDB-kodvag anvands oforandrat.
- Nar flaggan ar `true`: backend forsoker Supabase read-only for customers.
- Vid saknad Supabase-config eller read-fel: kontrollerad fallback till MongoDB.
- Inga Supabase writes introducerade.

### Miljovariabler for Fas 1A

- `SUPABASE_READONLY_CUSTOMERS_ENABLED=false`
- `SUPABASE_URL=...`
- `SUPABASE_ANON_KEY=...`
- `SUPABASE_CUSTOMERS_TIMEOUT_SEC=5` (valfri, default 5 sek)

## 1) Rekommenderad forsta read-only scope

### Fas 1A (forst): `customers` read-only

Motivering:
- Lagst risk att bryta dagens appfloden nar lasning sker parallellt.
- Kritisk domandata men utan samma tekniska kanslighet som regnr-falt i `vehicles`.
- Bra kandidat for att verifiera tenant/workshop-scope, pagination och falthygien.

### Fas 1B (efter verifierad 1A): `vehicles` read-only

Motivering:
- Ger hogt affarsvarde men innehaller kansligare falt (`reg_number_*`).
- Borde tas in efter att read-path och observabilitet redan ar verifierad pa `customers`.

## 2) Arkitekturrekommendation

**Rekommenderat alternativ: backend service layer (sakrast).**

Varfor:
- Frontend far inte direkt databasansvar eller query-logik for tenant/workshop-scope.
- Lattare att styra exakt vilka kolumner som returneras per endpoint.
- Mojliggor fallback till MongoDB per endpoint bakom feature flag utan UI-andring.
- Ger central punkt for loggning, timeout, felhantering och maskning innan svar till klient.

**Inte for fas 1:** direkt frontend Supabase client for domandata.

## 3) Sakerhetsregler for read-only integration

- Ingen service role-nyckel i frontend eller klientlevererad kod.
- Om Supabase klient anvands i backend: anvand endast nycklar avsedda for RLS-styrd access i den planerade read-pathen.
- Minsta mojliga SELECT: explicit kolumnlista, ingen `select *`.
- Ingen write-path aktiveras (inga inserts, updates, deletes, rpc-writes).
- Inga `reg_number_*` i listvyer.
- Ingen riktig kunddata i utvecklings-/testmiljo.
- Tenant/workshop-scope verifieras med befintlig RLS-modell och syntetiska identiteter.

## 4) Datafalthygien

### `customers`

**Listvy (tillatet):**
- `id`
- `tenant_id` (internt, ej nodvandigt i UI)
- `workshop_id` (internt, ej nodvandigt i UI)
- `customer_number`
- `full_name`
- `phone`
- `email`
- `is_active`
- `created_at`
- `updated_at`

**Detaljvy (kan visas nar behov finns):**
- `address_line1`
- `address_line2`
- `postal_code`
- `city`
- interna metadatafalt om de behovs for support/admin

**Maskning/minimering:**
- E-post och telefon kan maskas i lista vid osakert behov (t.ex. viewer-liknande vyer).
- Undvik att returnera full adress i listning.

### `vehicles`

**Listvy (tillatet):**
- `id`
- `tenant_id` (internt)
- `workshop_id` (internt)
- `customer_id`
- `make`
- `model`
- `model_year`
- `vin_last6` (om falt finns, annars motsvarande maskad identifierare)
- `is_active`
- `created_at`
- `updated_at`

**Regnummerhantering:**
- Exponera inte `reg_number_ciphertext`.
- Exponera inte `reg_number_hash`.
- Exponera inte `reg_number_last4` i generell listvy i fas 1.
- Eventuell regnummerpresentation i senare fas ska vara explicit behovspravad och maskad.

**Skall inte exponeras direkt:**
- Alla `reg_number_*`
- Eventuella interna tekniska falt som inte behovs i UI

## 5) Kodstrategi for kommande implementationssteg (inte nu)

Foreslagna filer/omraden att andra i nasta kodprompt:

- Backend:
  - ny read-only repository/service, t.ex. `backend/.../supabase_customers_repository.py`
  - feature flag i backend config, t.ex. `USE_SUPABASE_CUSTOMERS_READ=false`
  - separat mapper DTO for att filtrera tillatna falt
- Frontend:
  - befintlig API-klient pekar fortsatt mot backend (ingen direkt Supabase klient i fas 1)
  - eventuell hook senare: endast konsumera backend endpoint, inte direkt databas
- Config/env:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY` (om behov i backend read-path)
  - feature flags for read-only rollout

## 6) Samexistens med MongoDB (utan migration nu)

- MongoDB forblir source of truth i produktion under hela fas 1.
- Supabase lasning kor parallellt i kontrollerad mode (shadow/read-compare eller feature-flagad endpoint).
- Inga destruktiva andringar.
- Ingen datamigrering i detta steg.
- Ingen switch-over innan datakvalitet, latens och scope ar verifierade.

## 7) Testplan for nasta steg

- RLS-regression finns redan och behalls oforandrad.
- Ny backend smoke test (nar service byggs):
  - kan hamta customers read-only
  - returnerar endast tillatna falt
  - returnerar inga `reg_number_*`
- Frontend mock/smoke (senare, om hook tillkommer):
  - hanterar read-only svar och fallback utan UI-redesign
- Manuell verifiering med syntetisk data:
  - owner/admin/receptionist/mechanic/viewer inom tenant
  - cross-tenant och cross-workshop kontroll
  - ingen kunddata fran verklig miljo

## 8) Rekommenderad nasta kodprompt (smal)

**Mal:** Implementera endast `customers` read-only via backend med feature flag.

**Tillatna filer i nasta steg:**
- backend service/repository filer for Supabase customers read
- backend config/env hantering for Supabase URL/nyckel + feature flag
- backend tester (smoke/unit) for nya read-only pathen
- docs som beror read-only implementation

**Ej tillatna i nasta steg:**
- frontend UI-redesign
- vehicles-read implementation
- alla writes mot Supabase
- migrationer, RLS-policyer, testsviter for databasmigrationer
- auth-floden, MongoDB write-floden

**Definition of done for nasta steg:**
- Backend kan lasa `customers` read-only bakom flagga.
- Returnerad payload ar faltminimerad.
- MongoDB-flode ar oforandrat nar flagga ar av.
