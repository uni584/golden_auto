# Audit logging — plan för foundation (pre-implementation)

Detta dokument är **besluts- och planunderlag** för Golden Autos **append-only audit**. Foundation är implementerad i **`0009_audit_events_foundation.sql`**, första bredare rollout i **`0010_customer_vehicle_audit_triggers.sql`** och operativ rollout i **`0011_booking_work_order_audit_triggers.sql`**; dokumentet beskriver vad som är klart och vad som återstår i `0012+`.

**Relaterat:** `docs/RLS_WRITE_POLICY_PLAN.md`, `docs/RLS_POLICY_PLAN.md`, `docs/SUPABASE_SCHEMA_NOTES.md`, `docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md` (§3 audit).

---

## 1. Tabell: `public.audit_events`

**Namn:** `audit_events` (tydligt append-only; undvik generiska `logs` som krockar med annan telemetri).

**Kärnstruktur i `0009`:**

| Kolumn | Typ | Kommentar |
|--------|-----|-----------|
| `id` | `uuid` PK, default `gen_random_uuid()` | Surrogatnyckel. |
| `tenant_id` | `uuid` NOT NULL, FK → `tenants` | Obligatorisk tenant-scope. |
| `workshop_id` | `uuid` NULL, FK → `workshops` | Sätts när händelsen är verkstadsspecifik; annars `NULL`. |
| `actor_user_id` | `uuid` NULL, FK → `auth.users` (eller endast logisk referens) | Vem som utförde; `NULL` endast om framtida system-/batchidentitet dokumenteras separat. |
| `action` | `text` NOT NULL | T.ex. `receipt.created`, `vehicle.registration_updated`, `customer.updated`. Konvention: `resurs.verb` i snake_case. |
| `resource_type` | `text` NOT NULL | T.ex. `receipt`, `vehicle`, `customer`. |
| `resource_id` | `uuid` NULL | Primärnyckel till affärsobjektet när det finns; vissa händelser kan vara tenant-/policy-nivå. |
| `metadata` | `jsonb` NOT NULL default `'{}'` | **Minimal** strukturerad data (se §4). |
| `created_at` | `timestamptz` NOT NULL default `now()` | Ingen `updated_at` — append-only. |
| `correlation_id` | `text` NULL | Valfri `request_id` / trace-id från Edge/backend när sådan finns; annars `NULL`. |

**Index (riktlinje):** `(tenant_id, created_at DESC)`, `(tenant_id, resource_type, resource_id)`, ev. partial index per `action` om volym kräver det.

**Medvetet utelämnat i v1:** `old_values`/`new_values` som breda kolumnmappar (hög PII-risk); diffar hanteras senare selektivt i `metadata` enligt policy.

---

## 2. Säkerhetsmodell

### 2.1 Klient får inte skriva audit (implementerat)

- **Inga** `INSERT`/`UPDATE`/`DELETE`-policies för `authenticated` på `audit_events`.
- **Ingen** generös `GRANT INSERT` till `authenticated` på tabellen; skrivning sker via **`SECURITY DEFINER`**-funktion som ägs av en roll som bypassar RLS eller har explicit `INSERT`-rätt, med **`search_path`** låst till `public` (eller `public, pg_temp`).
- Klienten kan **inte** anropa audit-skrivning direkt: intern hjälpfunktion **`append_audit_event(...)`** har `REVOKE` från `PUBLIC`/`anon`/`authenticated` och anropas endast från godkända definer-RPC:er.

### 2.2 Läsning (SELECT, implementerat i v1)

- **RLS aktiverad** på `audit_events`.
- **Första versionen:** endast **`owner`** och **`admin`** med aktivt tenant-medlemskap får `SELECT` inom **egen** `tenant_id` (samma mönster som strikta policies: `current_user_is_active_tenant_member(tenant_id)` + `current_user_has_tenant_role(tenant_id, array['owner','admin'])`).
- **`mechanic`**, **`receptionist`**, **`viewer`:** **ingen** läsrätt till audit i v1 (minskar läckage av PII och intern spårbarhet till verkstadspersonal).
- **Service role / postgres:** endast drift/backup; aldrig exponerad i frontend.

