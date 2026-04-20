// Golden Auto - mock data for frontend-only showcase
export const SERVICES = [
  { id: "s1", category: "verkstad", name: "Felsökning", description: "Professionell diagnos med datorbaserad utrustning.", priceFrom: 800, durationMin: 60 },
  { id: "s2", category: "verkstad", name: "Bromsbyte fram", description: "Byte av bromsbelägg och kontroll av skivor.", priceFrom: 1800, durationMin: 90 },
  { id: "s3", category: "service", name: "Oljeservice", description: "Olja + filter enligt tillverkarens specifikation.", priceFrom: 1495, durationMin: 60 },
  { id: "s4", category: "service", name: "Stor service", description: "Komplett service med återställning.", priceFrom: 2995, durationMin: 120 },
  { id: "s5", category: "hjulskifte", name: "Hjulskifte", description: "Säsongsskifte med drejmoment.", priceFrom: 495, durationMin: 30 },
  { id: "s6", category: "hjulskifte", name: "Hjulskifte + balansering", description: "Skifte med precisionsbalansering.", priceFrom: 795, durationMin: 45 },
  { id: "s7", category: "dackhotell", name: "Däckhotell – säsong", description: "Temperaturkontrollerad förvaring.", priceFrom: 695, durationMin: 30 },
  { id: "s8", category: "biltvatt", name: "Utvändig tvätt", description: "Handtvätt med pH-neutralt schampo.", priceFrom: 249, durationMin: 30 },
  { id: "s9", category: "biltvatt", name: "Tvätt + invändig", description: "Utvändig + invändig grundrengöring.", priceFrom: 549, durationMin: 60 },
  { id: "s10", category: "rekond", name: "Invändig rekond", description: "Djuprengöring av klädsel, plast och tak.", priceFrom: 2495, durationMin: 180 },
  { id: "s11", category: "rekond", name: "Utvändig rekond", description: "Polering, dekontaminering och lackskydd.", priceFrom: 3495, durationMin: 240 },
];

export const CATEGORIES = [
  {
    key: "verkstad",
    title: "Verkstad",
    subtitle: "Reparation & diagnos",
    blurb: "Alla märken. Originaldelar när det krävs, kvalitetsersättning när det passar.",
    image: "https://images.pexels.com/photos/36044141/pexels-photo-36044141.jpeg",
    icon: "Wrench",
  },
  {
    key: "service",
    title: "Service",
    subtitle: "Enligt tillverkare",
    blurb: "Behåll garantin. Digitala servicebok och transparent uppföljning.",
    image: "https://images.pexels.com/photos/20550054/pexels-photo-20550054.jpeg",
    icon: "GearSix",
  },
  {
    key: "hjulskifte",
    title: "Hjulskifte",
    subtitle: "Säsongsskifte",
    blurb: "Boka enkelt online. Skifte på 20 minuter med dragläges­kontroll.",
    image: "https://images.pexels.com/photos/5260115/pexels-photo-5260115.jpeg",
    icon: "CircleNotch",
  },
  {
    key: "dackhotell",
    title: "Däckhotell",
    subtitle: "Trygg förvaring",
    blurb: "Tempererad lokal. Tvätt, kontroll och märkning ingår.",
    image: "https://images.pexels.com/photos/5260115/pexels-photo-5260115.jpeg",
    icon: "Warehouse",
  },
  {
    key: "biltvatt",
    title: "Biltvätt",
    subtitle: "Handtvätt",
    blurb: "Skonsam utvändig och invändig tvätt utförd av erfarna.",
    image: "https://images.pexels.com/photos/14231669/pexels-photo-14231669.jpeg",
    icon: "Drop",
  },
  {
    key: "rekond",
    title: "Rekond",
    subtitle: "Premium detailing",
    blurb: "Polering, keramik och lackskydd av högsta klass.",
    image: "https://images.pexels.com/photos/29527991/pexels-photo-29527991.jpeg",
    icon: "Sparkle",
  },
];

