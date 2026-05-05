# RLS WRITE POLICY PLAN

Detta dokument beskriver skrivstrategi for Golden Auto och vad som **redan ar implementerat** vs **aterstar**.

**Relaterat:** `docs/RLS_POLICY_PLAN.md` (SELECT + helpers), `docs/RLS_VERIFICATION_PLAN.md` (test/ regression), `docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md` (receipts + regnr — nästa steg).

## Implementerat: `0005_initial_write_policies.sql`

Migrationen inför **endast** `INSERT`/`UPDATE` RLS (inga `DELETE`-policies) for:

- `profiles` — `profiles_update_self` (endast `user_id = auth.uid()`, `WITH CHECK` samma; ingen klient-uppdatering av andras profiler).
- `customers` — `customers_insert_scoped`, `customers_update_scoped` (`owner`/`admin`/`receptionist`; receptionist kraver `workshop_id` + workshop-access; **ej** `mechanic`/`viewer`).
- `bookings` — `bookings_insert_scoped`, `bookings_update_scoped` (samma rollkrav; `UPDATE` `USING` = `current_user_has_workshop_access` i linje med SELECT; `WITH CHECK` validerar tenant/workshop + FK-konsistens mot `customers`/`vehicles`).
- `quotes` — `quotes_insert_scoped`, `quotes_update_scoped` (samma; `booking_id` valideras mot samma `workshop_id` som offerten).
- `quote_items` — `quote_items_insert_scoped`, `quote_items_update_scoped` (parent `quotes` maste matcha `tenant_id`; receptionist via workshop pa parent-offert).

**Triggers i 0005:**

- `tg_reject_tenant_id_change` pa `customers`, `bookings`, `quotes`, `quote_items` — `tenant_id` immutable pa `UPDATE`.
- `tg_set_audit_actor` pa `customers`, `bookings`, `quotes` — satter `created_by`/`updated_by` fran `auth.uid()`; `created_by` bevaras pa `UPDATE` (ingen klient-spoof).

**Ej i 0005 (medvetet):** `tenants`, `workshops`, `tenant_members`, `workshop_members`, `vehicles`, `work_orders`, `receipts`, `tire_hotel`; **inga** `DELETE`-policies.

## Implementerat: `0006_operational_write_policies.sql`

Migrationen inför **endast** `INSERT`/`UPDATE` RLS (inga `DELETE`) for:

- **`vehicles`** — `vehicles_insert_scoped`, `vehicles_update_scoped`: `owner`/`admin`/`receptionist`; **ej** `mechanic`/`viewer` (regnr/PII-risk). Receptionist: `workshop_id` **not null** + `current_user_has_workshop_access`. Owner/admin: `workshop_id` far vara `null` eller peka pa workshop i samma tenant (`EXISTS` mot `workshops`). `WITH CHECK`/`USING`: `customers.tenant_id` = radens `tenant_id`.
- **`work_orders`** — `work_orders_insert_scoped`, `work_orders_update_scoped`: `owner`/`admin` **eller** `mechanic` med workshop-access; **ej** `receptionist`/`viewer` (operativ AO hanteras av mekaniker och tenant-admins). `WITH CHECK`: workshop i tenant; `customer_id`/`vehicle_id` i samma tenant; valfri `booking_id` med samma `tenant_id` och `workshop_id` som arbetsordern.
- **`tire_hotel`** — `tire_hotel_insert_scoped`, `tire_hotel_update_scoped`: `owner`/`admin`, eller `receptionist`/`mechanic` med `current_user_has_workshop_access`; **ej** `viewer`. `WITH CHECK`: workshop + customer + vehicle i samma tenant.

**Triggers i 0006:** `tg_reject_tenant_id_change` pa `vehicles`, `work_orders`, `tire_hotel`; `tg_set_audit_actor` pa samma tabeller (`created_by`/`updated_by`).

**Registreringsnummer / PII (uppdatering efter 0007):** Direkt klient-`UPDATE` av `reg_number_*` ar **blockerad** av trigger; andring sker via `public.update_vehicle_registration_fields(...)`. **INSERT** av nya fordon med reg-falt kan fortfarande ske via RLS (samma risk som tidigare for forsta lagring). **Ej** full kryptering/KMS i 0007 — se **`docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`**.

