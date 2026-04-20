import React from "react";
import { SERVICES, CATEGORY_LABEL } from "@/mock/data";
import { Plus, PencilSimple, Clock } from "@phosphor-icons/react";

const ServicesAdmin = () => {
  const grouped = SERVICES.reduce((acc, s) => {
    (acc[s.category] = acc[s.category] || []).push(s);
    return acc;
  }, {});

  return (
    <div className="p-6 md:p-8" data-testid="services-admin-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Katalog</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Tjänster</h1>
        </div>
        <button className="bg-slate-900 hover:bg-black text-white px-4 py-2.5 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="new-service-btn">
          <Plus size={16} weight="bold" /> Ny tjänst
        </button>
      </div>

      <div className="space-y-6">
        {Object.entries(grouped).map(([cat, list]) => (
          <div key={cat} className="bg-white border border-slate-200 rounded-sm" data-testid={`services-group-${cat}`}>
            <div className="px-5 py-4 border-b border-slate-100 flex items-center justify-between">
              <h3 className="font-display font-bold text-slate-900">{CATEGORY_LABEL[cat]}</h3>
              <span className="text-xs text-slate-500 font-mono-ga">{list.length} tjänster</span>
            </div>
            <div className="divide-y divide-slate-100">
              {list.map((s) => (
                <div key={s.id} className="px-5 py-4 flex items-center gap-4 hover:bg-slate-50 transition" data-testid={`service-row-${s.id}`}>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-slate-900">{s.name}</div>
                    <div className="text-xs text-slate-500 mt-0.5">{s.description}</div>
                  </div>
                  <div className="flex items-center gap-1.5 text-xs text-slate-500 font-mono-ga w-20">
                    <Clock size={12} /> {s.durationMin} min
                  </div>
                  <div className="font-mono-ga tabular-nums text-slate-900 font-semibold w-28 text-right">fr. {s.priceFrom} kr</div>
                  <div className="w-20 text-right">
                    <span className="inline-block px-2 py-0.5 bg-emerald-100 text-emerald-800 text-[10px] tracking-wider uppercase font-semibold rounded-sm">Aktiv</span>
                  </div>
                  <button className="p-2 text-slate-400 hover:text-slate-900" aria-label="edit" data-testid={`edit-service-${s.id}`}>
                    <PencilSimple size={16} />
                  </button>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ServicesAdmin;
