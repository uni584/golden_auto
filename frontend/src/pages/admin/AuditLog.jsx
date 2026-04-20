import React, { useState } from "react";
import { AUDIT_LOGS } from "@/mock/data";
import { ClockCounterClockwise, UserCircle } from "@phosphor-icons/react";

const ENTITY_LABEL = {
  booking: "Bokning",
  customer: "Kund",
  work_order: "Arbetsorder",
  receipt: "Kvitto",
  standard_action: "Standardåtgärd",
  user: "Användare",
  vehicle: "Fordon",
  service: "Tjänst",
};

const ENTITY_COLOR = {
  booking: "bg-sky-100 text-sky-800",
  customer: "bg-violet-100 text-violet-800",
  work_order: "bg-amber-100 text-amber-800",
  receipt: "bg-emerald-100 text-emerald-800",
  standard_action: "bg-rose-100 text-rose-800",
  user: "bg-slate-200 text-slate-800",
  vehicle: "bg-indigo-100 text-indigo-800",
  service: "bg-orange-100 text-orange-800",
};

const AuditLog = () => {
  const [entity, setEntity] = useState("all");
  const list = AUDIT_LOGS.filter((l) => entity === "all" || l.entity === entity);

  return (
    <div className="p-6 md:p-8" data-testid="audit-log-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">System</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Audit-logg</h1>
          <p className="text-sm text-slate-500 mt-2 max-w-xl">Full spårbarhet av alla kritiska ändringar i systemet.</p>
        </div>
      </div>

      <div className="flex gap-2 flex-wrap mb-6">
        <button onClick={() => setEntity("all")} className={`px-3 py-1.5 text-xs font-semibold border rounded-sm transition ${entity==="all"?"bg-slate-900 text-white border-slate-900":"bg-white text-slate-600 border-slate-200"}`} data-testid="audit-filter-all">Alla</button>
        {Object.keys(ENTITY_LABEL).map((k) => (
          <button key={k} onClick={() => setEntity(k)} className={`px-3 py-1.5 text-xs font-semibold border rounded-sm transition ${entity===k?"bg-slate-900 text-white border-slate-900":"bg-white text-slate-600 border-slate-200"}`} data-testid={`audit-filter-${k}`}>
            {ENTITY_LABEL[k]}
          </button>
        ))}
      </div>

      <div className="bg-white border border-slate-200 rounded-sm">
        <div className="relative">
          {list.map((log, i) => (
            <div key={log.id} className="relative flex gap-4 px-5 py-4 hover:bg-slate-50 transition border-b border-slate-100 last:border-0" data-testid={`audit-row-${log.id}`}>
              <div className="relative flex flex-col items-center">
                <div className="h-9 w-9 bg-slate-900 text-[#F59E0B] grid place-items-center rounded-full">
                  <ClockCounterClockwise size={16} />
                </div>
                {i < list.length - 1 && <div className="absolute top-9 bottom-[-17px] w-px bg-slate-200" />}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-3 flex-wrap">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className={`px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider rounded-sm ${ENTITY_COLOR[log.entity] || "bg-slate-100 text-slate-700"}`}>
                        {ENTITY_LABEL[log.entity] || log.entity}
                      </span>
                      <span className="font-mono-ga text-sm text-slate-900 font-semibold">{log.action}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-slate-500 mt-1">
                      <UserCircle size={14} />
                      <span>{log.user}</span>
                      <span>·</span>
                      <span className="font-mono-ga">ID: {log.entityId}</span>
                    </div>
                  </div>
                  <div className="text-xs text-slate-500 font-mono-ga">{log.ts}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default AuditLog;
