import React, { useState } from "react";
import { CUSTOMERS } from "@/mock/data";
import { MagnifyingGlass, Plus, CaretRight } from "@phosphor-icons/react";

const Customers = () => {
  const [q, setQ] = useState("");
  const list = CUSTOMERS.filter((c) =>
    !q || c.name.toLowerCase().includes(q.toLowerCase()) ||
    c.phone.includes(q) || c.email.toLowerCase().includes(q.toLowerCase())
  );

  return (
    <div className="p-6 md:p-8" data-testid="customers-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Register</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Kunder</h1>
        </div>
        <button className="bg-slate-900 hover:bg-black text-white px-4 py-2.5 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="new-customer-btn">
          <Plus size={16} weight="bold" /> Ny kund
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
              placeholder="Sök namn, telefon, e-post..."
              data-testid="customers-search"
              className="w-full bg-slate-50 border border-slate-200 focus:border-slate-400 focus:bg-white outline-none pl-9 pr-4 py-2 text-sm rounded-sm"
            />
          </div>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 divide-y md:divide-y-0 md:divide-x divide-slate-100 border-b border-slate-100">
          {list.map((c) => (
            <div key={c.id} className="p-5 hover:bg-slate-50 transition cursor-pointer group" data-testid={`customer-card-${c.id}`}>
              <div className="flex items-start gap-4">
                <div className="h-11 w-11 bg-slate-900 text-white grid place-items-center rounded-full font-display font-black">
                  {c.name.split(" ").map(s=>s[0]).slice(0,2).join("")}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="font-semibold text-slate-900 truncate">{c.name}</div>
                  <div className="text-xs text-slate-500 truncate">{c.email}</div>
                  <div className="text-xs text-slate-500 font-mono-ga mt-0.5">{c.phone}</div>
                </div>
                <CaretRight size={14} className="text-slate-300 group-hover:text-slate-700 transition mt-1 shrink-0" />
              </div>
              <div className="mt-4 pt-4 border-t border-slate-100 grid grid-cols-3 gap-2 text-center">
                <div>
                  <div className="font-display font-black text-slate-900 tabular-nums">{c.vehicles}</div>
                  <div className="eyebrow text-[9px] text-slate-400">Fordon</div>
                </div>
                <div>
                  <div className="font-display font-black text-slate-900 tabular-nums">{c.bookings}</div>
                  <div className="eyebrow text-[9px] text-slate-400">Bokningar</div>
                </div>
                <div>
                  <div className="font-mono-ga text-slate-900 text-xs tabular-nums">{c.lastVisit}</div>
                  <div className="eyebrow text-[9px] text-slate-400">Senast</div>
                </div>
              </div>
            </div>
          ))}
        </div>

        {list.length === 0 && <div className="p-12 text-center text-slate-400 text-sm">Inga kunder hittades.</div>}
      </div>
    </div>
  );
};

export default Customers;