### 2.3 Integritet på databasnivå

- **Ingen** `UPDATE`/`DELETE` för applikationsroller på rader i `audit_events` (policy saknas + inga grants, eller explicit neka-policy som speglar `receipts`-mönstret om erfarenheten kräver tydligt fel).
- **Retention / purge** är en **senare** produkt-/juridisk fråga (ev. partitionering + TTL); inget i första foundation utan beslut.

---

## 3. Händelser att logga

### 3.1 Först i implementation (klart i `0009` + `0010` + `0011`)

| Område | `action` (förslag) | `resource_type` | Kommentar |
|--------|-------------------|-----------------|-----------|
| Registreringsfält | `vehicle.registration_updated` | `vehicle` | Efter **`update_vehicle_registration_fields`**; metadata innehåller endast `changed_fields`. |
| Kvitto | `receipt.created` | `receipt` | Efter **`create_receipt`**; metadata innehåller endast `payment_status` och `currency`. |
| Kund | `customer.created` / `customer.updated` | `customer` | **Implementerat i `0010`** via triggers med minimal metadata. |
| Fordon (övrigt) | `vehicle.created` / `vehicle.updated` | `vehicle` | **Implementerat i `0010`** via triggers; reg-fält exkluderas. |
| Bokning | `booking.created` / `booking.updated` | `booking` | **Implementerat i `0011`** via triggers med `{}` för insert och `changed_fields` för update. |
| Arbetsorder | `work_order.created` / `work_order.updated` | `work_order` | **Implementerat i `0011`** via triggers med `{}` för insert och `changed_fields` för update. |

### 3.2 Medel prioritet (kort efter v1)

| Område | Action (förslag) | Kommentar |
|--------|------------------|-----------|
| Bokning | `booking.created` / `booking.updated` | |
| Offert | `quote.created` / `quote.updated` | |
| Offert-rad | `quote_item.created` / `quote_item.updated` | |
| Arbetsorder | `work_order.created` / `work_order.updated` | |
| Däckhotell | `tire_hotel.created` / `tire_hotel.updated` | |

### 3.3 Senare / RPC-only

- **`tenant_members` / `workshop_members`** — ändringar ska loggas när skrivväg finns (idag ofta ingen klient-write); **`membership.granted`**, **`membership.revoked`**, **`role.changed`** m.m.
- **`receipt` void / betalning** — när dedikerade RPC införs (`finalize_payment`, `void_receipt`, …).

---

## 4. Integritet och innehåll i `metadata`

- **Aldrig** råa registreringsnummer, `reg_number_ciphertext`, `reg_number_hash` eller `reg_number_last4` i audit (hash kan fortfarande vara känslig i vissa hotmodeller). Logga **`vehicle_id`** och action `vehicle.registration_updated` — räcker för spårbarhet tillsammans med `actor_user_id` och tid.
- **Aldrig** tokens, lösenord, API-nycklar, full JWT, service-role-hemligheter.
- **PII:** minimera — undvik kundnamn/e-post i metadata om händelsen redan har `resource_id` till `customers`. Undantag endast efter DPIA/produktbeslut.
- **Belopp:** i många fall redan icke-hemliga affärsdata; håll siffror korta och konsekventa med vad som redan syns i appen.
- **`correlation_id`:** bara opersonliga trace-id; ingen payload.

---

## 5. Migration `0009` (genomfört)

### 5.1 Vad `0009` gör

1. **Skapa** `audit_events` enligt §1 (DDL + index + kommentarer).
2. **Skapar** intern **`append_audit_event(...)`**: `SECURITY DEFINER`, fast `search_path`, validerar kontext och blockerar känsliga metadata-nycklar; `REVOKE ALL` från `PUBLIC`/`anon`/`authenticated`.
3. **RLS + policies:** `SELECT` enligt §2.2; **inga** klient-`INSERT`/`UPDATE`/`DELETE`-policies.
4. **Koppla skrivning** i första vågen till befintliga **RPC:er**:
   - **`update_vehicle_registration_fields`** — ett append efter lyckad uppdatering.
   - **`create_receipt`** — ett append efter lyckad insert.
