import React from "react";
import { Link } from "react-router-dom";
import { SERVICES, CATEGORY_LABEL, CATEGORIES } from "@/mock/data";
import { ArrowRight, Clock, CurrencyEur } from "@phosphor-icons/react";

const ServicesPublic = () => {
  return (
    <div className="bg-[#0A0A0A] text-white" data-testid="services-page">
      <section className="relative pt-28 pb-16 border-b border-white/10">
        <div className="max-w-[1400px] mx-auto px-6 md:px-12">
          <div className="flex items-center gap-4 mb-8">
            <div className="amber-divider" />
            <span className="eyebrow text-[#F59E0B]">Tjänster & priser</span>
          </div>
          <h1 className="font-display font-black text-5xl md:text-6xl lg:text-7xl tracking-[-0.04em] max-w-4xl leading-[0.95] mb-6">
            Allt ditt fordon
            <br />
            <span className="text-white/40">behöver — i detalj.</span>
          </h1>
          <p className="text-white/60 max-w-xl text-base leading-relaxed">
            Transparenta frånpriser. Slutpriset bekräftas alltid innan arbetet påbörjas.
          </p>
        </div>
      </section>

      {CATEGORIES.map((cat) => {
        const catServices = SERVICES.filter((s) => s.category === cat.key);
        if (catServices.length === 0) return null;
        return (
          <section key={cat.key} className="py-20 border-b border-white/10" data-testid={`services-section-${cat.key}`}>
            <div className="max-w-[1400px] mx-auto px-6 md:px-12">
              <div className="grid md:grid-cols-[1fr_2fr] gap-10">
                <div>
                  <div className="eyebrow text-[#F59E0B] mb-3">{cat.subtitle}</div>
                  <h2 className="font-display font-black text-3xl md:text-4xl tracking-tight mb-4">{cat.title}</h2>
                  <p className="text-white/60 text-sm leading-relaxed">{cat.blurb}</p>
                </div>
                <div className="divide-y divide-white/10">
                  {catServices.map((svc) => (
                    <div key={svc.id} className="py-5 flex flex-col md:flex-row md:items-center gap-4 group">
                      <div className="flex-1">
                        <div className="font-display font-bold text-lg">{svc.name}</div>
                        <div className="text-white/50 text-sm mt-1">{svc.description}</div>
                      </div>
                      <div className="flex items-center gap-6 text-sm font-mono-ga text-white/70">
                        <span className="flex items-center gap-1.5"><Clock size={14} /> {svc.durationMin} min</span>
                        <span className="text-white font-bold text-base">fr. {svc.priceFrom} kr</span>
                        <Link
                          to="/boka"
                          state={{ serviceId: svc.id }}
                          className="btn-gold px-4 py-2 text-xs flex items-center gap-1.5"
                          data-testid={`service-book-${svc.id}`}
                        >
                          Boka <ArrowRight size={12} weight="bold" />
                        </Link>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </section>
        );
      })}

      <section className="py-20">
        <div className="max-w-[1400px] mx-auto px-6 md:px-12 text-center">
          <p className="text-white/60 mb-6">Hittar du inte tjänsten du söker?</p>
          <Link to="/kontakt" className="btn-ghost-dark px-8 py-3 text-sm inline-block">Kontakta oss</Link>
        </div>
      </section>
    </div>
  );
};

export default ServicesPublic;
