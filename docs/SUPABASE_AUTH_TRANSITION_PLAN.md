# SUPABASE AUTH TRANSITION PLAN

Detta dokument beskriver en kontrollerad overgang fran nuvarande auth i Golden Auto till Supabase-authad read-only access, sa att RLS med `auth.uid()` fungerar utan att bryta befintlig app.

## 1) Nuvarande auth (nulage)

### Frontend idag

- Frontend autentiserar mot befintlig backend-login (`/api/auth/login`).
- Ingen verifierad Supabase access token skickas idag i normalt appflode.

### Backend idag

- Backend verifierar egen JWT-signatur (`HS256`) via lokal `JWT_SECRET`.
- Token kommer via cookie `access_token` eller `Authorization: Bearer ...`.
- Denna JWT ar backend-intern och inte verifierad som Supabase access token.

### Konsekvens

- Backend kan identifiera anvandaren for MongoDB-floden.
- Men Supabase RLS-funktioner (`auth.uid()`) far bara korrekt user-context om en giltig Supabase user token skickas till Supabase.

## 2) Supabase Auth-krav for RLS

For att Supabase-read ska evalueras korrekt mot tenant/workshop-policyer kravs:

- En giltig Supabase access token (JWT) per request.
- Token skickas till backend i:
  - `Authorization: Bearer <supabase_access_token>`
- Backend skickar vidare samma user-token till Supabase REST:
  - `apikey: SUPABASE_ANON_KEY`
  - `Authorization: Bearer <supabase_access_token>`

Da kan `auth.uid()` kopplas till `auth.users.id`, och RLS kan matcha `tenant_members` + `workshop_members`.

## 3) Migration utan att bryta appen

Principer:

- MongoDB fortsatter som default tills Supabase Auth-kedjan ar verifierad.
- `SUPABASE_READONLY_CUSTOMERS_ENABLED` fortsatter styra Supabase-read path.
- Ingen frontend-redesign.
- Ingen write-koppling.
- Ingen vehicles-koppling i denna fas.

Stegvis overgang:

1. Behall nuvarande backend-auth som primar inloggning under overgang.
2. Introducera dev/staging-forberedelse for att klient kan bifoga Supabase access token.
3. Verifiera att backend passthrough fungerar utan tokenexponering.
4. Aktivera Supabase customers-read selektivt via feature flag i dev/staging.
5. Hall MongoDB som fallback tills roll/scope-matris ar passerad.

### Ny dev/staging smoke-verifiering (implementerad)

- Endpoint: `GET /api/dev/supabase-auth-check`
- Skyddas av env-flagga: `SUPABASE_AUTH_CHECK_ENABLED` (default `false`)
- Ar endpointen avstangd returneras `404` (inte publik i normal drift)
- Nar aktiv:
  - kraver `Authorization: Bearer <token>`
  - anropar Supabase Auth user endpoint med:
    - `apikey: SUPABASE_ANON_KEY`
    - `Authorization: Bearer <incoming user token>`
  - verifierar om token ar anvandbar for Supabase user-context
- Returnerar endast minimal, saker diagnostik:
  - `authenticated`
  - `user_id`
  - `customers_read_token_usable`
- Returnerar aldrig token/claims-dump.

## 4) Dev/staging-verifiering (syntetiska anvandare)

Verifiera minst dessa identiteter:

- owner
- admin
- receptionist
- mechanic
- viewer
- no membership
- suspended/revoked
- cross-tenant/cross-workshop scenarier

Kontroller:

- Ratt scope for tenant/workshop per roll.
- 0 rader for cross-tenant/cross-workshop/no-membership.
- Kontrollerad fallback till MongoDB om token saknas/ogiltig.
- Ingen token i loggar eller felmeddelanden.
- Endast syntetisk data.

## 5) Rekommenderat nasta smala kodsteg

Rekommenderat nasta steg: **dev/staging minimal token-forwarding fran klient till backend** for att mata `Authorization` med verklig Supabase access token.

Mal:

- Bekrafta om inkommande Bearer-token ar Supabase-kompatibel for RLS-read.
- Returnera endast icke-kanslig diagnostik (t.ex. "token present", "supabase call ok/deny"), aldrig tokeninnehall.
- Ingen write och ingen frontend-redesign.

Alternativt (om nuvarande frontend auth redan enkelt kan kompletteras): minimal token-forwarding i frontend request-lager utan UI-andring.

## 6) Sakerhetskrav under hela overgangen

- Ingen service role i frontend.
- Ingen service role for vanlig domandata-read.
- Logga aldrig tokens.
- Ingen riktig kunddata.
- Inga writes.
- MongoDB tas inte bort i denna fas.

## 7) Definition av "redo for live pilot"

Supabase customers read-only kan ga till kontrollerad live pilot forst nar:

- Supabase access token skickas konsekvent i appflodet.
- RLS-scope ar verifierat i staging/dev for roll- och tenant/workshop-matrisen.
- Fallback-beteende ar testat och forutsagbart.
- Sakerhetskrav ovan ar uppfyllda.

## 8) Miljovariabler (auth-transition)

- `SUPABASE_READONLY_CUSTOMERS_ENABLED=false`
- `SUPABASE_AUTH_CHECK_ENABLED=false` (dev/staging-only smoke-check)
- `SUPABASE_URL=...`
- `SUPABASE_ANON_KEY=...`
- `SUPABASE_CUSTOMERS_TIMEOUT_SEC=5`