export const CATEGORY_LABEL = {
  verkstad: "Verkstad",
  service: "Service",
  hjulskifte: "Hjulskifte",
  dackhotell: "Däckhotell",
  biltvatt: "Biltvätt",
  rekond: "Rekond",
};

export const TIME_SLOTS = [
  "08:00", "08:30", "09:00", "09:30", "10:00", "10:30",
  "11:00", "11:30", "13:00", "13:30", "14:00", "14:30",
  "15:00", "15:30", "16:00",
];

export const BOOKINGS = [
  { id: "b1", number: "GA-260420-X7K2M", date: "2026-04-20", time: "08:30", customerName: "Linnea Bergström", phone: "070-321 45 67", regnr: "ABC123", brand: "Volvo", model: "XC60", service: "Hjulskifte + balansering", category: "hjulskifte", status: "in_progress", price: 795 },
  { id: "b2", number: "GA-260420-P3R9N", date: "2026-04-20", time: "09:00", customerName: "Johan Eriksson", phone: "073-112 33 44", regnr: "DEF456", brand: "BMW", model: "320d", service: "Oljeservice", category: "service", status: "confirmed", price: 1495 },
  { id: "b3", number: "GA-260420-M8T1Z", date: "2026-04-20", time: "10:00", customerName: "Sara Lindqvist", phone: "076-998 77 66", regnr: "GHI789", brand: "Audi", model: "A4", service: "Utvändig rekond", category: "rekond", status: "checked_in", price: 3495 },
  { id: "b4", number: "GA-260420-K4Q7V", date: "2026-04-20", time: "11:00", customerName: "Mikael Andersson", phone: "072-445 66 99", regnr: "JKL321", brand: "Tesla", model: "Model 3", service: "Tvätt + invändig", category: "biltvatt", status: "new", price: 549 },
  { id: "b5", number: "GA-260421-W2E5R", date: "2026-04-21", time: "08:00", customerName: "Anna Karlsson", phone: "070-555 12 34", regnr: "MNO654", brand: "Volkswagen", model: "Golf", service: "Bromsbyte fram", category: "verkstad", status: "confirmed", price: 1800 },
  { id: "b6", number: "GA-260421-Y9H3S", date: "2026-04-21", time: "09:30", customerName: "Peter Nilsson", phone: "073-222 11 88", regnr: "PQR987", brand: "Mercedes", model: "C200", service: "Stor service", category: "service", status: "new", price: 2995 },
  { id: "b7", number: "GA-260419-T1B4L", date: "2026-04-19", time: "14:00", customerName: "Eva Persson", phone: "070-888 99 00", regnr: "STU246", brand: "Kia", model: "Ceed", service: "Hjulskifte", category: "hjulskifte", status: "delivered", price: 495 },
  { id: "b8", number: "GA-260419-F5G6U", date: "2026-04-19", time: "15:30", customerName: "Oskar Holm", phone: "072-333 22 11", regnr: "VXY135", brand: "Volvo", model: "V90", service: "Invändig rekond", category: "rekond", status: "delivered", price: 2495 },
];

export const CUSTOMERS = [
  { id: "c1", name: "Linnea Bergström", phone: "070-321 45 67", email: "linnea.b@example.se", vehicles: 1, bookings: 4, lastVisit: "2026-04-20" },
  { id: "c2", name: "Johan Eriksson", phone: "073-112 33 44", email: "johan.e@example.se", vehicles: 2, bookings: 7, lastVisit: "2026-04-20" },
  { id: "c3", name: "Sara Lindqvist", phone: "076-998 77 66", email: "sara.l@example.se", vehicles: 1, bookings: 2, lastVisit: "2026-04-20" },
  { id: "c4", name: "Mikael Andersson", phone: "072-445 66 99", email: "mikael.a@example.se", vehicles: 1, bookings: 1, lastVisit: "2026-04-20" },
  { id: "c5", name: "Anna Karlsson", phone: "070-555 12 34", email: "anna.k@example.se", vehicles: 1, bookings: 3, lastVisit: "2026-03-02" },
  { id: "c6", name: "Peter Nilsson", phone: "073-222 11 88", email: "peter.n@example.se", vehicles: 2, bookings: 9, lastVisit: "2026-04-21" },
  { id: "c7", name: "Eva Persson", phone: "070-888 99 00", email: "eva.p@example.se", vehicles: 1, bookings: 5, lastVisit: "2026-04-19" },
  { id: "c8", name: "Oskar Holm", phone: "072-333 22 11", email: "oskar.h@example.se", vehicles: 1, bookings: 2, lastVisit: "2026-04-19" },
];

