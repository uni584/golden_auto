# RLS WRITE POLICY PLAN (PRE-IMPLEMENTATION)

Detta dokument ar en **skrivpolicy-plan** for Golden Auto innan nagra `INSERT`/`UPDATE`/`DELETE` RLS-policies implementeras. Inget har i denna fas andrats i databasen.

**Relaterat:** `docs/RLS_POLICY_PLAN.md` (SELECT + helpers), `docs/RLS_VERIFICATION_PLAN.md` (test/ regression).

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
| receptionist | Nej                                           | Ja, kund/bokning/offert + begransade statusandringar                 |
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

| | Beslut |
|---|--------|
| **INSERT** | **Primart RPC** eller **admin/owner** endast; **WITH CHECK** stammer fran samma workshop och belopp ar rimliga (validering i RPC). **Receptionist:** **ej** skapa kvitto i forsta version om ekonomisk risk. |
| **UPDATE** | **Admin/owner** eller RPC for `payment_status`, `paid_at`; mechanic/receptionist **nej** (undantag: explicit affarskrav senare). |
| **DELETE** | **Ej**; `payment_status = voided` via admin/RPC. |
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

**Steg C (0006):** `vehicles` (garna med RPC-par), `work_orders`, `tire_hotel`, `receipts` (receipts sist eller RPC-only).

Efter varje steg: utoka `supabase/tests/database/*.test.sql` med write-negative/positive tester (ny fil eller utokning — separat uppgift).

## 9) Checklista innan implementation

- [ ] Product owner godkanner rollmatris for `receipts` och `work_orders`.
- [ ] Beslut om soft-delete kolumner (separat datamigration).
- [ ] Beslut om regnr-RPC kontra klient-krypterat payload.
- [ ] Verifiera att `npx supabase test db` fortfarande ar gron efter SELECT-lager.
- [ ] Inga service-role nycklar i frontend.

---

*Detta dokument ar en plan; implementation sker forst i kommande migrationer efter godkannande.*
