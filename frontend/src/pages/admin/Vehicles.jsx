import React, { useState } from "react";
import { VEHICLES } from "@/mock/data";
import { MagnifyingGlass, Plus } from "@phosphor-icons/react";

const Vehicles = () => {
  const [q, setQ] = useState("");
  const list = VEHICLES.filter((v) =>
    !q || v.regnr.toLowerCase().includes(q.toLowerCase()) ||
    v.brand.toLowerCase().includes(q.toLowerCase()) ||
    v.customer.toLowerCase().includes(q.toLowerCase())
  );

  return (
    <div className="p-6 md:p-8" data-testid="vehicles-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Register</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Fordon</h1>
        </div>
        <button className="bg-slate-900 hover:bg-black text-white px-4 py-2.5 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="new-vehicle-btn">
          <Plus size={16} weight="bold" /> Nytt fordon
        </button>
      </div>

      <div className="bg-white border border-slate-200 rounded-sm">
        <div className="p-4 border-b border-slate-100">
          <div className="relative max-w-md">
            <MagnifyingGlass size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Sök reg.nr, märke, kund..."
              data-testid="vehicles-search"
              className="w-full bg-slate-50 border border-slate-200 focus:border-slate-400 focus:bg-white outline-none pl-9 pr-4 py-2 text-sm rounded-sm"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase tracking-wider text-slate-500">
              <tr>
                <th className="px-5 py-3 text-left font-semibold">Reg.nr</th>
                <th className="px-5 py-3 text-left font-semibold">Fordon</th>
                <th className="px-5 py-3 text-left font-semibold">År</th>
                <th className="px-5 py-3 text-left font-semibold">Ägare</th>
                <th className="px-5 py-3 text-left font-semibold">Däck</th>
                <th className="px-5 py-3 text-left font-semibold">Senaste service</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {list.map((v) => (
                <tr key={v.id} className="hover:bg-slate-50 transition" data-testid={`vehicle-row-${v.id}`}>
                  <td className="px-5 py-4">
                    <span className="inline-block px-2 py-1 bg-slate-900 text-white font-mono-ga font-bold text-xs tracking-wider rounded-sm">{v.regnr}</span>
                  </td>
                  <td className="px-5 py-4 font-semibold text-slate-900">{v.brand} {v.model}</td>
                  <td className="px-5 py-4 font-mono-ga tabular-nums text-slate-600">{v.year}</td>
                  <td className="px-5 py-4 text-slate-700">{v.customer}</td>
                  <td className="px-5 py-4 text-slate-500 text-xs">{v.tires}</td>
                  <td className="px-5 py-4 font-mono-ga text-slate-500">{v.lastService}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {list.length === 0 && <div className="p-12 text-center text-slate-400 text-sm">Inga fordon hittades.</div>}
        </div>
      </div>
    </div>
  );
};

export default Vehicles;