**Ej i 0006:** `receipts`; membership- eller tenant/workshop-admin-skrivningar; regnr-RPC (uppdatering av reg-falt **centraliseras i 0007**, se nedan).

## Implementerat: `0007_registration_number_security_foundation.sql`

**Syfte:** lagrisk databasgrund — central skrivvag for **andring** av registreringsfalt, utan Edge Function, KMS eller produktionskryptering.

- **Trigger** `trg_vehicles_reg_fields_guard` / `tg_vehicles_reg_fields_guard`: pa `UPDATE` av `vehicles`, om nagon av `reg_number_ciphertext`, `reg_number_hash`, `reg_number_last4` andras kravs sessionsflagga `app.vehicle_registration_internal_update = '1'` (satts endast i RPC). Annars: fel meddelande som pekar pa `update_vehicle_registration_fields()`.
- **RPC** `public.update_vehicle_registration_fields(p_vehicle_id, p_ciphertext, p_hash, p_last4)` — `SECURITY DEFINER`, `search_path = public`: validerar `auth.uid()`, aktiv tenantmedlem, samma roll/workshop-regler som `vehicles_update_scoped` (owner/admin eller receptionist med workshop-access), **ej** mechanic/viewer; blockerar cross-tenant via medlemskapskontroll; **unik** `reg_number_hash` per tenant (konflikt → fel); uppdaterar tre kolumner under GUC-bypass.
- **GRANT** `EXECUTE` till `authenticated`; **REVOKE** fran `PUBLIC` och `anon`.
- **Ej i 0007:** kryptering, normalisering av platen, nyckelhantering, INSERT-hardning, kolumn-REVOKE, receipts, `DELETE`-policies.

**Planering (fortsatt regnr):** **`docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`**. Backend/Edge som **inte** skickar fardiga DB-falt fran klient; eventuellt kolumnprivilegier sa endast RPC-roll skriver `reg_number_*`.

## Implementerat: `0008_receipts_rpc_foundation.sql`

**Syfte:** lagrisk **RPC-first** grund for **skapande** av kvitton utan fri klient-`INSERT`/`UPDATE`/`DELETE` pa `receipts`.

- **`public.create_receipt(...)`** — `SECURITY DEFINER`, `search_path = public`: kraver `auth.uid()`, aktiv `tenant_members` (**ej** suspended/revoked), **endast** `owner` eller `admin` i aktuell tenant, samt `current_user_has_workshop_access(tenant_id, workshop_id)`. Validerar att `workshops`, `customers`, `vehicles` matchar tenant/workshop och att kund/fordon hor ihop. Valfri **`p_booking_id`** kontrolleras mot samma tenant/workshop/kund/fordon (tabellen `receipts` har **inget** `booking_id` i `0001` — bokning valideras endast om parametern satts). Valfri `work_order_id` / `quote_id` med samma konsistenskrav. Belopp: inga negativa varden; `total_amount` maste vara `subtotal_amount + vat_amount`. Endast `payment_status = 'unpaid'` vid skapande. `created_by` / `updated_by` satts **alltid** fran `auth.uid()` i RPC (ingen klient-spoof).
- **Ingen** `INSERT`-policy pa `receipts` — direkt klient-`INSERT` forblir nekad (RLS).
- **`receipts_deny_client_update` / `receipts_deny_client_delete`:** `UPDATE`/`DELETE` for `authenticated`; `USING(...)` anropar hjalpfunktion som **alltid** `RAISE` (tydligt fel vid klientforsok; annars kan "0 rows" utan fel under RLS).
- **Hjalpfunktioner** `receipts_deny_client_update()`, `receipts_deny_client_delete()`: `SECURITY DEFINER`, `REVOKE` fran `PUBLIC`/`anon`, `GRANT EXECUTE` till `authenticated`.
- **`create_receipt`:** `REVOKE` fran `PUBLIC`/`anon`, `GRANT EXECUTE` till `authenticated`.
- **Ej i 0008:** `UPDATE`-RPC (void/betalning/refund/kredit), `DELETE`-policy, Edge/backend, frontend, beloppsvalidering mot offert/AO, audit-tabell.

