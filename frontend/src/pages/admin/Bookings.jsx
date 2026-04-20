import React, { useState, useMemo } from "react";
import { BOOKINGS, STATUS_LABELS } from "@/mock/data";
import { MagnifyingGlass, Funnel, Plus, DotsThreeVertical } from "@phosphor-icons/react";

const STATUSES = ["all", "new", "confirmed", "checked_in", "in_progress", "done", "delivered", "cancelled"];

const Bookings = () => {
  const [filter, setFilter] = useState("all");
  const [q, setQ] = useState("");

  const filtered = useMemo(() => {
    return BOOKINGS.filter((b) => (filter === "all" || b.status === filter))
      .filter((b) =>
        !q ||
        b.customerName.toLowerCase().includes(q.toLowerCase()) ||
        b.regnr.toLowerCase().includes(q.toLowerCase()) ||
        b.number.toLowerCase().includes(q.toLowerCase())
      );
  }, [filter, q]);

  return (
    <div className="p-6 md:p-8" data-testid="bookings-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Drift</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Bokningar</h1>
        </div>
        <button className="bg-slate-900 hover:bg-black text-white px-4 py-2.5 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="new-booking-btn">
          <Plus size={16} weight="bold" /> Ny bokning
        </button>
      </div>

      {/* Filters */}
      <div className="bg-white border border-slate-200 rounded-sm mb-6">
        <div className="flex flex-col lg:flex-row lg:items-center gap-3 p-4 border-b border-slate-100">
          <div className="relative flex-1 max-w-md">
            <MagnifyingGlass size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Sök kund, reg.nr, bokningsnr..."
              data-testid="bookings-search"
              className="w-full bg-slate-50 border border-slate-200 focus:border-slate-400 focus:bg-white outline-none pl-9 pr-4 py-2 text-sm text-slate-900 rounded-sm"
            />
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Funnel size={14} className="text-slate-400" />
            {STATUSES.map((s) => {
              const active = filter === s;
              const label = s === "all" ? "Alla" : STATUS_LABELS[s]?.label || s;
              return (
                <button
                  key={s}
                  onClick={() => setFilter(s)}
                  data-testid={`filter-${s}`}
                  className={`px-3 py-1.5 text-xs font-semibold border transition ${
                    active ? "bg-slate-900 text-white border-slate-900" : "bg-white text-slate-600 border-slate-200 hover:border-slate-400"
                  }`}
                >
                  {label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase tracking-wider text-slate-500">
              <tr>
                <Th>Tid</Th>
                <Th>Bokning</Th>
                <Th>Kund</Th>
                <Th>Fordon</Th>
                <Th>Tjänst</Th>
                <Th>Status</Th>
                <Th align="right">Pris</Th>
                <Th />
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.map((b) => {
                const st = STATUS_LABELS[b.status];
                return (
                  <tr key={b.id} className="hover:bg-slate-50 transition" data-testid={`booking-row-${b.id}`}>
                    <Td>
                      <div className="font-mono-ga text-slate-900 font-bold">{b.time}</div>
                      <div className="font-mono-ga text-xs text-slate-500">{b.date}</div>
                    </Td>
                    <Td><span className="font-mono-ga text-xs text-slate-700">{b.number}</span></Td>
                    <Td>
                      <div className="font-semibold text-slate-900">{b.customerName}</div>
                      <div className="text-xs text-slate-500">{b.phone}</div>
                    </Td>
                    <Td>
                      <div className="font-mono-ga text-slate-900 font-bold">{b.regnr}</div>
                      <div className="text-xs text-slate-500">{b.brand} {b.model}</div>
                    </Td>
                    <Td>{b.service}</Td>
                    <Td><span className={`status-pill ${st.color}`}>{st.label}</span></Td>
                    <Td align="right"><span className="font-mono-ga tabular-nums text-slate-900">{b.price} kr</span></Td>
                    <Td><button className="p-1.5 text-slate-400 hover:text-slate-900" aria-label="actions"><DotsThreeVertical size={16} /></button></Td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {filtered.length === 0 && <div className="p-12 text-center text-slate-400 text-sm">Inga bokningar matchar filtret.</div>}
        </div>
      </div>
    </div>
  );
};

const Th = ({ children, align = "left" }) => (
  <th className={`px-5 py-3 font-semibold text-${align}`}>{children}</th>
);
const Td = ({ children, align = "left" }) => (
  <td className={`px-5 py-4 text-${align} align-middle`}>{children}</td>
);

export default Bookings;
