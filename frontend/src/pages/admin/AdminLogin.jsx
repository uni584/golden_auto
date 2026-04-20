import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useAuth } from "@/context/AuthContext";
import { toast } from "sonner";
import { ArrowRight, Lock, Envelope } from "@phosphor-icons/react";

const AdminLogin = () => {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("admin@goldenauto.se");
  const [password, setPassword] = useState("admin123");
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await login(email, password);
      toast.success("Inloggad");
      navigate("/admin");
    } catch (err) {
      toast.error(err.message || "Kunde inte logga in");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0A0A0A] grid lg:grid-cols-2" data-testid="admin-login-page">
      {/* LEFT: brand panel */}
      <div className="relative hidden lg:flex flex-col justify-between p-12 text-white overflow-hidden">
        <div
          className="absolute inset-0 bg-center bg-cover opacity-40"
          style={{ backgroundImage: "url('https://images.pexels.com/photos/36044141/pexels-photo-36044141.jpeg')" }}
        />
        <div className="absolute inset-0 bg-gradient-to-br from-black via-black/70 to-black/30" />
        <div className="relative">
          <Link to="/" className="flex items-center gap-3">
            <div className="h-10 w-10 bg-[#F59E0B] grid place-items-center">
              <span className="text-black font-display font-black text-xl">G</span>
            </div>
            <div>
              <div className="font-display font-black tracking-tight text-xl">GOLDEN AUTO</div>
              <div className="eyebrow text-[10px] text-[#A1A1AA]">Admin Console</div>
            </div>
          </Link>
        </div>
        <div className="relative">
          <div className="amber-divider mb-6" />
          <h2 className="font-display font-black text-5xl tracking-[-0.03em] leading-[1.05] mb-4">
            Verksamhetens
            <br />
            <span className="text-[#F59E0B]">digitala ryggrad.</span>
          </h2>
          <p className="text-white/60 max-w-md">
            Full spårbarhet. Standardiserade åtgärder. Allt inom ett klick.
          </p>
        </div>
        <div className="relative text-xs font-mono-ga text-white/40">
          v1.0 · © 2026 Golden Auto AB
        </div>
      </div>

      {/* RIGHT: form */}
      <div className="flex items-center justify-center p-6 md:p-12 bg-white">
        <form onSubmit={submit} className="w-full max-w-md" data-testid="admin-login-form">
          <div className="lg:hidden flex items-center gap-3 mb-10">
            <div className="h-10 w-10 bg-[#F59E0B] grid place-items-center">
              <span className="text-black font-display font-black text-xl">G</span>
            </div>
            <div className="font-display font-black text-xl text-slate-900">GOLDEN AUTO</div>
          </div>

          <div className="eyebrow text-[#D97706] mb-3">Inloggning</div>
          <h1 className="font-display font-black text-4xl tracking-tight text-slate-900 mb-2">Välkommen tillbaka</h1>
          <p className="text-slate-500 mb-10">Logga in för att komma åt adminpanelen.</p>

          <div className="space-y-5">
            <div>
              <label className="eyebrow text-slate-500 block mb-2">E-post</label>
              <div className="relative">
                <Envelope size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  data-testid="admin-login-email"
                  className="w-full bg-slate-50 border border-slate-200 focus:border-[#D97706] focus:bg-white outline-none pl-10 pr-4 py-3.5 text-slate-900 transition"
                  required
                />
              </div>
            </div>
            <div>
              <label className="eyebrow text-slate-500 block mb-2">Lösenord</label>
              <div className="relative">
                <Lock size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  data-testid="admin-login-password"
                  className="w-full bg-slate-50 border border-slate-200 focus:border-[#D97706] focus:bg-white outline-none pl-10 pr-4 py-3.5 text-slate-900 transition"
                  required
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              data-testid="admin-login-submit"
              className="w-full bg-slate-900 hover:bg-black text-white font-bold py-3.5 flex items-center justify-center gap-2 transition disabled:opacity-60"
            >
              {loading ? "Loggar in..." : (<>Logga in <ArrowRight size={16} weight="bold" /></>)}
            </button>

            <div className="text-xs text-slate-400 font-mono-ga border-t border-slate-100 pt-5 mt-5">
              <div className="flex items-center justify-between">
                <span>Demo-konto:</span>
                <span className="text-slate-600">admin@goldenauto.se / admin123</span>
              </div>
            </div>
          </div>

          <Link to="/" className="mt-10 block text-center text-sm text-slate-500 hover:text-slate-900 transition" data-testid="admin-login-back">
            ← Tillbaka till hemsidan
          </Link>
        </form>
      </div>
    </div>
  );
};

export default AdminLogin;