export const VEHICLES = [
  { id: "v1", regnr: "ABC123", brand: "Volvo", model: "XC60", year: 2021, customer: "Linnea Bergström", tires: "Michelin 235/55 R19", lastService: "2026-02-10" },
  { id: "v2", regnr: "DEF456", brand: "BMW", model: "320d", year: 2019, customer: "Johan Eriksson", tires: "Continental 225/45 R18", lastService: "2026-03-15" },
  { id: "v3", regnr: "GHI789", brand: "Audi", model: "A4", year: 2022, customer: "Sara Lindqvist", tires: "Pirelli 245/40 R18", lastService: "2026-01-22" },
  { id: "v4", regnr: "JKL321", brand: "Tesla", model: "Model 3", year: 2023, customer: "Mikael Andersson", tires: "Michelin 235/40 R19", lastService: "—" },
  { id: "v5", regnr: "MNO654", brand: "Volkswagen", model: "Golf", year: 2020, customer: "Anna Karlsson", tires: "Goodyear 205/55 R16", lastService: "2025-11-04" },
  { id: "v6", regnr: "PQR987", brand: "Mercedes", model: "C200", year: 2021, customer: "Peter Nilsson", tires: "Bridgestone 225/50 R17", lastService: "2026-04-21" },
  { id: "v7", regnr: "STU246", brand: "Kia", model: "Ceed", year: 2018, customer: "Eva Persson", tires: "Nokian 205/55 R16", lastService: "2026-04-19" },
  { id: "v8", regnr: "VXY135", brand: "Volvo", model: "V90", year: 2020, customer: "Oskar Holm", tires: "Michelin 245/45 R18", lastService: "2026-04-19" },
];

export const STANDARD_ACTIONS = [
  { id: "a1", category: "verkstad", name: "Oljebyte utfört", price: 595 },
  { id: "a2", category: "verkstad", name: "Oljefilter bytt", price: 195 },
  { id: "a3", category: "verkstad", name: "Luftfilter bytt", price: 295 },
  { id: "a4", category: "verkstad", name: "Kupéfilter bytt", price: 395 },
  { id: "a5", category: "verkstad", name: "Tändstift bytta", price: 495 },
  { id: "a6", category: "verkstad", name: "Kamrem bytt", price: 4995 },
  { id: "a7", category: "verkstad", name: "Bromsbelägg fram bytta", price: 1495 },
  { id: "a8", category: "verkstad", name: "Bromsbelägg bak bytta", price: 1495 },
  { id: "a9", category: "verkstad", name: "Bromsskivor fram bytta", price: 2495 },
  { id: "a10", category: "verkstad", name: "Felsökning utförd", price: 795 },
  { id: "a11", category: "verkstad", name: "Batteri bytt", price: 1495 },
  { id: "a12", category: "hjulskifte", name: "Hjulskifte utfört", price: 495 },
  { id: "a13", category: "hjulskifte", name: "Sommarhjul monterade", price: 495 },
  { id: "a14", category: "hjulskifte", name: "Vinterhjul monterade", price: 495 },
  { id: "a15", category: "hjulskifte", name: "Balansering utförd", price: 300 },
  { id: "a16", category: "dackhotell", name: "Däck inlagda i däckhotell", price: 695 },
  { id: "a17", category: "dackhotell", name: "Däck utlämnade från däckhotell", price: 0 },
  { id: "a18", category: "biltvatt", name: "Utvändig tvätt utförd", price: 249 },
  { id: "a19", category: "biltvatt", name: "Invändig rengöring utförd", price: 349 },
  { id: "a20", category: "biltvatt", name: "Fälgrengöring utförd", price: 149 },
  { id: "a21", category: "rekond", name: "Invändig rekond utförd", price: 2495 },
  { id: "a22", category: "rekond", name: "Utvändig rekond utförd", price: 3495 },
  { id: "a23", category: "rekond", name: "Polering utförd", price: 1995 },
  { id: "a24", category: "rekond", name: "Lackskydd applicerat", price: 2495 },
];

