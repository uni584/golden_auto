# Audit logging — plan för foundation (pre-implementation)

Detta dokument är **besluts- och planunderlag** för hur Golden Auto ska införa **append-only audit** för känsliga och affärskritiska händelser. **Ingen implementation** ingår här; migrationer **`0009+`** ska följa denna plan.

**Relaterat:** `docs/RLS_WRITE_POLICY_PLAN.md`, `docs/RLS_POLICY_PLAN.md`, `docs/SUPABASE_SCHEMA_NOTES.md`, `docs/RECEIPTS_AND_REGISTRATION_SECURITY_PLAN.md` (§3 audit).

---

## 1. Rekommenderad tabell: `public.audit_events`

**Namn:** `audit_events` (tydligt append-only; undvik generiska `logs` som krockar med annan telemetri).

**Föreslagen kärnstruktur** (exakt DDL bestäms i `0009`):

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

### 2.1 Klient får inte skriva audit

- **Inga** `INSERT`/`UPDATE`/`DELETE`-policies för `authenticated` på `audit_events`.
- **Ingen** generös `GRANT INSERT` till `authenticated` på tabellen; skrivning sker via **`SECURITY DEFINER`**-funktion som ägs av en roll som bypassar RLS eller har explicit `INSERT`-rätt, med **`search_path`** låst till `public` (eller `public, pg_temp`).
- Klienten ska **inte** kunna anropa en publik “skriv vad som helst”-RPC: intern hjälpfunktion **`append_audit_event(...)`** (eller liknande) anropas bara från andra **definer**-funktioner/triggers som redan validerat kontext.

### 2.2 Läsning (SELECT)

- **RLS aktiverad** på `audit_events`.
- **Första versionen:** endast **`owner`** och **`admin`** med aktivt tenant-medlemskap får `SELECT` inom **egen** `tenant_id` (samma mönster som strikta policies: `current_user_is_active_tenant_member(tenant_id)` + `current_user_has_tenant_role(tenant_id, array['owner','admin'])`).
- **`mechanic`**, **`receptionist`**, **`viewer`:** **ingen** läsrätt till audit i v1 (minskar läckage av PII och intern spårbarhet till verkstadspersonal).
- **Service role / postgres:** endast drift/backup; aldrig exponerad i frontend.

### 2.3 Integritet på databasnivå

- **Ingen** `UPDATE`/`DELETE` för applikationsroller på rader i `audit_events` (policy saknas + inga grants, eller explicit neka-policy som speglar `receipts`-mönstret om erfarenheten kräver tydligt fel).
- **Retention / purge** är en **senare** produkt-/juridisk fråga (ev. partitionering + TTL); inget i första foundation utan beslut.

---

## 3. Händelser att logga

### 3.1 Hög prioritet (bör täckas tidigt i implementation)

| Område | `action` (förslag) | `resource_type` | Kommentar |
|--------|-------------------|-----------------|-----------|
| Registreringsfält | `vehicle.registration_updated` | `vehicle` | Endast efter **`update_vehicle_registration_fields`**; ingen klartext/hash i metadata (se §4). |
| Kvitto | `receipt.created` | `receipt` | Efter **`create_receipt`**; metadata: t.ex. `receipt_number` (affärsnyckel), belopp som redan finns på raden — **ej** kortnummer/hemligheter. |
| Kund | `customer.created` / `customer.updated` | `customer` | Trigger-baserad eller samlad i RPC senare; v1 kan börja med triggers på befintliga write-sökvägar. |
| Fordon (övrigt) | `vehicle.created` / `vehicle.updated` | `vehicle` | Uppdatering av **icke-reg** fält via normal RLS; reg-ändring separat action ovan. |

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

## 5. Rekommenderad migration `0009` (audit foundation)

### 5.1 Vad `0009` bör göra

1. **Skapa** `audit_events` enligt §1 (DDL + index + kommentarer).
2. **Skapa** intern **`append_audit_event(...)`** (eller `append_audit_event_internal`): `SECURITY DEFINER`, fast `search_path`, validerar att anrop sker i tillåten kontext (t.ex. kräver `auth.uid()` när händelsen är användar-driven), **ingen** exponering mot `anon`/`PUBLIC` utöver vad som krävs — helst **endast** `EXECUTE` för `authenticated` **avstår** om funktionen endast anropas från andra definer-funktioner i samma migration; praktiskt: **REVOKE ALL FROM PUBLIC**; **GRANT EXECUTE** endast om nödvändigt för trigger-signaturen (triggers anropar funktion i definer-kontext — ofta räcker det att **bara** `postgres`/ägarrollen kör insert via definer kedja).
3. **RLS + policies:** `SELECT` enligt §2.2; **inga** klient-`INSERT`/`UPDATE`/`DELETE`-policies.
4. **Koppla skrivning** i första vågen till befintliga **RPC:er**:
   - **`update_vehicle_registration_fields`** — ett append efter lyckad uppdatering.
   - **`create_receipt`** — ett append efter lyckad insert.
5. **Triggers** på `customers`, `vehicles` (icke-reg), `bookings`, `quotes`, `quote_items`, `work_orders`, `tire_hotel`: **vänta** till efter RPC-vågen är verifierad, för att undvika dubbelloggning och svår felsökning (särskilt när samma transaktion gör flera ändringar). Alternativ: en trigger med **debounce** per transaktion är överkurs i v1 — börja med **RPC + sedan en tabell i taget** om triggers väljs.

### 5.2 Vad som medvetet kan vänta

- **Full täckning** av alla tabeller i en enda migration.
- **Membership**-audit tills säkra skrivvägar finns.
- **DELETE**-spår (ni har inga klient-`DELETE`-policies på affärstabeller i MVP — fokusera på INSERT/UPDATE).
- **Export** till SIEM / immutabel object storage.

### 5.3 Tester (när `0009` implementeras)

Ny eller utökad **pgTAP**-fil, t.ex. `audit_events.test.sql` eller utökning av write-sviten:

- **`authenticated`:** `INSERT` direkt till `audit_events` → **nekad** (RLS/grant).
- **`owner`/`admin`:** kan `SELECT` egna tenant-rader efter att definer-funktion lagt en rad (via test som anropar en minimal test-RPC eller superuser som simulerar append — enligt er testdisciplin).
- **`mechanic`/`receptionist`/`viewer`:** **0 rader** eller nekad `SELECT` på audit.
- **Cross-tenant:** ingen läsning av annan tenants audit.
- Verifiera att **RPC** som ska logga faktiskt skapar **exakt en** relevant rad (eller dokumenterad volym).

---

## 6. Sammanfattning

| Fråga | Rekommendation |
|--------|----------------|
| Tabell | **`audit_events`** (append-only, §1). |
| Först att logga | **`vehicle.registration_updated`** (RPC), **`receipt.created`** (RPC), därefter övriga domänobjekt enligt §3. |
| Klientmanipulation | **Ingen** klient-`INSERT`/`UPDATE`/`DELETE`; skrivning via **definer** + intern append; **RLS** på `SELECT` till **owner/admin** i v1. |
| Nästa kodsteg | **Ja:** **`0009_audit_events_foundation.sql`** (eller liknande namn) enligt §5 — tabell, RLS för läsning, intern append, koppling till **`update_vehicle_registration_fields`** och **`create_receipt`** först. |

*Senast uppdaterad: plan-only; ingen migration i detta steg.*
