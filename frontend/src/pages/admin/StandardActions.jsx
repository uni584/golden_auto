import React, { useState } from "react";
import { STANDARD_ACTIONS, CATEGORY_LABEL } from "@/mock/data";
import { Plus, PencilSimple, Trash } from "@phosphor-icons/react";

const StandardActions = () => {
  const [cat, setCat] = useState("verkstad");
  const list = STANDARD_ACTIONS.filter((a) => a.category === cat);

  return (
    <div className="p-6 md:p-8" data-testid="standard-actions-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Katalog</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Standardåtgärder</h1>
          <p className="text-sm text-slate-500 mt-2 max-w-xl">Hantera biblioteket av fördefinierade åtgärder som används i arbetsorder och kvitton.</p>
        </div>
        <button className="bg-slate-900 hover:bg-black text-white px-4 py-2.5 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="new-action-btn">
          <Plus size={16} weight="bold" /> Ny åtgärd
        </button>
      </div>

      <div className="flex flex-wrap gap-2 mb-6">
        {Object.keys(CATEGORY_LABEL).map((k) => (
          <button
            key={k}
            onClick={() => setCat(k)}
            data-testid={`actions-tab-${k}`}
            className={`px-4 py-2 text-sm font-semibold border transition rounded-sm ${
              cat === k
                ? "bg-slate-900 text-white border-slate-900"
                : "bg-white text-slate-600 border-slate-200 hover:border-slate-400"
            }`}
          >
            {CATEGORY_LABEL[k]}
            <span className="ml-2 text-xs opacity-60">{STANDARD_ACTIONS.filter(a=>a.category===k).length}</span>
          </button>
        ))}
      </div>

      <div className="bg-white border border-slate-200 rounded-sm">
        <div className="divide-y divide-slate-100">
          {list.map((a) => (
            <div key={a.id} className="px-5 py-4 flex items-center gap-4 hover:bg-slate-50 transition" data-testid={`action-row-${a.id}`}>
              <div className="h-8 w-8 bg-slate-100 grid place-items-center rounded-sm text-slate-600 font-display font-bold text-sm">
                {a.name[0]}
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-semibold text-slate-900">{a.name}</div>
                <div className="text-xs text-slate-500 mt-0.5">Kategori: {CATEGORY_LABEL[a.category]}</div>
              </div>
              <div className="font-mono-ga tabular-nums text-slate-900 font-semibold">
                {a.price > 0 ? `${a.price} kr` : <span className="text-slate-400">Gratis</span>}
              </div>
              <div className="flex gap-1">
                <button className="p-2 text-slate-400 hover:text-slate-900" aria-label="edit" data-testid={`edit-action-${a.id}`}>
                  <PencilSimple size={16} />
                </button>
                <button className="p-2 text-slate-300 hover:text-red-600" aria-label="delete">
                  <Trash size={16} />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default StandardActions;
