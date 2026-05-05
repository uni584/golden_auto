# Receipts och registreringsnummer — säkerhetsplan (nästa steg)

Detta dokument är **besluts- och planunderlag** för hur Golden Auto ska hantera **kvitton (`receipts`)** och **registreringsnummer på `vehicles`** efter migrationerna `0001`–`0006`. Det ändrar inte kod eller schema; det ska stödja nästa implementationsomgång.

**Relaterat:** `docs/RLS_WRITE_POLICY_PLAN.md`, `docs/RLS_POLICY_PLAN.md`, `docs/SUPABASE_SCHEMA_NOTES.md`.

---

## Rekommenderade huvudbeslut (sammanfattning)

| Område | Rekommendation |
|--------|----------------|
| **Receipts — skapande** | **Primärt via säker server-side väg** (Edge Function, backend eller `SECURITY DEFINER`-RPC med strikt validering). **Ej** fri klient-`INSERT` mot `receipts` i första skarpa läget. |
| **Receipts — uppdatering** | Känsliga fält (`payment_status`, belopp, `paid_at`, kopplingar) via **samma server-side väg** eller **mycket snäv RLS** endast för `owner`/`admin` med triggers som spärrar beloppsändring efter `paid`. |
| **Registreringsnummer** | **Ej** att klienten sätter `reg_number_ciphertext` / `reg_number_hash` / `reg_number_last4` direkt på sikt; **dedikerad RPC/backend** som normaliserar, hashar och krypterar. |
| **Nästa kodsteg (ordning)** | **Föreslå regnr-/fordons-RPC (härdning) före eller tillsammans med första receipts-skrivning**, så att ekonomiska poster inte byggs ovanpå fortsatt svag regnr-yta. Receipts kan därefter implementeras med tydlig kopplings- och beloppsvalidering. |

---

## 1. Receipts

### 1.1 Rollmatris (rekommendation)

| Roll | Skapa receipt | Uppdatera receipt | Kommentar |
|------|---------------|---------------------|-----------|
| **owner** | Via **server-side** (rekommenderat) eller, om produkt kräver det, **snäv RLS** + triggers | Justeringar / void / korrigering enligt policy; helst **RPC** för status och belopp | Ekonomisk ansvarsnivå; minska risk för bedrägeri. |
| **admin** | Som owner | Som owner | |
| **receptionist** | **Normalt nej** till att skapa kvitto i första version (hög risk för felaktiga belopp/betalningsstatus) | **Nej** för `paid`/`voided`/belopp | Undantag endast om produktägare uttryckligen kräver det och policy/trigger begränsar fält. |
| **mechanic** | **Nej** | **Nej** (eller enbart icke-ekonomiska fält i extremt begränsad variant — **ej rekommenderat** i MVP) | Verkstad ska inte kunna fabricera betalda kvitton. |
| **viewer** | **Nej** | **Nej** | |

### 1.2 Ska receipts vara klient-write alls?

**Standardrekommendation: nej för `INSERT` och nej för känsliga `UPDATE` direkt från app mot tabellen.**

Motivering:

- Kvitton är **ekonomiskt och juridiskt känsliga**; fel eller illvillig klient kan skapa **skenbart betalda** poster eller manipulera belopp om endast generiska RLS-policies skyddar.
- RLS kan begränsa tenant/workshop, men **validering av affärsregler** (ex. att belopp stämmer mot offert/AO, att `work_order_id`/`quote_id` är konsekvent, att övergång till `paid` är tillåten) passar bättre i **en kodväg** med tester och loggning.
- **Service role i frontend är förbjuden**; den säkra vägen är **server** med egen auktorisation och idempotens där det behövs.

**Alternativ (nedprioriterat):** begränsade `INSERT`/`UPDATE` RLS-policies endast för `owner`/`admin`, kombinerat med:

- triggers för `tenant_id` immutable, `created_by`/`updated_by`,
- trigger eller constraint som **förhindrar** ändring av `subtotal_amount`/`total_amount`/`vat_amount` efter viss status,
- strikta `WITH CHECK` mot `customer_id`/`vehicle_id`/`workshop_id` i samma tenant.

Även då bör **övergång till `paid` och `voided`** ske via **namngiven RPC** så att händelsen kan loggas enhetligt.

### 1.3 Server-side / RPC

**Rekommendation:** inför en eller flera **explicita funktioner**, t.ex.:

- `create_receipt_from_work_order(...)` — validerar att AO finns, tillhör workshop, kund/fordon matchar, belopp inom gränser.
- `finalize_receipt_payment(...)` — sätter `payment_status`, `paid_at` under kontrollerade villkor.
- `void_receipt(...)` — sätter `voided` med anledning (ev. ny kolumn `void_reason` i framtida migration).

RPC ska:

- köras som **`SECURITY DEFINER`** med **fast `search_path`**,
- använda **`auth.uid()`** för actor,
- **inte** lita på att klienten skickar färdiga ekonomiska summor utan att validera mot underlag där så krävs,
- returnera tydliga fel till klienten utan att läcka intern data.

### 1.4 Skydd av ekonomisk data

- **Belopp och valuta:** validera rimlighet, avrundning och att ändringar spärras efter `paid` (eller kräv separat **korrigerings-/kreditflöde**).
- **Integritet:** `receipt_number` unikt per tenant; överväg **trigger** som förhindrar ändring av nyckelfält efter utfärdande.
- **Koppling till underlag:** när `work_order_id` eller `quote_id` sätts ska **`EXISTS`-kontroller** säkerställa samma `tenant_id` och **samma `workshop_id`** som kvittot (likt befintliga mönster för `quotes`/`bookings`).

### 1.5 Säker koppling till customer, vehicle, booking, work_order

- **FK i schema** (redan i `0001`) ger basintegritet; **RLS/RPC** måste spegla samma logik:
  - `customer_id` och `vehicle_id` tillhör **samma tenant** som kvittot.
  - `work_order_id` / `quote_id` valfria men om satta: samma tenant och **workshop** som kvittots `workshop_id`.
- **Booking:** idag finns inget direkt `booking_id` på `receipts`; koppling sker via AO/offert. Om framtida behov finns, kräver det **datamodellbeslut** (utanför denna planfil).

### 1.6 DELETE

**Rekommendation:** **fortsätt utan `DELETE`-policy** för klient. Använd **`payment_status = voided`** (eller framtida `cancelled`/`refunded` enligt enum-utökning) med **obligatorisk anledning och audit**.

### 1.7 Soft delete, status, cancel, refund

- **Void:** använd befintlig `voided` i `payment_status` där det räcker; dokumentera vem som voidat och när (audit).
- **Refund:** antingen utökad enum (`refunded` finns) med separat affärslogik i RPC, eller **ny rad** / kreditkvitto — **produktbeslut** innan migration.
- **Soft delete:** om `deleted_at` införs senare ska den **endast** sättas server-side; aldrig klientskrivbar.

---

## 2. Registreringsnummer (`vehicles`)

### 2.1 Risk med direkt klientwrite

Nuvarande RLS (`0006`) tillåter **owner/admin/receptionist** att skriva **`reg_number_ciphertext`**, **`reg_number_hash`**, **`reg_number_last4`** utan att databasen validerar kryptografi eller normalisering.

Risker:

- **Felaktig eller tom “ciphertext”** som ändå lagras.
- **Hash som inte följer av samma normalisering** som sökning förväntar → trasig unikhet eller kollisioner.
- **Läckage av pseudonymiserad data** via `reg_number_last4` om satt godtyckligt.
- **Korrelation** mellan klient och lagrade värden utan central nyckelhantering.

### 2.2 Rekommenderat säkrare flöde

1. **Klienten skickar endast registreringsnummer i ett kontrollerat anrop** (HTTPS till Edge Function/backend, eller RPC med **endast klartext/reg-input** — aldrig färdig ciphertext från opålitlig klient om ni vill ha strikt modell).
2. **Servern:**
   - normaliserar (gemener/versaler, landsspecifik validering för `reg_country_code`),
   - beräknar **deterministisk hash** (samma algoritm och salt/pepper-strategi som dokumenteras),
   - krypterar till **`reg_number_ciphertext`** med nyckel som **inte** finns i appen,
   - sätter **`reg_number_last4`** enligt regel (maskning).
3. **Databasen** uppdateras via RPC som **endast** skriver de tre fälten (eller hela raden) under samma transaktion som validering.

Valfritt nästa steg i migration:

- **REVOKE** `UPDATE` på `reg_number_*` för `authenticated` på `vehicles` och låt **endast RPC** (som ägars av begränsad roll) skriva dessa kolumner — kräver ofta **kolumnprivilegier** eller separat vy/policy-design (implementationsdetalj i framtida migration).

### 2.3 Vad frontend får och inte får skicka

| Tillåtet (rekommendation) | Ej tillåtet / undvik |
|---------------------------|----------------------|
| Registreringsnummer som **indata** till **säker endpoint** | Färdiga **`reg_number_ciphertext` / `reg_number_hash`** från klient i skarpa läget |
| Visa **maskerat** värde som server returnerar (`last4` eller servergenererad label) | Lagra eller logga **klartext** regnr i analytics utan DPIA/beslutsstöd |
| Anropa **namngiven RPC** med `vehicle_id` + nytt regnr vid byte | Direkt `UPDATE vehicles SET reg_number_*` via generisk Supabase-klient när härdning är på plats |

### 2.4 Innan riktig kunddata