**Automatiserad write-regression (pgTAP):** `supabase/tests/database/rls_write_policies.test.sql` (**93** test, `plan(93)`). Kor med `npx supabase db reset` och `npx supabase test db` tillsammans med SELECT-sviten (**125** tester totalt: 32 SELECT + 93 write). Syntetiska `auth.users`, tenants/workshops, medlemskap och domandata; `rollback` i slutet av testfilen.

**Tackning (0005):**

- **profiles:** egen `UPDATE`; blockerat att skriva annan anvandares rad (verifierat via oforandrat `full_name` — Postgres ger inget fel vid 0 traffar); `user_id`-andring blockerad.
- **customers:** `INSERT`/`UPDATE` for owner/admin/receptionist inom ratt scope; receptionist utan workshop-access nekad; mechanic/viewer/no membership/suspended/revoked nekad; cross-tenant insert nekad; `tenant_id`-andring nekas (RLS `WITH CHECK` och/eller trigger `tenant_id cannot be changed`).
- **bookings:** owner/admin/receptionist happy path; mechanic insert nekad; fel tenant pa vehicle nekad; receptionist update i A1; viewer utan A1-access kan inte andra A1-rad (verifierat via oforandrat `notes`); `tenant_id`-andring nekad.
- **quotes:** insert/update for owner/admin/receptionist; `booking_id` fran annat verkstadspar nekad; customer fran annan tenant nekad; mechanic insert nekad; `tenant_id`-andring nekad.
- **quote_items:** insert/update mot parent quote; fel `tenant_id` mot parent nekad; mechanic nekad; `tenant_id`-andring nekad.

**Tackning (0006 + 0007 fordon):**

- **vehicles:** owner/receptionist insert/update i ratt scope; receptionist A2 utan access nekad; mechanic/viewer nekad; customer fran annan tenant nekad; `tenant_id`-andring nekad; no membership nekad.
- **0007:** direkt `UPDATE` av `reg_number_*` nekad; owner/receptionist andrar reg-falt via RPC; mechanic/viewer/cross-tenant/hash-konflikt nekad via RPC.
- **work_orders:** owner/mechanic insert/update; receptionist/viewer nekad; vehicle fran tenant B nekad; `booking_id` fel verkstad nekad; mechanic utan A2-access nekad A2; `tenant_id`-andring nekad.
- **tire_hotel:** receptionist/mechanic/owner insert/update; viewer nekad; receptionist utan A2-access nekad; customer B pa tenant A nekad; `tenant_id`-andring nekad.
- **Fortfarande utan klient-write:** `INSERT` nekad for `authenticated` pa `tenants`, `workshops`, `tenant_members`, `workshop_members` (W33–W36). **Receipts:** direkt tabell-`INSERT` nekad (W69); skapande via **`create_receipt`** for owner/admin (W71–W72); receptionist/mechanic/viewer/suspended/revoked/no membership nekad (W73–W78); cross-tenant/workshop och fel FK-kontext nekad (W79–W84); belopp/status-validering (W85–W87); direkt `UPDATE`/`DELETE` nekad (W88–W89); `created_by` fran `auth.uid()` (W90).

**Receptionist (implementation vs enkel workshop-roll):** policies i `0005`/`0006` for receptionist-skrivning kraver `tenant_members.role = 'receptionist'` **och** `current_user_has_workshop_access` dar workshop kravs. Test **W70**/`W06`/`W07` stodjer detta. Om produktplanen var "receptionist enbart via workshop_members" ar det en **policy-/plan-mismatch**; atgard = framtida migration.

**Kanda luckor / begransningar i write-sviten:**

- Inga `DELETE`-policy-tester (policies saknas avsiktligt).
- `UPDATE` som inte matchar nagon rad under RLS ger **inget** Postgres-fel; negativa fall for cross-user/cross-workshop kan darfor vara "sidoeffekt"-asserts (data oforandrad), inte `throws_ok`.
- `tenant_id`-immutability: felmeddelande kan vara RLS **eller** trigger beroende pa evalueringsordning; tester anvander regex som tillater bada.
- Fordon i negativt `vehicles`-insert: `reg_number_hash` satts med `decode(..., 'hex')` (ingen `digest()` i `authenticated`-session).

## 1) Gemensamma principer