5. **Lämnar triggers** på `customers`, `vehicles` (icke-reg), `bookings`, `quotes`, `quote_items`, `work_orders`, `tire_hotel` till senare för att undvika dubbelloggning i foundation.

## 5b. Migration `0010` (genomfört)

### 5b.1 Vad `0010` gör

- Trigger-audit på `customers`:
  - `customer.created` (AFTER INSERT)
  - `customer.updated` (AFTER UPDATE)
- Trigger-audit på `vehicles`:
  - `vehicle.created` (AFTER INSERT)
  - `vehicle.updated` (AFTER UPDATE)
- Triggerfunktioner anropar intern `append_audit_event(...)`.
- `auth.uid()` krävs för app-audit; seed/superuser utan auth-kontext skapar inte app-audit-rader.
- Metadata:
  - INSERT: `{}` (ingen payloaddump)
  - UPDATE: `changed_fields` (fältnamn), inga row snapshots.

### 5b.2 Regnummer-skydd och dubbelloggning

- `vehicle.updated` exkluderar alltid:
  - `reg_number_ciphertext`
  - `reg_number_hash`
  - `reg_number_last4`
- Om endast regfält/systemfält ändras i vehicle-update skapas **ingen** `vehicle.updated`.
- Primär reg-händelse förblir:
  - `vehicle.registration_updated` via `update_vehicle_registration_fields` (RPC).

### 5b.3 Verifiering (pgTAP)

- write-sviten verifierar `customer.created`, `customer.updated`, `vehicle.created`, `vehicle.updated`.
- write-sviten verifierar att vehicle-trigger metadata saknar `reg_number_*`.
- write-sviten verifierar att `vehicle.registration_updated` fortfarande skapas via RPC.

### 5.2 Vad som medvetet kan vänta

- **Full täckning** av alla tabeller i en enda migration.
- **Membership**-audit tills säkra skrivvägar finns.
- **DELETE**-spår (ni har inga klient-`DELETE`-policies på affärstabeller i MVP — fokusera på INSERT/UPDATE).
- **Export** till SIEM / immutabel object storage.

### 5.3 Tester (genomfört i write-sviten)

Ny eller utökad **pgTAP**-fil, t.ex. `audit_events.test.sql` eller utökning av write-sviten:

- `INSERT` direkt till `audit_events` nekas.
- `UPDATE`/`DELETE` direkt mot `audit_events` ger 0 ändrade rader (ingen write-policy).
- `owner`/`admin` kan läsa tenantens audit-rader; `mechanic`/`receptionist`/`viewer` får 0 rader.
- Cross-tenant läsning blockeras.
- `update_vehicle_registration_fields` och `create_receipt` skapar audit-rader.
- Metadata verifieras mot förbjudna reg-värden/nycklar i test.

---

## 6. Rolloutplan `0012+` (operativa flöden)

### 6.1 Full händelsekatalog (operativ audit)

