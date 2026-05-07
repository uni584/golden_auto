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
- `GET /api/customers` ar explicit skyddad med `Depends(get_current_user)`, dvs legacy JWT-guard exekveras innan customers-handlern.

### Konsekvens

- Backend kan identifiera anvandaren for MongoDB-floden.
- Men Supabase RLS-funktioner (`auth.uid()`) far bara korrekt user-context om en giltig Supabase user token skickas till Supabase.
- Enbart Supabase access token mot `GET /api/customers` stoppas i nulaget av legacy JWT-dekodning och blir `401 Ogiltig token`.

## 1.1) Verifierad status (dev smoke vs app-endpoint)

Verifierat lage i dev:

- `GET /api/dev/supabase-auth-check` ar gron med giltig Supabase access token.
- Endpointen returnerar korrekt `user_id` (observerad: `a257c0d4-8fbe-4229-ade0-a5fa34dbb98d`).
- `GET /api/customers` returnerar `{"detail":"Ogiltig token"}` med samma Supabase token.

Rotorsak:

- `customers_list` kraver `user: dict = Depends(get_current_user)`.
- `get_current_user` forsoker `jwt.decode(token, JWT_SECRET, algorithms=["HS256"])`.
- Supabase JWT ar inte signerad med lokal `JWT_SECRET` och matchar inte legacy-formatet.
- Resultat: `jwt.InvalidTokenError` -> `401 Ogiltig token` innan Supabase read-only pathen exekveras.

Sakerhetsbedomning:

- Detta ar en korrekt sakerhetsblocker i overgangsfasen.
- Felet ligger i auth-guard-kompatibilitet, inte i Supabase RLS-policyer.
- RLS for `customers` kunde inte verifieras via `GET /api/customers` i detta test, eftersom anropet stoppades fore Supabase-read.

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

### Ny dev/staging customers read smoke-verifiering (implementerad)

- Endpoint: `GET /api/dev/supabase-customers-read-check`
- Skyddas av egen env-flagga: `SUPABASE_CUSTOMERS_READ_CHECK_ENABLED` (default `false`)
- Nar flaggan ar avstangd returneras `404`
- Endpointen ar endast for dev/staging och ska inte exponeras i produktion
- Endpointen anvander **inte** legacy `get_current_user` (ingen HS256-verifiering i denna smoke-vag)
- Endpointen anvander **ingen** MongoDB-fallback, for att inte maskera RLS-resultat
- Supabase-anrop sker endast med:
  - `apikey: SUPABASE_ANON_KEY`
  - `Authorization: Bearer <incoming supabase access token>`
- Ingen service role, inga writes
- Returnerar endast verifieringssvar:
  - `source`
  - `count`
  - `customers` (minimerad faltlista utan notes/fritext)

### Exakt verifieringsflode for `/api/dev/supabase-auth-check`

Forberedelser (dev/staging):

- `SUPABASE_AUTH_CHECK_ENABLED=true`
- `SUPABASE_URL` satt
- `SUPABASE_ANON_KEY` satt
- Endast syntetiska testanvandare

Request:

- `GET /api/dev/supabase-auth-check`
- Header: `Authorization: Bearer <supabase_access_token>`

Forvantade svar:

- Flag av (`SUPABASE_AUTH_CHECK_ENABLED=false`) -> `404`
- Saknad token/header -> `401`
- Felaktigt Authorization-format (inte giltig Bearer) -> `400`
- Ogiltig/utgangen token -> `401`
- Giltig Supabase token -> `200` med:
  - `authenticated: true`
  - `user_id: <uuid>`
  - `customers_read_token_usable: true`

### Exakt verifieringsflode for `/api/dev/supabase-customers-read-check`

Forberedelser (dev/staging):

- `SUPABASE_CUSTOMERS_READ_CHECK_ENABLED=true`
- `SUPABASE_URL` satt
- `SUPABASE_ANON_KEY` satt
- Endast syntetiska testanvandare

Request:

- `GET /api/dev/supabase-customers-read-check`
- Header: `Authorization: Bearer <supabase_access_token>`
- Valfri query: `q=<sokterm>`

Forvantade svar:

- Flag av -> `404`
- Saknad token/header -> `401`
- Felaktigt Authorization-format -> `400`
- Supabase nekar token (RLS/auth) -> `401` eller `403`
- Giltig Supabase token + tillaten RLS-scope -> `200` med:
  - `source: "supabase"`
  - `count`
  - `customers` (minimerad read-only lista)

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
- Ingen token committas och ingen token loggas.
- For customers read smoke-check: fallback till MongoDB far inte ske (annars maskeras RLS-resultat).

## 5) Rekommenderat nasta smala kodsteg

Rekommenderat nasta steg ar en **kontrollerad auth-migration for utvalda read-only endpoints** i dev/staging, utan broad bypass:

Alternativ A (sakrast for snabb verifiering):  
- lagg till en dev-only customers Supabase smoke endpoint som *inte* anvander legacy `get_current_user`, men som:
  - krav pa giltig Supabase Bearer-token
  - anropar Supabase customers read med samma token + `apikey`
  - returnerar minimal diagnostik / read-count utan PII-dump
- syfte: verifiera verklig `customers` RLS-vag separat fran legacy app-auth.

Alternativ B (kontrollerad dual-token pa endpoint-niva):  
- behall legacy auth som default
- tillat Supabase JWT endast pa explicit allowlistade read-only endpoints i dev/staging
- ingen andring av writes, vehicles eller ovriga endpoint-floden.

Alternativ C (styrd stegvis migration):  
- infors ny auth dependency som kan verifiera:
  - legacy HS256 JWT (bakat kompatibilitet), eller
  - Supabase JWT (for utvalda read-only endpoints)
- rollout bakom feature flag och med tydlig endpoint-allowlist.

Guardrails for nasta kodsteg:

- ingen service role
- inga writes
- ingen frontend-redesign
- ingen riktig kunddata
- MongoDB kvar som default/fallback
- ingen bred auth-bypass

Rekommenderad nasta kodprompt (kopiera vid behov):

`Implementera en dev/staging-only customers Supabase smoke endpoint (read-only) som verifierar Supabase Bearer-token utan att anvanda legacy get_current_user. Behall befintlig auth oforandrad for ovriga endpoints, inga writes, ingen service role, ingen frontendandring. Returnera endast minimal diagnostik for RLS-verifiering.`

### Stoppregel vid fel

- Om smoke-check eller customers RLS-scope fallerar: stoppa vidare integration och atgarda auth/membership-kedjan forst.

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

Lokal setup:

- Kopiera `backend/.env.example` till `backend/.env` for lokal utveckling.
- `backend/.env` ar lokal runtime-konfiguration och ska aldrig committas.
- Hamta lokal Supabase anon key med:
  - `npx supabase status`
- Skriv aldrig riktiga tokens/nycklar/hemligheter i dokumentation eller git.

- `SUPABASE_READONLY_CUSTOMERS_ENABLED=false`
- `SUPABASE_AUTH_CHECK_ENABLED=false` (endast dev/staging smoke-check)
- `SUPABASE_CUSTOMERS_READ_CHECK_ENABLED=false` (dev/staging-only customers RLS smoke-check)
- `SUPABASE_URL=...`
- `SUPABASE_ANON_KEY=...`
- `SUPABASE_CUSTOMERS_TIMEOUT_SEC=5`