- **viewer:** ingen skrivratt (`INSERT`/`UPDATE`/`DELETE`) via RLS for klient-sessioner.
- **Minsta privilegium:** workshop-scoped data ska skrivas med **workshop-access** dar tabellen har `workshop_id`; tenant-metadata med **tenant owner/admin** dar det ar motiverat.
- **WITH CHECK:** varje write-policy ska validera att `tenant_id` (och `workshop_id` nar den finns) stammer fran samma tenant/workshop som anvandaren far skriva i; inga "flyttar" av rader mellan tenants via `UPDATE`.
- **Inga DELETE-policies i forsta write-migration:** prioritera **soft delete / archive** (ny kolumn eller status) i senare datamodell-migration; tills dess ska `DELETE` forbli **utan** policy (dvs nekad for `authenticated`) om inte tabellen redan ar oppen utan RLS for superuser-only.
- **Service role i frontend:** **forbjuden**; klienten anvander endast `anon`/`authenticated`. Privilegierade floden (invite, receipt finalisering, regnr-kryptering) sker via **Edge Function / backend / saker RPC** med separat identitet och strikt validering.
- **Audit:** inga `audit_*`-tabeller i detta repo an; nar de infors ska de **inte** vara klientskrivbara — endast server-side eller `SECURITY DEFINER`-RPC med hard kontroll.
- **Kanslig data:** `vehicles.reg_number_*` ska betraktas som hogkansligt; klient-write ska begransas eller ersattas av RPC som satter ciphertext/hash konsekvent.

## 2) Roller — skrivratt (oversikt)

| Roll        | Tenant-admin (tenants, workshops, membership) | Operativ skriv (kunder, bokningar, offerter, AO, kvitton, dackhotell) |
|------------|--------------------------------------------------|----------------------------------------------------------------------|
| owner      | Ja (inom egen tenant)                            | Ja, brett; kvitto/receipts enligt tabell nedan                      |
| admin      | Ja (inom egen tenant)                            | Ja, brett; kvitto/receipts enligt tabell nedan                      |
| mechanic   | Nej                                              | Ja, begransat till verkstads-/AO-/statusfalt                        |
| receptionist | Nej (i 0005/0006: operativ skriv kraver **tenant**-roll `receptionist` + workshop-access dar sa kravs; inte enbart workshop-roll) | Ja: kund/bokning/offert/`vehicles`/`tire_hotel` (0005/0006); **nej** direkt skriv till `work_orders` i 0006   |
| viewer     | Nej                                              | Nej                                                                  |

**Workshop vs tenant:**  
- Dar tabellen har **obligatorisk** `workshop_id` (t.ex. `bookings`): **workshop-access** kravs for `mechanic`/`receptionist` (via `current_user_has_workshop_access` / roll-helper).  
- `owner`/`admin` kan skriva enligt tabell dar tenant-niva ar medvetet tillaten (t.ex. skapa workshop under tenant, uppdatera `workshops`).

## 3) `created_by` / `updated_by` — strategi

- **Mal:** sparbarhet utan att lita pa klientens payload.
- **Rekommendation:**
  - **INSERT:** satt `created_by = auth.uid()` via **trigger** `BEFORE INSERT` (eller `DEFAULT` dar lampligt) — inte enbart via klient.
  - **UPDATE:** satt `updated_by = auth.uid()` via trigger `BEFORE UPDATE`; RLS far fortfarande begransa *vem* som far uppdatera.
  - **RLS:** valfritt komplettera med policy-villkor att `created_by` inte far andras pa `UPDATE` (endast trigger/admin-RPC).
- **Profiles:** har inga `created_by`/`updated_by` i nuvarande schema; hall `user_id` immutable efter insert (trigger eller policy).

## 4) Server-side / saker RPC (rekommenderat utanfor RLS)

Foljande operationer ska **inte** erbjudas som fri klient-`INSERT`/`UPDATE` mot tabellen om de kan kringga affarsregler eller lackage kanslig data:

- **Medlemskap:** invite, rollbyte, `suspended`/`revoked`, borttag av `workshop_members` / `tenant_members`.
- **Tenants:** skapa ny tenant (onboarding), `slug`-andring, avaktivering.
- **Fordons registreringsdata:** skrivning till `reg_number_ciphertext`, `reg_number_hash`, `reg_number_last4` — **enhetlig RPC** som normaliserar, hashar och (om tillampigt) krypterar.
- **Receipts:** utfardande, `payment_status` `paid`/`voided`, beloppsjusteringar som paverkar bokforing — **RPC** eller admin-only med extra `WITH CHECK`.
- **Framtida audit-logg:** endast server.

