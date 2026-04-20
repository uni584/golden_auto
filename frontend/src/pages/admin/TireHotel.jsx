import React, { useState, useMemo } from "react";
import { TIRE_HOTEL } from "@/mock/data";
import { MagnifyingGlass, Plus, Snowflake, Sun, ArrowCircleUp, Printer, Warehouse, Package } from "@phosphor-icons/react";
import { toast } from "sonner";

const SEASON_META = {
  winter: { label: "Vinter", Icon: Snowflake, color: "bg-sky-100 text-sky-800 border-sky-200" },
  summer: { label: "Sommar", Icon: Sun, color: "bg-amber-100 text-amber-900 border-amber-300" },
};

const TireHotel = () => {
  const [q, setQ] = useState("");
  const [seasonFilter, setSeasonFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("stored");

  const filtered = useMemo(() => {
    return TIRE_HOTEL
      .filter((t) => statusFilter === "all" || t.status === statusFilter)
      .filter((t) => seasonFilter === "all" || t.season === seasonFilter)
      .filter((t) => !q ||
        t.customer.toLowerCase().includes(q.toLowerCase()) ||
        t.regnr.toLowerCase().includes(q.toLowerCase()) ||
        t.location.toLowerCase().includes(q.toLowerCase())
      );
  }, [q, seasonFilter, statusFilter]);

  const stats = {
    stored: TIRE_HOTEL.filter((t) => t.status === "stored").length,
    winter: TIRE_HOTEL.filter((t) => t.status === "stored" && t.season === "winter").length,
    summer: TIRE_HOTEL.filter((t) => t.status === "stored" && t.season === "summer").length,
    lowTread: TIRE_HOTEL.filter((t) => t.status === "stored" && parseFloat(t.tread) < 5).length,
  };

  // rack map: compute occupancy per rack A-D
  const racks = ["A", "B", "C", "D"];
  const rackStats = racks.map((r) => ({
    rack: r,
    total: 30,
    used: TIRE_HOTEL.filter((t) => t.rack === r && t.status === "stored").length,
  }));

  return (
    <div className="p-6 md:p-8" data-testid="tire-hotel-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Drift</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Däckhotell</h1>
          <p className="text-sm text-slate-500 mt-2">Spårning av lagrade däck per kund, fordon och plats.</p>
        </div>
        <button className="bg-slate-900 hover:bg-black text-white px-4 py-2.5 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="new-tire-hotel-btn">
          <Plus size={16} weight="bold" /> Lägg in däck
        </button>
      </div>

      {/* KPI */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <StatCard label="Lagrade totalt" value={stats.stored} Icon={Warehouse} accent="text-slate-600" testId="kpi-stored" />
        <StatCard label="Vinterdäck" value={stats.winter} Icon={Snowflake} accent="text-sky-600" testId="kpi-winter" />
        <StatCard label="Sommardäck" value={stats.summer} Icon={Sun} accent="text-[#F59E0B]" testId="kpi-summer" />
        <StatCard label="Låg profil (<5mm)" value={stats.lowTread} sub="Kontakt rekommenderas" Icon={ArrowCircleUp} accent="text-rose-600" testId="kpi-low-tread" />
      </div>

      {/* Rack occupancy */}
      <div className="bg-white border border-slate-200 rounded-sm p-5 mb-8" data-testid="rack-map">
        <div className="flex items-center justify-between mb-4">
          <div>
            <div className="eyebrow text-slate-400 mb-1">Beläggning</div>
            <h3 className="font-display font-bold text-lg text-slate-900">Rackkarta</h3>
          </div>
          <span className="text-xs font-mono-ga text-slate-500">{stats.stored} av {rackStats.reduce((s, r) => s + r.total, 0)} platser</span>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {rackStats.map((r) => {
            const pct = (r.used / r.total) * 100;
            const warn = pct > 70;
            return (
              <div key={r.rack} className="border border-slate-200 p-4 rounded-sm">
                <div className="flex items-center justify-between mb-2">
                  <div className="font-display font-black text-2xl text-slate-900">Rack {r.rack}</div>
                  <span className={`text-xs font-bold font-mono-ga ${warn ? "text-rose-600" : "text-emerald-600"}`}>{Math.round(pct)}%</span>
                </div>
                <div className="h-2 bg-slate-100 overflow-hidden rounded-sm mb-2">
                  <div className="h-full transition-all" style={{ width: `${pct}%`, backgroundColor: warn ? "#DC2626" : "#111827" }} />
                </div>
                <div className="flex items-center justify-between text-xs text-slate-500 font-mono-ga">
                  <span>{r.used} / {r.total}</span>
                  <span>{r.total - r.used} lediga</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Filters + table */}
      <div className="bg-white border border-slate-200 rounded-sm">
        <div className="flex flex-col lg:flex-row lg:items-center gap-3 p-4 border-b border-slate-100">
          <div className="relative flex-1 max-w-md">
            <MagnifyingGlass size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Sök kund, reg.nr, plats (t.ex. A-12)..."
              data-testid="tire-hotel-search"
              className="w-full bg-slate-50 border border-slate-200 focus:border-slate-400 focus:bg-white outline-none pl-9 pr-4 py-2 text-sm rounded-sm"
            />
          </div>
          <div className="flex items-center gap-2">
            {[
              { k: "all", l: "Alla" },
              { k: "winter", l: "Vinter" },
              { k: "summer", l: "Sommar" },
            ].map((f) => (
              <button
                key={f.k}
                onClick={() => setSeasonFilter(f.k)}
                data-testid={`season-${f.k}`}
                className={`px-3 py-1.5 text-xs font-semibold border transition rounded-sm ${seasonFilter === f.k ? "bg-slate-900 text-white border-slate-900" : "bg-white text-slate-600 border-slate-200"}`}
              >
                {f.l}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2">
            {[
              { k: "stored", l: "I hotell" },
              { k: "withdrawn", l: "Uthämtade" },
              { k: "all", l: "Alla" },
            ].map((f) => (
              <button
                key={f.k}
                onClick={() => setStatusFilter(f.k)}
                data-testid={`tire-status-${f.k}`}
                className={`px-3 py-1.5 text-xs font-semibold border transition rounded-sm ${statusFilter === f.k ? "bg-[#F59E0B] text-black border-[#F59E0B]" : "bg-white text-slate-600 border-slate-200"}`}
              >
                {f.l}
              </button>
            ))}
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase tracking-wider text-slate-500">
              <tr>
                <th className="px-5 py-3 text-left font-semibold">Plats</th>
                <th className="px-5 py-3 text-left font-semibold">Kund</th>
                <th className="px-5 py-3 text-left font-semibold">Fordon</th>
                <th className="px-5 py-3 text-left font-semibold">Däck</th>
                <th className="px-5 py-3 text-left font-semibold">Säsong</th>
                <th className="px-5 py-3 text-right font-semibold">Profil</th>
                <th className="px-5 py-3 text-left font-semibold">Lagrad sedan</th>
                <th className="px-5 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.map((t) => {
                const s = SEASON_META[t.season];
                const treadNum = parseFloat(t.tread);
                const low = treadNum < 5;
                return (
                  <tr key={t.id} className="hover:bg-slate-50 transition" data-testid={`tire-row-${t.id}`}>
                    <td className="px-5 py-4">
                      <span className="inline-flex items-center gap-1.5 px-2 py-1 bg-slate-900 text-[#F59E0B] font-mono-ga font-bold text-xs tracking-wider rounded-sm">
                        <Package size={12} weight="bold" /> {t.location}
                      </span>
                    </td>
                    <td className="px-5 py-4 font-semibold text-slate-900">{t.customer}</td>
                    <td className="px-5 py-4">
                      <div className="font-mono-ga text-slate-900 font-bold text-xs">{t.regnr}</div>
                      <div className="text-xs text-slate-500">{t.vehicle}</div>
                    </td>
                    <td className="px-5 py-4 text-slate-600 text-xs">{t.tires}</td>
                    <td className="px-5 py-4">
                      <span className={`status-pill ${s.color}`}>
                        <s.Icon size={11} weight="bold" /> {s.label}
                      </span>
                    </td>
                    <td className={`px-5 py-4 text-right font-mono-ga tabular-nums font-semibold ${low ? "text-rose-600" : "text-slate-900"}`}>
                      {t.tread}
                    </td>
                    <td className="px-5 py-4 text-slate-500 font-mono-ga text-xs">
                      {t.storedAt}
                      {t.withdrawnAt && <div className="text-slate-400">uth: {t.withdrawnAt}</div>}
                    </td>
                    <td className="px-5 py-4 text-right">
                      <div className="flex justify-end gap-1">
                        <button
                          onClick={() => toast.success(`Etikett utskriven för ${t.location}`)}
                          className="p-1.5 text-slate-400 hover:text-slate-900"
                          aria-label="print"
                          data-testid={`print-label-${t.id}`}
                        >
                          <Printer size={14} />
                        </button>
                        {t.status === "stored" && (
                          <button
                            onClick={() => toast.success(`${t.location} markerad som uthämtad`)}
                            className="px-2 py-1 text-xs font-bold bg-slate-900 text-white hover:bg-black rounded-sm"
                            data-testid={`withdraw-${t.id}`}
                          >
                            Hämta ut
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {filtered.length === 0 && <div className="p-12 text-center text-slate-400 text-sm">Inga däck matchar filtret.</div>}
        </div>
      </div>
    </div>
  );
};

const StatCard = ({ label, value, sub, Icon, accent, testId }) => (
  <div className="bg-white border border-slate-200 p-5 rounded-sm" data-testid={testId}>
    <div className="flex items-center justify-between mb-3">
      <div className="eyebrow text-slate-400">{label}</div>
      {Icon && <Icon size={18} weight="duotone" className={accent || "text-slate-400"} />}
    </div>
    <div className="font-display font-black text-3xl tracking-tight text-slate-900 tabular-nums">{value}</div>
    {sub && <div className="mt-2 text-xs text-slate-500">{sub}</div>}
  </div>
);

export default TireHotel;
