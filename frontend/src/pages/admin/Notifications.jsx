import React, { useState } from "react";
import { NOTIFICATIONS } from "@/mock/data";
import { EnvelopeSimple, ChatCircleText, CheckCircle, XCircle } from "@phosphor-icons/react";

const Notifications = () => {
  const [filter, setFilter] = useState("all");
  const list = NOTIFICATIONS.filter((n) => filter === "all" || n.channel === filter);

  return (
    <div className="p-6 md:p-8" data-testid="notifications-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">System</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Notiser</h1>
          <p className="text-sm text-slate-500 mt-2">Logg över skickade meddelanden (e-post & SMS).</p>
        </div>
      </div>

      <div className="flex gap-2 mb-6">
        {[
          { key: "all", label: "Alla" },
          { key: "email", label: "E-post" },
          { key: "sms", label: "SMS" },
        ].map((f) => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key)}
            data-testid={`notif-filter-${f.key}`}
            className={`px-4 py-2 text-sm font-semibold border rounded-sm transition ${
              filter === f.key ? "bg-slate-900 text-white border-slate-900" : "bg-white text-slate-600 border-slate-200 hover:border-slate-400"
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      <div className="bg-white border border-slate-200 rounded-sm">
        <div className="divide-y divide-slate-100">
          {list.map((n) => {
            const Icon = n.channel === "email" ? EnvelopeSimple : ChatCircleText;
            const isOk = n.status === "sent";
            return (
              <div key={n.id} className="px-5 py-4 flex items-center gap-4 hover:bg-slate-50 transition" data-testid={`notif-row-${n.id}`}>
                <div className={`h-10 w-10 grid place-items-center rounded-sm ${n.channel === "email" ? "bg-sky-100 text-sky-700" : "bg-amber-100 text-amber-700"}`}>
                  <Icon size={18} weight="duotone" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold text-slate-900 truncate">{n.subject || "(SMS)"}</div>
                  <div className="text-xs text-slate-500 mt-0.5">till <span className="font-mono-ga">{n.to}</span> · mall: <span className="font-mono-ga">{n.template}</span></div>
                </div>
                <div className="text-xs text-slate-500 font-mono-ga hidden md:block">{n.sentAt}</div>
                {isOk ? (
                  <span className="flex items-center gap-1.5 text-emerald-700 text-xs font-bold uppercase tracking-wider">
                    <CheckCircle size={14} weight="fill" /> Skickad
                  </span>
                ) : (
                  <span className="flex items-center gap-1.5 text-rose-700 text-xs font-bold uppercase tracking-wider">
                    <XCircle size={14} weight="fill" /> Misslyckades
                  </span>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default Notifications;