RLS-policies for dessa tabeller kan da vara **tillat SELECT** (redan) men **ingen direkt klient-write**, utom dar explicit rad nedan sager "egen rad / self".

## 5) Per-tabell plan

Nedan: **INSERT** / **UPDATE** / **DELETE**, **scope** (tenant/workshop), **WITH CHECK-nycklar**, **falt som begransas**, **RPC-preferens**.

### 5.1 `tenants`

| | Beslut |
|---|--------|
| **INSERT** | **Ej klient.** Endast onboarding-RPC eller plattforms-admin (utanfor denna apps RLS-klient). |
| **UPDATE** | `owner`/`admin` med `current_user_has_tenant_role(id, {owner,admin})`; **WITH CHECK** `id` oforandrad (eller samma som USING-rad); blockera andring av `slug` for normal admin om risk for brutna lankar — eller endast owner. |
| **DELETE** | **Ej** i forsta lage; soft-deactivate (`is_active`) via owner/admin eller RPC. |
| **Scope** | Tenant-niva. |
| **Falt** | `slug`, `legal_name`, `org_number` — endast owner/admin; `metadata` med forsiktighet. |

### 5.2 `workshops`

| | Beslut |
|---|--------|
| **INSERT** | `owner`/`admin` pa **parent** `tenant_id`; **WITH CHECK** `tenant_id` matchar tenant dar anvandaren ar owner/admin och aktiv medlem. |
| **UPDATE** | Samma som INSERT (USING + WITH CHECK pa `tenant_id`, `id`). |
| **DELETE** | **Ej**; `is_active = false` eller archive-flagga (senare schema). |
| **Scope** | Tenant-niva skrivning; ingen workshop-membership kravs for owner/admin att skapa workshop (stammer med SELECT-hardning). |
| **Falt** | `code` unikt per tenant — validera i applikation + DB constraint (redan). |

### 5.3 `profiles`

| | Beslut |
|---|--------|
| **INSERT** | **Sjalv** vid forsta inloggning: `user_id = auth.uid()` endast; eller **RPC** som skapar profil efter `auth.users`. |
| **UPDATE** | **Sjalv:** `user_id = auth.uid()` — far andra `full_name`, `phone`, `metadata` (begransa PII-nycklar i metadata); **owner/admin** far **inte** skriva direkt till andras `profiles` via klient (SELECT finns redan begransat); andringar for andra anvandare = **RPC**. |
| **DELETE** | **Ej**; inaktivera via `is_active` eller hantera i `auth`. |
| **Scope** | Self + styrd RPC. |
| **Falt** | `user_id` immutable. |

### 5.4 `tenant_members`

| | Beslut |
|---|--------|
| **INSERT** / **UPDATE** / **DELETE** | **Ej direkt klient.** Endast **saker RPC** (owner/admin invite, revoke, rollbyte). RLS kan forbli **ingen write-policy** for `authenticated` = nekad write. |
| **Scope** | Tenant. |
| **Falt** | `role`, `membership_status`, `is_default_tenant` — endast RPC med validering. |

### 5.5 `workshop_members`

| | Beslut |
|---|--------|
| **INSERT** / **UPDATE** / **DELETE** | **Ej direkt klient** (samma som `tenant_members`). **RPC** med validering av `(tenant_id, workshop_id)` och att anvandaren ar owner/admin i tenant eller workshop. |
| **Scope** | Workshop + tenant composite. |

### 5.6 `customers`

| | Beslut |
|---|--------|
| **INSERT** | `owner`/`admin` **eller** `receptionist` med aktiv medlemskap; **WITH CHECK** `tenant_id` = tillaten tenant och om `workshop_id` ar satt: `current_user_has_workshop_access(tenant_id, workshop_id)` **eller** owner/admin pa tenant. |
| **UPDATE** | Samma som INSERT (USING + WITH CHECK); forbjud andring av `tenant_id`; `workshop_id` andring endast owner/admin eller receptionist med access till **bade** gammal och ny workshop (eller endast owner/admin om enklare). |
| **DELETE** | **Ej**; soft-archive (`metadata` eller `deleted_at` i framtida migration). |
| **Scope** | Primart workshop for receptionist; tenant-level for owner/admin. |
| **Falt** | `customer_number` — receptionist far skapa; andring av ekonomiskt kansliga falt = begransa. |

