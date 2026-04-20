import React, { useState } from "react";
import { WORK_ORDERS, STANDARD_ACTIONS, STATUS_LABELS, CATEGORY_LABEL } from "@/mock/data";
import { Plus, Check, Trash, Printer, Receipt as ReceiptIcon } from "@phosphor-icons/react";
import { toast } from "sonner";

const WorkOrders = () => {
  const [selected, setSelected] = useState(WORK_ORDERS[0]);
  const [items, setItems] = useState([
    { id: "i1", action: "Hjulskifte utfört", qty: 1, price: 495, vat: 25 },
    { id: "i2", action: "Balansering utförd", qty: 1, price: 300, vat: 25 },
  ]);
  const [cat, setCat] = useState("verkstad");

  const addAction = (a) => {
    setItems([...items, { id: `i${Date.now()}`, action: a.name, qty: 1, price: a.price, vat: 25 }]);
    toast.success(`Lade till: ${a.name}`);
  };

  const subtotal = items.reduce((s, i) => s + i.qty * i.price, 0);
  const vat = items.reduce((s, i) => s + i.qty * i.price * (i.vat / 100), 0);
  const total = subtotal + vat;

  return (
    <div className="p-6 md:p-8" data-testid="workorders-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Drift</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Arbetsorder</h1>
        </div>
        <button className="bg-slate-900 hover:bg-black text-white px-4 py-2.5 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="new-wo-btn">
          <Plus size={16} weight="bold" /> Ny arbetsorder
        </button>
      </div>

      <div className="grid lg:grid-cols-[320px_1fr] gap-6">
        {/* List */}
        <div className="bg-white border border-slate-200 rounded-sm overflow-hidden">
          <div className="px-4 py-3 border-b border-slate-100 eyebrow text-slate-400">Pågående & senaste ({WORK_ORDERS.length})</div>
          <div className="divide-y divide-slate-100">
            {WORK_ORDERS.map((w) => {
              const st = STATUS_LABELS[w.status];
              const isSel = selected?.id === w.id;
              return (
                <button
                  key={w.id}
                  onClick={() => setSelected(w)}
                  data-testid={`wo-list-${w.id}`}
                  className={`w-full text-left px-4 py-4 transition ${isSel ? "bg-slate-900 text-white" : "hover:bg-slate-50"}`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className={`font-mono-ga text-xs ${isSel ? "text-[#F59E0B]" : "text-slate-500"}`}>{w.number}</span>
                    <span className={`status-pill ${isSel ? "bg-white/10 text-white border-white/20" : st.color}`}>{st.label}</span>
                  </div>
                  <div className={`font-semibold ${isSel ? "text-white" : "text-slate-900"}`}>{w.customer}</div>
                  <div className={`text-xs ${isSel ? "text-white/60" : "text-slate-500"} mt-0.5`}>{w.regnr} · {w.vehicle}</div>
                  <div className={`flex items-center justify-between mt-2 text-xs ${isSel ? "text-white/60" : "text-slate-500"}`}>
                    <span>{w.assignedTo}</span>
                    <span className="font-mono-ga tabular-nums">{w.total} kr</span>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Editor */}
        {selected && (
          <div className="bg-white border border-slate-200 rounded-sm" data-testid="wo-editor">
            <div className="flex items-start justify-between p-6 border-b border-slate-100">
              <div>
                <div className="font-mono-ga text-xs text-[#D97706] mb-2">{selected.number}</div>
                <h2 className="font-display font-black text-2xl tracking-tight text-slate-900">{selected.customer}</h2>
                <div className="text-slate-500 text-sm mt-1">
                  <span className="font-mono-ga font-bold">{selected.regnr}</span> · {selected.vehicle} · {selected.assignedTo}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button className="p-2 border border-slate-200 hover:bg-slate-50 rounded-sm" aria-label="print" data-testid="wo-print">
                  <Printer size={18} className="text-slate-600" />
                </button>
                <button className="bg-[#F59E0B] hover:bg-[#D97706] text-black font-semibold px-4 py-2 text-sm flex items-center gap-2 rounded-sm" data-testid="wo-create-receipt">
                  <ReceiptIcon size={16} weight="bold" /> Skapa kvitto
                </button>
              </div>
            </div>

            {/* Action library */}
            <div className="p-6 border-b border-slate-100">
              <div className="flex items-center justify-between mb-3">
                <div>
                  <div className="eyebrow text-slate-400 mb-1">Standardåtgärder</div>
                  <div className="text-sm text-slate-500">Välj ur biblioteket för snabb registrering</div>
                </div>
                <div className="flex gap-1 flex-wrap">
                  {Object.keys(CATEGORY_LABEL).map((k) => (
                    <button
                      key={k}
                      onClick={() => setCat(k)}
                      data-testid={`wo-cat-${k}`}
                      className={`px-3 py-1 text-xs font-semibold border transition ${cat===k ? "bg-slate-900 text-white border-slate-900" : "border-slate-200 text-slate-600 hover:border-slate-400"}`}
                    >
                      {CATEGORY_LABEL[k]}
                    </button>
                  ))}
                </div>
              </div>
              <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-2 mt-4">
                {STANDARD_ACTIONS.filter((a) => a.category === cat).map((a) => (
                  <button
                    key={a.id}
                    onClick={() => addAction(a)}
                    data-testid={`wo-add-action-${a.id}`}
                    className="text-left px-3 py-2.5 border border-slate-200 hover:border-slate-900 hover:bg-slate-50 transition text-sm flex items-center justify-between group rounded-sm"
                  >
                    <span className="text-slate-700 group-hover:text-slate-900">{a.name}</span>
                    <span className="font-mono-ga text-xs text-slate-400 tabular-nums">{a.price > 0 ? `${a.price} kr` : "—"}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Items table */}
            <div className="p-6 border-b border-slate-100">
              <div className="eyebrow text-slate-400 mb-3">Åtgärdsrader</div>
              <table className="w-full text-sm" data-testid="wo-items-table">
                <thead className="text-xs uppercase tracking-wider text-slate-400">
                  <tr>
                    <th className="text-left py-2">Beskrivning</th>
                    <th className="text-right py-2 w-20">Antal</th>
                    <th className="text-right py-2 w-28">À-pris</th>
                    <th className="text-right py-2 w-28">Summa</th>
                    <th className="w-10" />
                  </tr>
                </thead>
                <tbody>
                  {items.map((it) => (
                    <tr key={it.id} className="border-t border-slate-100">
                      <td className="py-3 text-slate-900">{it.action}</td>
                      <td className="text-right font-mono-ga tabular-nums">{it.qty}</td>
                      <td className="text-right font-mono-ga tabular-nums text-slate-600">{it.price.toFixed(2)}</td>
                      <td className="text-right font-mono-ga tabular-nums font-bold text-slate-900">{(it.qty*it.price).toFixed(2)}</td>
                      <td className="text-right">
                        <button onClick={() => setItems(items.filter(x=>x.id!==it.id))} className="text-slate-300 hover:text-red-600 p-1" aria-label="remove">
                          <Trash size={14} />
                        </button>
                      </td>
                    </tr>
                  ))}
                  {items.length === 0 && (
                    <tr><td colSpan={5} className="py-8 text-center text-slate-400 text-sm">Inga åtgärder ännu — välj från biblioteket ovan.</td></tr>
                  )}
                </tbody>
              </table>
            </div>

            {/* Totals */}
            <div className="p-6 flex flex-col md:flex-row md:items-center md:justify-between gap-4 bg-slate-50">
              <div className="flex items-center gap-2">
                <Check size={16} weight="bold" className="text-emerald-600" />
                <span className="text-sm text-slate-600">Ändringar sparas automatiskt · Senast uppdaterad {new Date().toLocaleTimeString("sv-SE", { hour: "2-digit", minute: "2-digit" })}</span>
              </div>
              <div className="text-right space-y-1 font-mono-ga tabular-nums">
                <div className="text-sm text-slate-500 flex justify-end gap-8"><span>Netto</span><span>{subtotal.toFixed(2)} kr</span></div>
                <div className="text-sm text-slate-500 flex justify-end gap-8"><span>Moms 25%</span><span>{vat.toFixed(2)} kr</span></div>
                <div className="font-display font-black text-2xl text-slate-900 flex justify-end gap-8"><span>Att betala</span><span>{total.toFixed(2)} kr</span></div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default WorkOrders;