export const WORK_ORDERS = [
  { id: "w1", number: "WO-260420-L4K2P", customer: "Linnea Bergström", regnr: "ABC123", vehicle: "Volvo XC60", assignedTo: "Erik (Mekaniker)", status: "in_progress", total: 1095, items: 2, created: "2026-04-20" },
  { id: "w2", number: "WO-260420-M9R7T", customer: "Johan Eriksson", regnr: "DEF456", vehicle: "BMW 320d", assignedTo: "Marcus (Mekaniker)", status: "done", total: 1890, items: 3, created: "2026-04-20" },
  { id: "w3", number: "WO-260419-N2B5F", customer: "Eva Persson", regnr: "STU246", vehicle: "Kia Ceed", assignedTo: "Sofia (Rekond)", status: "invoiced", total: 495, items: 1, created: "2026-04-19" },
  { id: "w4", number: "WO-260419-P8W3X", customer: "Oskar Holm", regnr: "VXY135", vehicle: "Volvo V90", assignedTo: "Sofia (Rekond)", status: "invoiced", total: 2495, items: 2, created: "2026-04-19" },
  { id: "w5", number: "WO-260418-Q1Y6H", customer: "Maria Ström", regnr: "XYZ000", vehicle: "Skoda Octavia", assignedTo: "Erik (Mekaniker)", status: "draft", total: 0, items: 0, created: "2026-04-18" },
];

export const RECEIPTS = [
  { id: "r1", number: "KV-260419-A2B9", customer: "Eva Persson", regnr: "STU246", total: 619, paid: true, created: "2026-04-19" },
  { id: "r2", number: "KV-260419-C7D1", customer: "Oskar Holm", regnr: "VXY135", total: 3119, paid: true, created: "2026-04-19" },
  { id: "r3", number: "KV-260418-E3F8", customer: "Maria Ström", regnr: "XYZ000", total: 1869, paid: false, created: "2026-04-18" },
  { id: "r4", number: "KV-260417-G5H2", customer: "Henrik Sjö", regnr: "QRS147", total: 4369, paid: true, created: "2026-04-17" },
  { id: "r5", number: "KV-260416-J8K4", customer: "Lina Berg", regnr: "LMN258", total: 744, paid: true, created: "2026-04-16" },
];

export const NOTIFICATIONS = [
  { id: "n1", channel: "email", to: "linnea.b@example.se", subject: "Bokningsbekräftelse GA-260420-X7K2M", template: "booking_confirmation", status: "sent", sentAt: "2026-04-18 14:32" },
  { id: "n2", channel: "sms", to: "070-321 45 67", subject: "Bokning bekräftad", template: "booking_confirmed_sms", status: "sent", sentAt: "2026-04-18 14:32" },
  { id: "n3", channel: "email", to: "johan.e@example.se", subject: "Påminnelse imorgon 09:00", template: "reminder", status: "sent", sentAt: "2026-04-19 17:00" },
  { id: "n4", channel: "sms", to: "076-998 77 66", subject: "Din bil är klar för upphämtning", template: "ready_for_pickup_sms", status: "sent", sentAt: "2026-04-20 11:45" },
  { id: "n5", channel: "email", to: "anna.k@example.se", subject: "Säsongspåminnelse – däckskifte", template: "season_reminder", status: "sent", sentAt: "2026-04-15 08:00" },
  { id: "n6", channel: "sms", to: "072-333 22 11", subject: "Tid för hjulskifte?", template: "season_reminder_sms", status: "failed", sentAt: "2026-04-14 08:00" },
];

