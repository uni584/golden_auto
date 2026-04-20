import React from "react";
import { Outlet, NavLink, Link, useLocation } from "react-router-dom";
import { List, X } from "@phosphor-icons/react";

const NAV = [
  { to: "/", label: "Hem", end: true },
  { to: "/tjanster", label: "Tjänster" },
  { to: "/boka", label: "Boka tid" },
  { to: "/kontakt", label: "Kontakt" },
];

const PublicLayout = () => {
  const [open, setOpen] = React.useState(false);
  const location = useLocation();
  React.useEffect(() => setOpen(false), [location.pathname]);

  return (
    <div className="dark-theme min-h-screen" data-testid="public-layout">
      <header className="glass-nav fixed top-0 left-0 right-0 z-50">
        <div className="max-w-[1400px] mx-auto px-6 md:px-12 h-16 md:h-20 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-3" data-testid="public-logo">
            <div className="h-8 w-8 bg-[#F59E0B] grid place-items-center">
              <span className="text-black font-display font-black text-lg">G</span>
            </div>
            <div className="leading-tight">
              <div className="font-display font-black tracking-tight text-white text-lg">GOLDEN AUTO</div>
              <div className="eyebrow text-[10px] text-[#A1A1AA]">Workshop · Detail · Storage</div>
            </div>
          </Link>

          <nav className="hidden md:flex items-center gap-10">
            {NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                data-testid={`nav-${item.label.toLowerCase()}`}
                className={({ isActive }) =>
                  `text-sm tracking-wide transition-colors ${
                    isActive ? "text-[#F59E0B]" : "text-white/80 hover:text-white"
                  }`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>

          <div className="hidden md:flex items-center gap-3">
            <Link
              to="/admin/login"
              className="text-xs tracking-[0.2em] uppercase text-white/60 hover:text-white transition"
              data-testid="nav-admin"
            >
              Admin
            </Link>
            <Link
              to="/boka"
              className="btn-gold px-5 py-2.5 text-sm"
              data-testid="nav-boka-btn"
            >
              Boka tid →
            </Link>
          </div>

          <button
            className="md:hidden text-white p-2"
            onClick={() => setOpen(!open)}
            data-testid="mobile-menu-toggle"
            aria-label="menu"
          >
            {open ? <X size={22} /> : <List size={22} />}
          </button>
        </div>

        {open && (
          <div className="md:hidden bg-black/95 border-t border-white/10 px-6 py-6 space-y-4">
            {NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className="block text-white text-lg font-display"
                data-testid={`mobile-nav-${item.label.toLowerCase()}`}
              >
                {item.label}
              </NavLink>
            ))}
            <Link to="/boka" className="btn-gold block text-center px-5 py-3 mt-4">
              Boka tid
            </Link>
          </div>
        )}
      </header>

      <main className="pt-16 md:pt-20">
        <Outlet />
      </main>

      <footer className="bg-black border-t border-white/10 mt-32">
        <div className="max-w-[1400px] mx-auto px-6 md:px-12 py-16 grid md:grid-cols-4 gap-10">
          <div className="md:col-span-1">
            <div className="flex items-center gap-3 mb-4">
              <div className="h-8 w-8 bg-[#F59E0B] grid place-items-center">
                <span className="text-black font-display font-black text-lg">G</span>
              </div>
              <div className="font-display font-black text-white text-lg">GOLDEN AUTO</div>
            </div>
            <p className="text-[#A1A1AA] text-sm leading-relaxed">
              Professionell fordonsvård sedan 2008. Märkesoberoende verkstad, däckhotell och premium detailing.
            </p>
          </div>
          <div>
            <div className="eyebrow text-[#A1A1AA] mb-4">Navigation</div>
            <ul className="space-y-2 text-sm">
              {NAV.map((n) => (
                <li key={n.to}>
                  <Link to={n.to} className="text-white/80 hover:text-[#F59E0B] transition">{n.label}</Link>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <div className="eyebrow text-[#A1A1AA] mb-4">Kontakt</div>
            <ul className="space-y-2 text-sm text-white/80">
              <li>Industrigatan 14, 212 34 Malmö</li>
              <li>040-123 45 67</li>
              <li>info@goldenauto.se</li>
            </ul>
          </div>
          <div>
            <div className="eyebrow text-[#A1A1AA] mb-4">Öppettider</div>
            <ul className="space-y-2 text-sm text-white/80 font-mono-ga">
              <li className="flex justify-between"><span>Mån–Fre</span><span>07:00 – 17:00</span></li>
              <li className="flex justify-between"><span>Lördag</span><span>09:00 – 14:00</span></li>
              <li className="flex justify-between"><span>Söndag</span><span className="text-[#F59E0B]">Stängt</span></li>
            </ul>
          </div>
        </div>
        <div className="border-t border-white/10">
          <div className="max-w-[1400px] mx-auto px-6 md:px-12 py-6 flex flex-col md:flex-row items-center justify-between text-xs text-[#A1A1AA]">
            <span>© 2026 Golden Auto AB — Org.nr 556789-1234</span>
            <span className="mt-2 md:mt-0">Byggd med hantverk. Driven av precision.</span>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default PublicLayout;
