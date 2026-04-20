import React from "react";
import { USERS } from "@/mock/data";
import { Plus, PencilSimple, Trash, Shield, Wrench, Sparkle, UserCircle } from "@phosphor-icons/react";

const ROLE_META = {
  superadmin: { label: "Superadmin", color: "bg-rose-100 text-rose-800", Icon: Shield },
  admin: { label: "Admin / Reception", color: "bg-amber-100 text-amber-800", Icon: UserCircle },
  mechanic: { label: "Mekaniker", color: "bg-slate-900 text-white", Icon: Wrench },
  detailing: { label: "Rekond / Tvätt", color: "bg-sky-100 text-sky-800", Icon: Sparkle },
};

const Users = () => {
  return (
    <div className="p-6 md:p-8" data-testid="users-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">System</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Användare & Roller</h1>
        </div>
        <button className="bg-slate-900 hover:bg-black text-white px-4 py-2.5 text-sm font-semibold flex items-center gap-2 rounded-sm" data-testid="new-user-btn">
          <Plus size={16} weight="bold" /> Ny användare
        </button>
      </div>

      <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {Object.entries(ROLE_META).map(([key, m]) => {
          const count = USERS.filter((u) => u.role === key).length;
          return (
            <div key={key} className="bg-white border border-slate-200 rounded-sm p-5" data-testid={`role-card-${key}`}>
              <div className="flex items-center justify-between mb-2">
                <m.Icon size={20} weight="duotone" className="text-slate-600" />
                <span className={`text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-sm ${m.color}`}>{m.label}</span>
              </div>
              <div className="font-display font-black text-3xl text-slate-900 tabular-nums">{count}</div>
              <div className="eyebrow text-slate-400 mt-1">Aktiva</div>
            </div>
          );
        })}
      </div>

      <div className="bg-white border border-slate-200 rounded-sm">
        <div className="px-5 py-3 border-b border-slate-100 eyebrow text-slate-400">Användare ({USERS.length})</div>
        <div className="divide-y divide-slate-100">
          {USERS.map((u) => {
            const m = ROLE_META[u.role] || ROLE_META.admin;
            return (
              <div key={u.id} className="px-5 py-4 flex items-center gap-4 hover:bg-slate-50 transition" data-testid={`user-row-${u.id}`}>
                <div className="h-11 w-11 bg-slate-900 text-white grid place-items-center rounded-full font-display font-black">
                  {u.name.split(" ").map(s=>s[0]).slice(0,2).join("")}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold text-slate-900">{u.name}</div>
                  <div className="text-xs text-slate-500 font-mono-ga mt-0.5">{u.email}</div>
                </div>
                <span className={`px-2 py-1 text-[10px] font-bold uppercase tracking-wider rounded-sm ${m.color}`}>
                  {m.label}
                </span>
                {u.active ? (
                  <span className="flex items-center gap-1 text-xs text-emerald-700">
                    <span className="h-2 w-2 bg-emerald-500 rounded-full"></span> Aktiv
                  </span>
                ) : (
                  <span className="text-xs text-slate-400">Inaktiv</span>
                )}
                <div className="flex gap-1">
                  <button className="p-2 text-slate-400 hover:text-slate-900" aria-label="edit"><PencilSimple size={16} /></button>
                  <button className="p-2 text-slate-300 hover:text-red-600" aria-label="delete"><Trash size={16} /></button>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default Users;