export const AUDIT_LOGS = [
  { id: "l1", entity: "booking", action: "status:new→confirmed", user: "Superadmin", ts: "2026-04-20 08:12", entityId: "GA-260420-X7K2M" },
  { id: "l2", entity: "booking", action: "status:confirmed→in_progress", user: "Erik (Mekaniker)", ts: "2026-04-20 08:35", entityId: "GA-260420-X7K2M" },
  { id: "l3", entity: "customer", action: "update", user: "Superadmin", ts: "2026-04-20 09:15", entityId: "c2" },
  { id: "l4", entity: "work_order", action: "create", user: "Erik (Mekaniker)", ts: "2026-04-20 09:20", entityId: "WO-260420-L4K2P" },
  { id: "l5", entity: "receipt", action: "create", user: "Superadmin", ts: "2026-04-20 11:50", entityId: "KV-260420-K8M2" },
  { id: "l6", entity: "standard_action", action: "update", user: "Superadmin", ts: "2026-04-19 16:04", entityId: "a5" },
  { id: "l7", entity: "booking", action: "status:in_progress→done", user: "Erik (Mekaniker)", ts: "2026-04-20 11:30", entityId: "GA-260420-X7K2M" },
  { id: "l8", entity: "user", action: "login", user: "Superadmin", ts: "2026-04-20 07:58", entityId: "u1" },
];

export const USERS = [
  { id: "u1", name: "Superadmin", email: "admin@goldenauto.se", role: "superadmin", active: true },
  { id: "u2", name: "Erik Andersson", email: "erik@goldenauto.se", role: "mechanic", active: true },
  { id: "u3", name: "Marcus Berg", email: "marcus@goldenauto.se", role: "mechanic", active: true },
  { id: "u4", name: "Sofia Lindén", email: "sofia@goldenauto.se", role: "detailing", active: true },
  { id: "u5", name: "Camilla Reception", email: "camilla@goldenauto.se", role: "admin", active: true },
];

export const STATUS_LABELS = {
  new: { label: "Ny", color: "bg-blue-100 text-blue-800 border-blue-200" },
  confirmed: { label: "Bekräftad", color: "bg-sky-100 text-sky-800 border-sky-200" },
  checked_in: { label: "Incheckad", color: "bg-indigo-100 text-indigo-800 border-indigo-200" },
  in_progress: { label: "Pågående", color: "bg-amber-100 text-amber-900 border-amber-300" },
  awaiting: { label: "Väntar kund", color: "bg-orange-100 text-orange-900 border-orange-200" },
  done: { label: "Klar", color: "bg-emerald-100 text-emerald-900 border-emerald-200" },
  delivered: { label: "Utlämnad", color: "bg-slate-200 text-slate-800 border-slate-300" },
  cancelled: { label: "Avbokad", color: "bg-red-100 text-red-800 border-red-200" },
  draft: { label: "Utkast", color: "bg-slate-100 text-slate-700 border-slate-200" },
  invoiced: { label: "Fakturerad", color: "bg-emerald-100 text-emerald-900 border-emerald-200" },
};

export const OVERVIEW = {
  todayBookings: 4,
  newBookings: 2,
  inProgress: 1,
  done: 2,
  totalCustomers: 248,
  totalVehicles: 312,
  receiptsPending: 3,
  revenue30d: 184750,
  categories: {
    verkstad: 42, service: 58, hjulskifte: 96, dackhotell: 38, biltvatt: 74, rekond: 29,
  },
};