| Händelse | Rek. väg | `action` | `resource_type` | `tenant_id`/`workshop_id` källa | Tillåten metadata | Förbjuden metadata | Risk | Testkrav (min) |
|---------|----------|----------|-----------------|-------------------------------|-------------------|-------------------|------|----------------|
| Booking create | Trigger | `booking.created` | `booking` | `NEW.tenant_id`, `NEW.workshop_id` | `{}` eller säkra status/enum | notes/fritext, PII, tokens | Medel | **klart i 0011** |
| Booking update | Trigger | `booking.updated` | `booking` | `NEW.tenant_id`, `NEW.workshop_id` | `changed_fields` (+ ev `status`) | full row snapshots, notes-innehåll | Medel | **klart i 0011** |
| Quote create | Trigger | `quote.created` | `quote` | `NEW.tenant_id`, `NEW.workshop_id` | `{}` eller `status`,`currency` | offerttest/fritext, PII | Medel | event skapas, tenant/workshop korrekt |
| Quote update | Trigger | `quote.updated` | `quote` | `NEW.tenant_id`, `NEW.workshop_id` | `changed_fields` (+ ev `status`) | full snapshots, notes/fritext | Medel | event skapas, cross-tenant read block |
| Quote item create | Trigger | `quote_item.created` | `quote_item` | `NEW.tenant_id`, `NULL` workshop | `{}` eller `item_type` | `description` payload, snapshots | Medel | event skapas, resource_id korrekt |
| Quote item update | Trigger | `quote_item.updated` | `quote_item` | `NEW.tenant_id`, `NULL` workshop | `changed_fields` | full snapshots, beskrivningstext | Medel | event skapas, minimal metadata |
| Work order create | Trigger | `work_order.created` | `work_order` | `NEW.tenant_id`, `NEW.workshop_id` | `{}` eller `status` | interna notes/fritext, PII | Medel/Hög | **klart i 0011** |
| Work order update | Trigger | `work_order.updated` | `work_order` | `NEW.tenant_id`, `NEW.workshop_id` | `changed_fields` (+ ev `status`) | notes payload, full snapshots | Medel/Hög | **klart i 0011** |
| Tire hotel create | Trigger | `tire_hotel.created` | `tire_hotel` | `NEW.tenant_id`, `NEW.workshop_id` | `{}` eller `status`,`season` | fritext/noteringar, PII | Låg/Medel | event skapas, role-read korrekt |
| Tire hotel update | Trigger | `tire_hotel.updated` | `tire_hotel` | `NEW.tenant_id`, `NEW.workshop_id` | `changed_fields` (+ ev `status`) | snapshots, fritext | Låg/Medel | event skapas, metadata minimal |

**Varför trigger här:** dessa flöden går idag via flera RLS-write-vägar, inte en enda kontrollerad RPC. Trigger ger konsekvent audit utan backend-beroende.

### 6.2 Trigger vs RPC/server-side rekommendation (operativ)

- **Behåll RPC-audit** för redan centraliserade känsliga flöden:
  - `vehicle.registration_updated` via `update_vehicle_registration_fields`
  - `receipt.created` via `create_receipt`
- **Inför trigger-audit** för domäntabeller med distribuerade write-vägar:
  - `bookings`, `quotes`, `quote_items`, `work_orders`, `tire_hotel`
- **Framtida membership/admin-händelser:** helst **RPC/server-side** när säkra skrivflöden finns, inte breda tabelltriggers i första steget.

### 6.3 Metadata-regler för `0011+`

- **Tillåtet (baseline):**
  - `changed_fields` (array av fältnamn, inte värden)
  - säkra statusfält (`status`, `payment_status`)
  - ofarliga enum-/kodfält (`currency`, `season`, `item_type`, `source`)
- **Förbjudet:**
  - råa regnr och alla `reg_number_*`
  - tokens/hemligheter/lösenord/API-nycklar
  - fulla row snapshots (`old_row`, `new_row`, stora JSON-dumpar)
  - onödig PII (namn, e-post, telefon, adress) när `resource_id` redan finns

### 6.4 Rekommenderad migration `0012+` (nästa steg efter `0011`)

**Ska vänta till `0012+`:**
- `quote.created`, `quote.updated`
- `quote_item.created`, `quote_item.updated`
- `tire_hotel.created`, `tire_hotel.updated`
- membership/admin-audit
- `correlation_id` från backend/request layer
- retention/export-policy (SIEM/object storage)

## 7. Sammanfattning

| Fråga | Rekommendation |
|--------|----------------|
| Tabell | **`audit_events`** (append-only, §1). |
| Först att logga | **`vehicle.registration_updated`** (RPC), **`receipt.created`** (RPC), därefter övriga domänobjekt enligt §3. |
| Klientmanipulation | **Ingen** klient-`INSERT`/`UPDATE`/`DELETE`; skrivning via **definer** + intern append; **RLS** på `SELECT` till **owner/admin** i v1. |
| Nästa kodsteg | **Ja:** kör **`0012`** för `quote.*` + `quote_item.*` och därefter `tire_hotel.*` i `0013+` om ni vill hålla låg risk. |

*Senast uppdaterad: `0011` implementerad och verifierad i pgTAP.*