### 5.7 `vehicles`

| | Beslut |
|---|--------|
| **INSERT** | `owner`/`admin` **eller** `receptionist` (workshop-scope); **WITH CHECK** `tenant_id`, `customer_id` tillhor samma tenant (join-validering i policy eller trigger); `workshop_id` konsistent med policy. **Registreringsfalt:** helst endast via **RPC** som satter `ciphertext`+`hash`+`last4`; om direkt klient tillats: endast owner/admin/receptionist och aldrig klartext i `ciphertext` (app maste kryptera). |
| **UPDATE** | Samma roller; **forbjud** `tenant_id`-andring; `customer_id`-andring endast inom samma tenant och med workshop-regler; **reg-falt** enligt RPC-rekommendation. |
| **DELETE** | **Ej**; avregistrera via status eller soft delete (framtida). |
| **Scope** | Workshop + tenant; **hard** skydd. |
| **Falt** | `reg_number_*`, `vin` — begransa for mechanic (las: mechanic far ev. endast `odometer`/anteckningar). |

### 5.8 `bookings`

| | Beslut |
|---|--------|
| **INSERT** | `receptionist`, `admin`, `owner` med **workshop-access**; **WITH CHECK** `workshop_id` matchar access, `tenant_id` matchar workshopens tenant. |
| **UPDATE** | Dessa + `mechanic` for **status-/tids-/anteckningsfalt** (policy kan vara tva policies eller en med `CASE` pa kolumn — enklare: separata policies eller trigger som nekar mechanic andring av `tenant_id`/`workshop_id`/`customer_id`). |
| **DELETE** | **Ej**; `status = cancelled` (redan i enum). |
| **Scope** | Workshop. |
| **Falt** | `booking_number` immutable efter insert (trigger); mechanic far inte andra prisfalt om sadana lags till senare. |

### 5.9 `work_orders`

| | Beslut |
|---|--------|
| **INSERT** | `mechanic` (workshop), `admin`, `owner`; **WITH CHECK** workshop-access + samma tenant som `customer`/`vehicle`. |
| **UPDATE** | `mechanic` for arbetsfalt (`status`, `labor_minutes`, `notes`, `assigned_to_label`); `admin`/`owner` fullare; receptionist **valfritt** endast las eller begransad status — rekommenderat **ej** skapa AO om inte receptionist-rollen ska det. |
| **DELETE** | **Ej**; status `cancelled` om behovs (utoka enum i framtida migration om saknas). |
| **Scope** | Workshop. |

### 5.10 `quotes`

| | Beslut |
|---|--------|
| **INSERT** | `receptionist`, `admin`, `owner` med workshop-access; **WITH CHECK** `workshop_id`, `tenant_id`, `customer_id`, `vehicle_id` konsistens. |
| **UPDATE** | Samma; `mechanic` **endast** om affarsregel kraver (annars nej); `status`-andringar kan begransas till receptionist/admin/owner. |
| **DELETE** | **Ej**; `status = cancelled`/`expired`. |
| **Scope** | Workshop. |

### 5.11 `quote_items`

| | Beslut |
|---|--------|
| **INSERT** | `receptionist`, `admin`, `owner`; **WITH CHECK** det finns en `quotes`-rad med samma `quote_id`, `tenant_id`, och anvandaren har write-ratt till den offerten (workshop-access + roll). **Obligatorisk** koppling: `tenant_id` pa item = `quotes.tenant_id`. |
| **UPDATE** | Samma; forbjud andring av `quote_id` till annan offert. |
| **DELETE** | **Ej**; `line_total_amount = 0` + beskrivning "void" eller soft-delete rad (framtida). |
| **Scope** | Harledd fran parent `quotes`. |

### 5.12 `receipts`

Uppdaterad sakerhets- och implementationsvagledning: **`docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`**.

