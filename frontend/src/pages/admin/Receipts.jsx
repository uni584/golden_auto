import React, { useState } from "react";
import { RECEIPTS } from "@/mock/data";
import { Printer, Download, Eye, Check, X } from "@phosphor-icons/react";
import { toast } from "sonner";

const Receipts = () => {
  const [selected, setSelected] = useState(RECEIPTS[0]);

  return (
    <div className="p-6 md:p-8" data-testid="receipts-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Drift</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Kvitton</h1>
        </div>
      </div>

      <div className="grid lg:grid-cols-[400px_1fr] gap-6">
        <div className="bg-white border border-slate-200 rounded-sm overflow-hidden">
          <div className="px-4 py-3 border-b border-slate-100 eyebrow text-slate-400">Utfärdade ({RECEIPTS.length})</div>
          <div className="divide-y divide-slate-100">
            {RECEIPTS.map((r) => {
              const isSel = selected?.id === r.id;
              return (
                <button
                  key={r.id}
                  onClick={() => setSelected(r)}
                  data-testid={`receipt-list-${r.id}`}
                  className={`w-full text-left px-4 py-4 transition ${isSel ? "bg-slate-900 text-white" : "hover:bg-slate-50"}`}
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className={`font-mono-ga text-xs ${isSel ? "text-[#F59E0B]" : "text-slate-500"}`}>{r.number}</span>
                    {r.paid ? (
                      <span className={`flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider ${isSel ? "text-emerald-300" : "text-emerald-600"}`}>
                        <Check size={12} weight="bold" /> Betald
                      </span>
                    ) : (
                      <span className={`flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider ${isSel ? "text-rose-300" : "text-rose-600"}`}>
                        <X size={12} weight="bold" /> Obetald
                      </span>
                    )}
                  </div>
                  <div className={`font-semibold ${isSel ? "text-white" : "text-slate-900"}`}>{r.customer}</div>
                  <div className="flex items-center justify-between mt-2">
                    <span className={`font-mono-ga text-xs ${isSel ? "text-white/60" : "text-slate-500"}`}>{r.regnr} · {r.created}</span>
                    <span className={`font-mono-ga tabular-nums font-bold ${isSel ? "text-white" : "text-slate-900"}`}>{r.total} kr</span>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Receipt preview (looks like real receipt) */}
        {selected && (
          <div className="space-y-3">
            <div className="flex items-center justify-end gap-2">
              <button onClick={() => toast.success("Öppnar utskriftsvy...")} className="bg-white border border-slate-200 hover:bg-slate-50 px-4 py-2 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="receipt-print">
                <Printer size={16} /> Skriv ut
              </button>
              <button onClick={() => toast.success("PDF nedladdad")} className="bg-slate-900 hover:bg-black text-white px-4 py-2 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="receipt-pdf">
                <Download size={16} /> Ladda ner PDF
              </button>
            </div>

            <div className="bg-white border border-slate-200 rounded-sm overflow-hidden shadow-sm" data-testid="receipt-preview">
              {/* Receipt header - dark */}
              <div className="bg-slate-900 text-white p-8 flex items-center justify-between">
                <div>
                  <div className="font-display font-black text-3xl tracking-tight text-[#F59E0B]">GOLDEN AUTO</div>
                  <div className="text-white/60 text-xs mt-1">Bilverkstad · Däckhotell · Rekond</div>
                </div>
                <div className="text-right">
                  <div className="eyebrow text-white/60 mb-1">Kvitto</div>
                  <div className="font-mono-ga">{selected.number}</div>
                </div>
              </div>

              <div className="p-8">
                <div className="grid md:grid-cols-2 gap-6 pb-6 border-b border-slate-200">
                  <div>
                    <div className="eyebrow text-slate-400 mb-2">Kund</div>
                    <div className="font-semibold text-slate-900">{selected.customer}</div>
                  </div>
                  <div className="md:text-right">
                    <div className="eyebrow text-slate-400 mb-2">Fordon & Datum</div>
                    <div className="font-mono-ga text-slate-900 font-bold">{selected.regnr}</div>
                    <div className="text-sm text-slate-500 font-mono-ga mt-0.5">{selected.created}</div>
                  </div>
                </div>

                {/* Items */}
                <table className="w-full my-6">
                  <thead className="border-b border-slate-200">
                    <tr className="text-left text-xs uppercase tracking-wider text-slate-500">
                      <th className="py-3 font-semibold">Beskrivning</th>
                      <th className="py-3 font-semibold text-right">Antal</th>
                      <th className="py-3 font-semibold text-right">À-pris</th>
                      <th className="py-3 font-semibold text-right">Summa</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    <tr><td className="py-3 text-slate-800">Hjulskifte utfört</td><td className="text-right font-mono-ga">1</td><td className="text-right font-mono-ga">495.00</td><td className="text-right font-mono-ga font-bold">495.00</td></tr>
                    <tr><td className="py-3 text-slate-800">Balansering 4 hjul</td><td className="text-right font-mono-ga">1</td><td className="text-right font-mono-ga">300.00</td><td className="text-right font-mono-ga font-bold">300.00</td></tr>
                  </tbody>
                </table>

                {/* Totals */}
                <div className="flex justify-end">
                  <div className="w-full md:w-72 space-y-1.5 font-mono-ga tabular-nums">
                    <div className="flex justify-between text-sm text-slate-500"><span>Netto</span><span>{(selected.total / 1.25).toFixed(2)} kr</span></div>
                    <div className="flex justify-between text-sm text-slate-500"><span>Moms 25%</span><span>{(selected.total - selected.total/1.25).toFixed(2)} kr</span></div>
                    <div className="flex justify-between pt-2 border-t border-slate-200 text-lg font-display font-black text-slate-900">
                      <span>Att betala</span><span>{selected.total.toFixed(2)} kr</span>
                    </div>
                  </div>
                </div>

                {/* Status badge */}
                <div className="mt-8 pt-6 border-t border-slate-200 flex items-center justify-between">
                  <div>
                    {selected.paid ? (
                      <span className="inline-flex items-center gap-2 px-3 py-1.5 bg-emerald-100 text-emerald-800 text-xs font-bold uppercase tracking-wider rounded-sm"><Check size={14} weight="bold" /> Betald</span>
                    ) : (
                      <span className="inline-flex items-center gap-2 px-3 py-1.5 bg-rose-100 text-rose-800 text-xs font-bold uppercase tracking-wider rounded-sm"><X size={14} weight="bold" /> Obetald</span>
                    )}
                  </div>
                  <div className="text-xs text-slate-400 font-mono-ga">Golden Auto AB · Org.nr 556789-1234</div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default Receipts;