- Dokumentera **nyckelrotation**, **var nycklar lagras** (t.ex. KMS, Vault), och **vem som får dekryptera**.
- Säkerställ **backup och rättslig grund** (GDPR) för behandling av fordonsidentifierare.
- Kör **penntest / kodgranskning** av RPC och RLS tillsammans.
- Migrera befintliga test-/staging-rader så att hash-algoritm och ciphertext-format är **konsekventa** innan produktion.

---

## 3. Audit

### 3.1 Receipts och regnr-ändringar

- **Receipts:** logga minst: `created`, `payment_status_changed`, `voided`, `amount_corrected` (om tillåtet), med **actor** (`auth.uid()` eller service identity), **tid**, **tenant/workshop**, **receipt_id**, och **före/efter** för kritiska fält (i säker logg — undvik PII i klartext i oskyddade loggar).
- **Registreringsnummer:** logga **byte av hash/ciphertext** (inte klartext regnr i applikationsloggar); koppla till `vehicle_id` och actor.

### 3.2 Varför `audit_logs` inte ska vara klientskrivbar

- Klienten kan **fabricera** eller **radera** spår efter missbruk.
- Audit ska vara **append-only** från server/trigger med hög trovärdighet.
- Rekommendation: tabell **endast** skrivbar av **`SECURITY DEFINER`-funktioner** eller **databasroll** som klienten aldrig använder; RLS som **nej** till `INSERT`/`UPDATE`/`DELETE` för `authenticated`.

### 3.3 Händelser att logga (minimum)

- Kvitto: skapad, betalningsstatus ändrad, void, beloppsjustering (om tillåten).
- Fordon: regnr uppdaterat (via RPC), `customer_id`/`workshop_id`-ändring om det tillåts.
- Misslyckade auktoriseringsförsök mot RPC (rate limit / övervakning).

---

## 4. Rekommenderad nästa migration och ordning

### 4.1 Alternativ A (rekommenderad ordning)

1. **Migration / kod: Regnr-RPC och fordonsfält-härdning**
   - Ny RPC (eller Edge Function + service) som sätter `reg_number_*`.
   - Eventuellt: minska eller ta bort direkt klientuppdatering av dessa kolumner (privilegier / policy).
   - pgTAP-tester för RPC och befintliga RLS-regressioner.
2. **Migration: Receipts**
   - Triggers: `tenant_id` immutable, `created_by`/`updated_by`, ev. beloppsspärr vid `paid`.
   - **Antingen** inga klient-write policies + endast RPC, **eller** mycket snäva policies enligt avsnitt 1.2.
   - Utökad testsvit för receipts och negativa fall.

**Motivering:** minskar risk att ekonomiska dokument skapas samtidigt som regnr fortfarande kan manipuleras godtyckligt från klient; en gemensam “sanering” av fordonsidentitet förenklar efterföljande kvittovalidering.

### 4.2 Alternativ B (parallellt)

- Två team: ett på regnr-RPC, ett på receipts-RPC — **kräver** gemensamt gränssnitt för validering av `vehicle_id` vid kvittoskapande och **integrations-/migrationsdisciplin** så att inte receipts släpps före minsta regnr-härdning.

### 4.3 Om `0007` enbart är receipts

**Möjligt scope för `0007_receipts_write_*.sql` om produkt prioriterar kvitton först:**

- Triggers på `receipts` (audit actors, `tenant_id`).
- **Antingen** policies endast för `owner`/`admin` **eller** inga insert/update policies och enbart RPC — **måste** matcha beslut i avsnitt 1.
- Inga `DELETE`-policies.
- **Risk:** regnr förblir svag tills separat migration; **blockerare** om compliance kräver PII-härdning före ekonomidata.

### 4.4 Risker och blockerare

| Risk | Beskrivning |
|------|-------------|
| **Dubbel skrivväg** | Både RPC och RLS tillåter samma operation → inkonsistent validering. **Mitigering:** en primär skrivväg per operation. |
| **Beloppsmanipulation** | Klient eller komprometterad roll ändrar `total_amount`. **Mitigering:** triggers, RPC-only för känsliga fält, loggning. |
| **Nyckelhantering** | Regnr-kryptering utan KMS/rotation. **Blockerare** för produktion. |
| **Saknad produktdefinition** | Refund/kredit/void-process. **Blockerare** för komplett receipt-livscykel. |
| **FORCE RLS / privilege** | Framtida hårdning kan påverka triggers och DEFINER-funktioner. Planera innan aktivering. |

---

## 5. Nästa steg (checklista, dokumentation)

- [ ] Produktägare godkänner: **receipts RPC-first** vs **snäv RLS** för admin/owner.
- [ ] Juridik/ekonomi: void, refund, korrektion.
- [ ] Teknik: nycklar och algoritm för hash/kryptering av regnr.
- [ ] Uppdatera `RLS_WRITE_POLICY_PLAN.md` och testspec när implementation påbörjas.

*Senast uppdaterad som planunderlag i samband med dokumentations-PR (ingen schemaändring i samma steg).*
