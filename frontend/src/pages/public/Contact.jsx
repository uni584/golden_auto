import React from "react";
import { MapPin, Phone, EnvelopeSimple, Clock } from "@phosphor-icons/react";
import { toast } from "sonner";

const Contact = () => {
  const submit = (e) => {
    e.preventDefault();
    toast.success("Tack! Vi återkommer inom kort.");
    e.target.reset();
  };

  return (
    <div className="bg-[#0A0A0A] text-white min-h-screen" data-testid="contact-page">
      <section className="pt-28 pb-16 border-b border-white/10">
        <div className="max-w-[1400px] mx-auto px-6 md:px-12">
          <div className="flex items-center gap-4 mb-8">
            <div className="amber-divider" />
            <span className="eyebrow text-[#F59E0B]">Kontakt</span>
          </div>
          <h1 className="font-display font-black text-5xl md:text-6xl lg:text-7xl tracking-[-0.04em] leading-[0.95]">
            Hör av dig.
            <br />
            <span className="text-white/40">Vi svarar snabbt.</span>
          </h1>
        </div>
      </section>

      <section className="py-20">
        <div className="max-w-[1400px] mx-auto px-6 md:px-12 grid lg:grid-cols-2 gap-16">
          <div>
            <div className="space-y-8">
              {[
                { Icon: MapPin, label: "Besöksadress", value: "Industrigatan 14, 212 34 Malmö" },
                { Icon: Phone, label: "Telefon", value: "040-123 45 67" },
                { Icon: EnvelopeSimple, label: "E-post", value: "info@goldenauto.se" },
                { Icon: Clock, label: "Öppettider", value: "Mån–Fre 07–17 · Lör 09–14" },
              ].map(({ Icon, label, value }) => (
                <div key={label} className="flex gap-5 items-start">
                  <div className="h-12 w-12 border border-white/15 grid place-items-center shrink-0">
                    <Icon size={20} weight="duotone" className="text-[#F59E0B]" />
                  </div>
                  <div>
                    <div className="eyebrow text-white/50 mb-1">{label}</div>
                    <div className="text-lg">{value}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <form onSubmit={submit} className="bg-[#111] border border-white/10 p-8 md:p-10 space-y-5" data-testid="contact-form">
            <div>
              <label className="eyebrow text-white/50 block mb-2">Namn</label>
              <input required className="w-full bg-black/50 border border-white/15 focus:border-[#F59E0B] outline-none px-4 py-3 text-white transition" data-testid="contact-name" />
            </div>
            <div className="grid md:grid-cols-2 gap-5">
              <div>
                <label className="eyebrow text-white/50 block mb-2">E-post</label>
                <input required type="email" className="w-full bg-black/50 border border-white/15 focus:border-[#F59E0B] outline-none px-4 py-3 text-white transition" data-testid="contact-email" />
              </div>
              <div>
                <label className="eyebrow text-white/50 block mb-2">Telefon</label>
                <input className="w-full bg-black/50 border border-white/15 focus:border-[#F59E0B] outline-none px-4 py-3 text-white transition" data-testid="contact-phone" />
              </div>
            </div>
            <div>
              <label className="eyebrow text-white/50 block mb-2">Meddelande</label>
              <textarea required rows={5} className="w-full bg-black/50 border border-white/15 focus:border-[#F59E0B] outline-none px-4 py-3 text-white resize-none transition" data-testid="contact-message" />
            </div>
            <button type="submit" className="btn-gold w-full py-4 text-sm" data-testid="contact-submit">Skicka meddelande</button>
          </form>
        </div>
      </section>
    </div>
  );
};

export default Contact;
