import React, { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { motion, AnimatePresence } from "framer-motion";
import { ArrowLeft, ArrowRight, Check, Clock, CalendarBlank, User, Car } from "@phosphor-icons/react";
import { SERVICES, CATEGORY_LABEL, CATEGORIES, TIME_SLOTS } from "@/mock/data";
import { toast } from "sonner";

const STEPS = ["Tjänst", "Datum & tid", "Uppgifter", "Bekräftelse"];

const fmtDate = (d) => d.toISOString().slice(0, 10);

const Booking = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const preSelectedId = location.state?.serviceId || null;
  const preSelectedCat = location.state?.category || null;

  const [step, setStep] = useState(0);
  const [categoryFilter, setCategoryFilter] = useState(preSelectedCat || "verkstad");
  const [serviceId, setServiceId] = useState(preSelectedId);
  const [date, setDate] = useState(null);
  const [time, setTime] = useState(null);
  const [form, setForm] = useState({ name: "", phone: "", email: "", regnr: "", brand: "", model: "", message: "" });
  const [confirmed, setConfirmed] = useState(null);

  const service = SERVICES.find((s) => s.id === serviceId);

  const next = () => setStep((s) => Math.min(s + 1, STEPS.length - 1));
  const prev = () => setStep((s) => Math.max(s - 1, 0));

  const canNext = () => {
    if (step === 0) return !!serviceId;
    if (step === 1) return !!date && !!time;
    if (step === 2) return form.name && form.phone && form.email && form.regnr;
    return true;
  };

  const submit = () => {
    const bookingNumber = `GA-${Date.now().toString(36).toUpperCase().slice(-8)}`;
    setConfirmed({ ...form, bookingNumber, service, date, time });
    toast.success("Din bokning är mottagen!");
    setStep(3);
  };

  // generate next 14 days
  const days = Array.from({ length: 14 }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() + i);
    return d;
  });

  return (
    <div className="bg-[#0A0A0A] text-white min-h-screen" data-testid="booking-page">
      <section className="pt-24 pb-10 border-b border-white/10">
        <div className="max-w-[1100px] mx-auto px-6 md:px-12">
          <div className="flex items-center gap-4 mb-6">
            <div className="amber-divider" />
            <span className="eyebrow text-[#F59E0B]">Online-bokning</span>
          </div>
          <h1 className="font-display font-black text-4xl md:text-5xl lg:text-6xl tracking-[-0.03em]">
            Boka tid
          </h1>

          {/* Stepper */}
          <div className="mt-10 grid grid-cols-4 gap-2">
            {STEPS.map((label, i) => (
              <div key={label} className="flex items-center gap-3" data-testid={`step-indicator-${i}`}>
                <div
                  className={`h-9 w-9 shrink-0 grid place-items-center border text-sm font-bold font-mono-ga transition ${
                    i < step
                      ? "bg-[#F59E0B] border-[#F59E0B] text-black"
                      : i === step
                        ? "border-[#F59E0B] text-[#F59E0B]"
                        : "border-white/20 text-white/40"
                  }`}
                >
                  {i < step ? <Check size={16} weight="bold" /> : String(i + 1).padStart(2, "0")}
                </div>
                <div className={`text-xs tracking-[0.15em] uppercase truncate ${i === step ? "text-white" : "text-white/40"}`}>{label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-12 md:py-16">
        <div className="max-w-[1100px] mx-auto px-6 md:px-12">
          <AnimatePresence mode="wait">
            {step === 0 && (
              <motion.div key="s0" initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -12 }} transition={{ duration: 0.3 }}>
                <div className="flex flex-wrap gap-2 mb-8" data-testid="category-filter">
                  {CATEGORIES.map((c) => (
                    <button
                      key={c.key}
                      onClick={() => setCategoryFilter(c.key)}
                      data-testid={`cat-filter-${c.key}`}
                      className={`px-4 py-2 text-sm border transition ${
                        categoryFilter === c.key
                          ? "bg-[#F59E0B] text-black border-[#F59E0B] font-bold"
                          : "border-white/20 text-white/70 hover:border-white/40"
                      }`}
                    >
                      {c.title}
                    </button>
                  ))}
                </div>

                <div className="grid md:grid-cols-2 gap-4">
                  {SERVICES.filter((s) => s.category === categoryFilter).map((svc) => (
                    <button
                      key={svc.id}
                      onClick={() => setServiceId(svc.id)}
                      data-testid={`service-option-${svc.id}`}
                      className={`text-left p-6 border transition ${
                        serviceId === svc.id ? "border-[#F59E0B] bg-[#F59E0B]/5" : "border-white/10 hover:border-white/30 bg-[#111]"
                      }`}
                    >
                      <div className="flex items-start justify-between gap-4 mb-3">
                        <div className="font-display font-bold text-xl">{svc.name}</div>
                        {serviceId === svc.id && (
                          <div className="h-6 w-6 bg-[#F59E0B] grid place-items-center rounded-full shrink-0">
                            <Check size={14} weight="bold" className="text-black" />
                          </div>
                        )}
                      </div>
                      <div className="text-sm text-white/60 mb-4">{svc.description}</div>
                      <div className="flex items-center justify-between text-sm font-mono-ga">
                        <span className="text-white/60 flex items-center gap-1.5"><Clock size={14} /> {svc.durationMin} min</span>
                        <span className="text-[#F59E0B] font-bold">fr. {svc.priceFrom} kr</span>
                      </div>
                    </button>
                  ))}
                </div>
              </motion.div>
            )}

            {step === 1 && (
              <motion.div key="s1" initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -12 }} transition={{ duration: 0.3 }}>
                <div className="mb-8 p-5 border border-white/10 bg-[#111] flex items-center gap-4">
                  <div className="h-10 w-10 bg-[#F59E0B] grid place-items-center">
                    <Check size={16} weight="bold" className="text-black" />
                  </div>
                  <div>
                    <div className="eyebrow text-white/50">Vald tjänst</div>
                    <div className="font-display font-bold text-lg">{service?.name} <span className="text-white/40 font-normal text-sm">· {service?.durationMin} min · fr. {service?.priceFrom} kr</span></div>
                  </div>
                </div>

                <div className="eyebrow text-[#F59E0B] mb-4">Välj datum</div>
                <div className="grid grid-cols-3 sm:grid-cols-5 lg:grid-cols-7 gap-2 mb-10" data-testid="date-picker">
                  {days.map((d) => {
                    const iso = fmtDate(d);
                    const isSel = date === iso;
                    const weekday = d.toLocaleDateString("sv-SE", { weekday: "short" });
                    return (
                      <button
                        key={iso}
                        onClick={() => setDate(iso)}
                        data-testid={`date-${iso}`}
                        className={`p-3 border text-left transition ${
                          isSel ? "bg-[#F59E0B] text-black border-[#F59E0B]" : "border-white/10 hover:border-white/30 bg-[#111]"
                        }`}
                      >
                        <div className="eyebrow text-[10px]">{weekday}</div>
                        <div className="font-display font-black text-2xl mt-1">{d.getDate()}</div>
                        <div className="text-[10px] font-mono-ga mt-1 opacity-70">{d.toLocaleDateString("sv-SE", { month: "short" })}</div>
                      </button>
                    );
                  })}
                </div>

                {date && (
                  <>
                    <div className="eyebrow text-[#F59E0B] mb-4">Välj tid</div>
                    <div className="grid grid-cols-3 sm:grid-cols-5 lg:grid-cols-6 gap-2" data-testid="time-picker">
                      {TIME_SLOTS.map((t) => {
                        const isSel = time === t;
                        const unavailable = (t === "09:00" || t === "10:00") && date === fmtDate(new Date());
                        return (
                          <button
                            key={t}
                            onClick={() => !unavailable && setTime(t)}
                            disabled={unavailable}
                            data-testid={`time-${t}`}
                            className={`p-3 border text-center font-mono-ga transition ${
                              unavailable
                                ? "border-white/5 text-white/20 line-through cursor-not-allowed"
                                : isSel
                                  ? "bg-[#F59E0B] text-black border-[#F59E0B] font-bold"
                                  : "border-white/10 hover:border-white/30 bg-[#111]"
                            }`}
                          >
                            {t}
                          </button>
                        );
                      })}
                    </div>
                  </>
                )}
              </motion.div>
            )}

            {step === 2 && (
              <motion.div key="s2" initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -12 }} transition={{ duration: 0.3 }}>
                <div className="grid md:grid-cols-2 gap-10">
                  <div>
                    <div className="flex items-center gap-3 mb-6">
                      <User size={20} weight="duotone" className="text-[#F59E0B]" />
                      <h3 className="font-display font-bold text-xl">Dina uppgifter</h3>
                    </div>
                    <div className="space-y-4">
                      <Field label="För- och efternamn" value={form.name} onChange={(v) => setForm({ ...form, name: v })} testId="field-name" />
                      <Field label="Telefonnummer" value={form.phone} onChange={(v) => setForm({ ...form, phone: v })} testId="field-phone" />
                      <Field label="E-post" type="email" value={form.email} onChange={(v) => setForm({ ...form, email: v })} testId="field-email" />
                    </div>
                  </div>
                  <div>
                    <div className="flex items-center gap-3 mb-6">
                      <Car size={20} weight="duotone" className="text-[#F59E0B]" />
                      <h3 className="font-display font-bold text-xl">Fordon</h3>
                    </div>
                    <div className="space-y-4">
                      <Field label="Registreringsnummer" value={form.regnr} onChange={(v) => setForm({ ...form, regnr: v.toUpperCase() })} testId="field-regnr" />
                      <div className="grid grid-cols-2 gap-4">
                        <Field label="Bilmärke" value={form.brand} onChange={(v) => setForm({ ...form, brand: v })} testId="field-brand" />
                        <Field label="Modell" value={form.model} onChange={(v) => setForm({ ...form, model: v })} testId="field-model" />
                      </div>
                      <Field label="Meddelande (valfritt)" value={form.message} onChange={(v) => setForm({ ...form, message: v })} textarea testId="field-message" />
                    </div>
                  </div>
                </div>
              </motion.div>
            )}

            {step === 3 && confirmed && (
              <motion.div key="s3" initial={{ opacity: 0, scale: 0.96 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 0.4 }}>
                <div className="max-w-2xl mx-auto text-center">
                  <div className="inline-grid place-items-center h-20 w-20 bg-[#F59E0B] rounded-full mb-8">
                    <Check size={40} weight="bold" className="text-black" />
                  </div>
                  <h2 className="font-display font-black text-4xl md:text-5xl tracking-[-0.03em] mb-4">Bokning mottagen</h2>
                  <p className="text-white/60 mb-10">Vi har skickat en bekräftelse till <span className="text-white">{confirmed.email}</span> och ett SMS till <span className="text-white">{confirmed.phone}</span>.</p>

                  <div className="border border-white/10 bg-[#111] p-8 text-left mb-10" data-testid="booking-summary">
                    <div className="flex items-center justify-between pb-5 border-b border-white/10 mb-5">
                      <div>
                        <div className="eyebrow text-white/50">Bokningsnummer</div>
                        <div className="font-mono-ga text-[#F59E0B] text-lg">{confirmed.bookingNumber}</div>
                      </div>
                      <div className="text-right">
                        <div className="eyebrow text-white/50">Datum & tid</div>
                        <div className="font-mono-ga text-lg">{confirmed.date} · {confirmed.time}</div>
                      </div>
                    </div>
                    <Summary label="Tjänst" value={`${confirmed.service.name} (fr. ${confirmed.service.priceFrom} kr)`} />
                    <Summary label="Kund" value={confirmed.name} />
                    <Summary label="Kontakt" value={`${confirmed.phone} · ${confirmed.email}`} />
                    <Summary label="Fordon" value={`${confirmed.regnr}${confirmed.brand ? ` · ${confirmed.brand} ${confirmed.model}` : ""}`} />
                    {confirmed.message && <Summary label="Meddelande" value={confirmed.message} />}
                  </div>

                  <div className="flex flex-wrap gap-4 justify-center">
                    <button onClick={() => navigate("/")} className="btn-ghost-dark px-6 py-3 text-sm" data-testid="confirm-home-btn">Till startsidan</button>
                    <button
                      onClick={() => { setStep(0); setServiceId(null); setDate(null); setTime(null); setForm({ name:"",phone:"",email:"",regnr:"",brand:"",model:"",message:"" }); setConfirmed(null); }}
                      className="btn-gold px-6 py-3 text-sm"
                      data-testid="new-booking-btn"
                    >
                      Skapa ny bokning
                    </button>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {step < 3 && (
            <div className="mt-12 flex items-center justify-between pt-8 border-t border-white/10">
              <button
                onClick={prev}
                disabled={step === 0}
                data-testid="step-prev"
                className="btn-ghost-dark px-6 py-3 text-sm flex items-center gap-2 disabled:opacity-30 disabled:cursor-not-allowed"
              >
                <ArrowLeft size={14} weight="bold" /> Tillbaka
              </button>
              {step < 2 ? (
                <button
                  onClick={next}
                  disabled={!canNext()}
                  data-testid="step-next"
                  className="btn-gold px-8 py-3 text-sm flex items-center gap-2 disabled:opacity-30 disabled:cursor-not-allowed"
                >
                  Nästa <ArrowRight size={14} weight="bold" />
                </button>
              ) : (
                <button onClick={submit} disabled={!canNext()} data-testid="booking-submit" className="btn-gold px-8 py-3 text-sm flex items-center gap-2 disabled:opacity-30">
                  Bekräfta bokning <Check size={14} weight="bold" />
                </button>
              )}
            </div>
          )}
        </div>
      </section>
    </div>
  );
};

const Field = ({ label, value, onChange, type = "text", textarea, testId }) => (
  <label className="block">
    <span className="eyebrow text-white/50 mb-2 block">{label}</span>
    {textarea ? (
      <textarea
        rows={3}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        data-testid={testId}
        className="w-full bg-black/50 border border-white/15 focus:border-[#F59E0B] outline-none text-white px-4 py-3 resize-none transition"
      />
    ) : (
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        data-testid={testId}
        className="w-full bg-black/50 border border-white/15 focus:border-[#F59E0B] outline-none text-white px-4 py-3 transition"
      />
    )}
  </label>
);

const Summary = ({ label, value }) => (
  <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between py-2 gap-1">
    <span className="eyebrow text-white/50">{label}</span>
    <span className="text-white text-sm font-medium">{value}</span>
  </div>
);

export default Booking;
