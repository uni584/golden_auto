import React from "react";
import { NavLink, Outlet, Link, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "@/context/AuthContext";
import {
  Gauge, Calendar, Users as UsersIcon, Car, ClipboardText, Wrench,
  ListChecks, Receipt, Bell, ClockCounterClockwise, UsersThree, SignOut,
  MagnifyingGlass, CaretDown, Warehouse, PaperPlaneTilt,
} from "@phosphor-icons/react";

const SECTIONS = [
  { label: "Drift", items: [
    { to: "/admin", end: true, icon: Gauge, label: "Dashboard" },
    { to: "/admin/bokningar", icon: Calendar, label: "Bokningar" },
    { to: "/admin/arbetsorder", icon: ClipboardText, label: "Arbetsorder" },
    { to: "/admin/kvitton", icon: Receipt, label: "Kvitton" },
    { to: "/admin/dackhotell", icon: Warehouse, label: "Däckhotell" },
    { to: "/admin/paminnelser", icon: PaperPlaneTilt, label: "Säsongspåminnelser" },
  ]},
  { label: "Register", items: [
    { to: "/admin/kunder", icon: UsersIcon, label: "Kunder" },
    { to: "/admin/fordon", icon: Car, label: "Fordon" },
  ]},
  { label: "Katalog", items: [
    { to: "/admin/tjanster", icon: Wrench, label: "Tjänster" },
    { to: "/admin/standardatgarder", icon: ListChecks, label: "Standardåtgärder" },
  ]},
  { label: "System", items: [
    { to: "/admin/notiser", icon: Bell, label: "Notiser" },
    { to: "/admin/auditlogg", icon: ClockCounterClockwise, label: "Audit-logg" },
    { to: "/admin/anvandare", icon: UsersThree, label: "Användare" },
  ]},
];

const AdminLayout = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => { logout(); navigate("/admin/login"); };

  return (
    <div className="min-h-screen bg-slate-50 flex" data-testid="admin-layout">
      {/* Sidebar */}
      <aside className="w-64 bg-white border-r border-slate-200 flex flex-col sticky top-0 h-screen">
        <Link to="/admin" className="flex items-center gap-3 px-5 py-5 border-b border-slate-200" data-testid="admin-logo">
          <div className="h-9 w-9 bg-[#F59E0B] grid place-items-center">
            <span className="text-black font-display font-black text-lg">G</span>
          </div>
          <div>
            <div className="font-display font-black tracking-tight text-slate-900">GOLDEN AUTO</div>
            <div className="eyebrow text-[9px] text-slate-400">Admin Console</div>
          </div>
        </Link>

        <nav className="flex-1 overflow-y-auto py-4 px-3 space-y-5">
          {SECTIONS.map((sec) => (
            <div key={sec.label}>
              <div className="eyebrow text-[10px] text-slate-400 px-3 mb-2">{sec.label}</div>
              <div className="space-y-0.5">
                {sec.items.map((it) => (
                  <NavLink
                    key={it.to}
                    to={it.to}
                    end={it.end}
                    data-testid={`sidebar-${it.label.toLowerCase().replace(/\s/g, "-")}`}
                    className={({ isActive }) => `admin-sidebar-link ${isActive ? "active" : ""}`}
                  >
                    <it.icon size={18} weight={location.pathname === it.to ? "fill" : "regular"} />
                    <span>{it.label}</span>
                  </NavLink>
                ))}
              </div>
            </div>
          ))}
        </nav>

        <div className="border-t border-slate-200 p-3">
          <div className="flex items-center gap-3 px-2 py-2">
            <div className="h-9 w-9 bg-slate-900 text-white grid place-items-center font-display font-black rounded-full">
              {user?.name?.[0]?.toUpperCase() || "A"}
            </div>
            <div className="min-w-0 flex-1">
              <div className="text-sm font-semibold text-slate-900 truncate">{user?.name || "Admin"}</div>
              <div className="text-xs text-slate-500 truncate">{user?.email}</div>
            </div>
            <button onClick={handleLogout} data-testid="logout-btn" className="text-slate-400 hover:text-red-600 transition p-1" aria-label="logout">
              <SignOut size={18} />
            </button>
          </div>
        </div>
      </aside>

      {/* Main */}
      <div className="flex-1 flex flex-col min-w-0">
        <header className="h-16 bg-white border-b border-slate-200 flex items-center gap-4 px-6 md:px-8 sticky top-0 z-20">
          <div className="relative flex-1 max-w-md">
            <MagnifyingGlass size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              placeholder="Sök kund, reg.nr, ordernummer..."
              data-testid="admin-global-search"
              className="w-full bg-slate-50 border border-slate-200 focus:border-slate-400 focus:bg-white outline-none pl-9 pr-4 py-2 text-sm text-slate-900 transition rounded-sm"
            />
          </div>
          <div className="ml-auto flex items-center gap-4 text-xs text-slate-500">
            <span className="hidden md:inline font-mono-ga">{new Date().toLocaleDateString("sv-SE", { weekday: "long", day: "numeric", month: "long" })}</span>
            <div className="flex items-center gap-2 px-3 py-1.5 bg-slate-100 rounded-sm">
              <span className="h-2 w-2 bg-emerald-500 rounded-full" />
              <span className="font-semibold text-slate-700">Live</span>
            </div>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default AdminLayout;
