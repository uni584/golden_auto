import React from "react";
import { Link } from "react-router-dom";
import { OVERVIEW, BOOKINGS, STATUS_LABELS, CATEGORY_LABEL } from "@/mock/data";
import { ArrowRight, TrendUp, Calendar, Users as UsersIcon, Car, Receipt } from "@phosphor-icons/react";

const StatCard = ({ label, value, sub, testId, accent, Icon }) => (
  <div className="bg-white border border-slate-200 p-5 rounded-sm" data-testid={testId}>
    <div className="flex items-center justify-between mb-3">
      <div className="eyebrow text-slate-400">{label}</div>
      {Icon && <Icon size={18} weight="duotone" className={accent || "text-slate-400"} />}
    </div>
    <div className="font-display font-black text-3xl tracking-tight text-slate-900 tabular-nums">{value}</div>
    {sub && <div className="mt-2 text-xs text-slate-500">{sub}</div>}
  </div>
);

const Dashboard = () => {
  const today = BOOKINGS.filter((b) => b.date === "2026-04-20");
  const categoriesArr = Object.entries(OVERVIEW.categories).sort((a, b) => b[1] - a[1]);
  const maxCat = Math.max(...categoriesArr.map(([, v]) => v));

  return (
    <div className="p-6 md:p-8" data-testid="dashboard-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Översikt</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Dashboard</h1>
        </div>
        <Link to="/admin/bokningar" className="text-sm font-semibold text-slate-700 hover:text-slate-900 flex items-center gap-1.5">
          Alla bokningar <ArrowRight size={14} weight="bold" />
        </Link>
      </div>

      {/* KPI grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <StatCard label="Dagens bokningar" value={OVERVIEW.todayBookings} sub={`${OVERVIEW.inProgress} pågående · ${OVERVIEW.done} klara`} Icon={Calendar} accent="text-[#F59E0B]" testId="kpi-today" />
        <StatCard label="Nya bokningar" value={OVERVIEW.newBookings} sub="Ej behandlade" Icon={Calendar} accent="text-blue-500" testId="kpi-new" />
        <StatCard label="Aktiva kunder" value={OVERVIEW.totalCustomers} sub={`${OVERVIEW.totalVehicles} fordon`} Icon={UsersIcon} accent="text-slate-500" testId="kpi-customers" />
        <StatCard label="Omsättning 30d" value={`${(OVERVIEW.revenue30d/1000).toFixed(1)}k kr`} sub={`${OVERVIEW.receiptsPending} obetalda kvitton`} Icon={TrendUp} accent="text-emerald-500" testId="kpi-revenue" />
      </div>

      <div className="grid lg:grid-cols-[2fr_1fr] gap-6">
        {/* Today's bookings */}
        <div className="bg-white border border-slate-200 rounded-sm" data-testid="today-bookings-panel">
          <div className="flex items-center justify-between px-5 py-4 border-b border-slate-200">
            <div>
              <div className="eyebrow text-slate-400 mb-1">Idag</div>
              <h3 className="font-display font-bold text-lg text-slate-900">Dagens bokningar</h3>
            </div>
            <span className="font-mono-ga text-xs text-slate-500">{today.length} st</span>
          </div>
          <div className="divide-y divide-slate-100">
            {today.map((b) => {
              const st = STATUS_LABELS[b.status];
              return (
                <div key={b.id} className="px-5 py-4 flex items-center gap-4 hover:bg-slate-50 transition" data-testid={`today-booking-${b.id}`}>
                  <div className="font-mono-ga text-slate-900 font-bold w-14 text-sm">{b.time}</div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-slate-900 truncate">{b.customerName}</div>
                    <div className="text-xs text-slate-500 truncate">{b.service} · {b.regnr} {b.brand} {b.model}</div>
                  </div>
                  <span className={`status-pill ${st.color}`}>{st.label}</span>
                  <div className="font-mono-ga text-sm text-slate-700 hidden sm:block tabular-nums">{b.price} kr</div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Category breakdown */}
        <div className="bg-white border border-slate-200 rounded-sm p-5" data-testid="category-breakdown">
          <div className="eyebrow text-slate-400 mb-1">Senaste 90 dagarna</div>
          <h3 className="font-display font-bold text-lg text-slate-900 mb-6">Volym per kategori</h3>
          <div className="space-y-4">
            {categoriesArr.map(([key, val]) => (
              <div key={key}>
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-sm font-medium text-slate-700">{CATEGORY_LABEL[key] || key}</span>
                  <span className="font-mono-ga text-sm text-slate-900 tabular-nums">{val}</span>
                </div>
                <div className="h-2 bg-slate-100 overflow-hidden rounded-sm">
                  <div
                    className="h-full bg-slate-900 transition-all"
                    style={{ width: `${(val / maxCat) * 100}%`, backgroundColor: key === "hjulskifte" || key === "biltvatt" ? "#F59E0B" : "#111827" }}
                  />
                </div>
              </div>
            ))}
          </div>

          <div className="mt-8 pt-6 border-t border-slate-100">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <div className="eyebrow text-slate-400 mb-1">Kunder</div>
                <div className="font-display font-black text-2xl tabular-nums text-slate-900">{OVERVIEW.totalCustomers}</div>
              </div>
              <div>
                <div className="eyebrow text-slate-400 mb-1">Fordon</div>
                <div className="font-display font-black text-2xl tabular-nums text-slate-900">{OVERVIEW.totalVehicles}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