**Implementerat i `0008`:** Skapande **endast** via `public.create_receipt(...)` (`SECURITY DEFINER`); **owner**/**admin** med aktiv medlemskap och workshop-access. **Ej** receptionist/mechanic/viewer i denna foundation. Direkt `INSERT` forblir **nej** (RLS). `UPDATE`/`DELETE` stoppas av neka-policies som `RAISE` (inte generosa klient-policies). Se **`docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`** for void/refund/kredit, frontend och Edge — **ej** byggt i `0008`.

| | Beslut |
|---|--------|
| **INSERT** | **RPC** `create_receipt` (**0008**): owner/admin; validering i SQL enligt ovan. **Receptionist:** **nej** i `0008`. Ingen fri klient-`INSERT`. |
| **UPDATE** | **Ej** klient-`UPDATE` i `0008` (nekad med tydligt fel). Framtida RPC for `payment_status`, `paid_at`, void, m.m. |
| **DELETE** | **Ej**; nekad for `authenticated`. Framtida void/status. |
| **Scope** | Workshop; **extra restriktiv**. |

### 5.13 `tire_hotel`

| | Beslut |
|---|--------|
| **INSERT** | `mechanic`, `receptionist`, `admin`, `owner` med workshop-access; **WITH CHECK** `tenant_id`/`workshop_id` + lankade `customer`/`vehicle` i samma tenant/workshop. |
| **UPDATE** | Samma roller; status `withdrawn`/`stored` — mechanic eller receptionist enligt process. |
| **DELETE** | **Ej**; `status = discarded` eller archive. |
| **Scope** | Workshop. |

## 6) Hogsta risk — tabeller

1. **`tenant_members` / `workshop_members`** — fel write ger cross-tenant access eller privilege escalation; **endast RPC**.
2. **`vehicles`** — registreringsdata; kombinera RLS med **RPC** for kryptografiska falt.
3. **`receipts`** — ekonomi och integritet; **minst** klient-write.
4. **`quotes` / `quote_items`** — `quote_items` maste alltid valideras mot parent `quotes` i **WITH CHECK**.
5. **`customers`** — PII; strikt workshop/tenant **WITH CHECK**.

## 7) DELETE — rekommendation

- **Skjut upp** `DELETE`-policies tills soft-delete/archive ar modellerat (`deleted_at` eller `status`).
- Undantag: ingen klient-`DELETE` alls i MVP; stadata hanteras av admin-RPC med separat sparbarhet.

## 8) Forslag pa forsta write-migration (efter denna plan)

**Rekommendation:** migration `0005` (namn exempel) i **tva logiska steg** i samma fil eller tva filer:

1. **Steg A — "Sakert bottenlager":** triggers for `created_by`/`updated_by` dar kolumner finns; **inga** policies an `tenant_members`/`workshop_members`/`tenants` (klient write fortfarande nekad).
2. **Steg B — receptionist + admin operativt:** `INSERT`/`UPDATE` policies for `customers`, `bookings`, `quotes`, `quote_items` med strikta `WITH CHECK` + `profiles` self-`UPDATE` endast.

**Steg C (0006):** ~~`vehicles`, `work_orders`, `tire_hotel`~~ **klart** i `0006_operational_write_policies.sql`. **Steg D (`0008`):** ~~receipts RPC-grund (`create_receipt`)~~ **klart**; **aterstar** void/betalnings-RPC, audit-triggers, produktregler.

Efter varje steg: utoka `supabase/tests/database/*.test.sql` med write-negative/positive tester (ny fil eller utokning — separat uppgift).

## 9) Checklista innan implementation

- [ ] Product owner godkanner rollmatris for `receipts` och `work_orders`.
- [ ] Beslut om soft-delete kolumner (separat datamigration).
- [ ] Beslut om regnr-RPC kontra klient-krypterat payload.
- [x] Verifiera att `npx supabase test db` ar gron efter `0005`–`0008` (SELECT 32/32 + write 93/93 i nuvarande miljo; **125** totalt).
- [x] `supabase/tests/database/rls_write_policies.test.sql` for skrivscenarier (0005 + 0006 + 0007 reg-hantering + **0008 receipts**).
- [ ] Inga service-role nycklar i frontend.

---

*Avsnitt 5 beskriver fortfarande helhetsbeslut; operativ skriv for `vehicles`/`work_orders`/`tire_hotel` ar i **0006**; **registreringsfalt-UPDATE** i **0007**; **kvitto-skapande (foundation)** i **0008** (`create_receipt`). **Nasta steg:** **`docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md`** (void/betalning, fortsatt regnr/kryptering, Edge/backend).*
