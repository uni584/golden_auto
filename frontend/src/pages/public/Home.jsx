import React from "react";
import { Link } from "react-router-dom";
import { motion } from "framer-motion";
import { ArrowRight, Wrench, GearSix, CircleNotch, Warehouse, Drop, Sparkle, ShieldCheck, Clock, Medal } from "@phosphor-icons/react";
import { CATEGORIES } from "@/mock/data";

const ICONS = { Wrench, GearSix, CircleNotch, Warehouse, Drop, Sparkle };

const stagger = {
  hidden: {},
  show: { transition: { staggerChildren: 0.08 } },
};
const fadeUp = {
  hidden: { opacity: 0, y: 24 },
  show: { opacity: 1, y: 0, transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] } },
};

const Home = () => {
  return (
    <div className="bg-[#0A0A0A] text-white" data-testid="home-page">
      {/* ============ HERO ============ */}
      <section className="relative min-h-[92vh] flex items-end overflow-hidden grain hero-vignette">
        <div
          className="absolute inset-0 bg-center bg-cover"
          style={{
            backgroundImage:
              "url('https://images.pexels.com/photos/14231669/pexels-photo-14231669.jpeg')",
          }}
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black via-black/60 to-black/40" />

        <div className="relative z-10 max-w-[1400px] mx-auto px-6 md:px-12 py-20 md:py-28 w-full">
          <motion.div variants={stagger} initial="hidden" animate="show" className="max-w-4xl">
            <motion.div variants={fadeUp} className="flex items-center gap-4 mb-8">
              <div className="amber-divider" />
              <span className="eyebrow text-[#F59E0B]">Sedan 2008 · Malmö</span>
            </motion.div>

            <motion.h1
              variants={fadeUp}
              className="font-display font-black tracking-[-0.04em] text-5xl sm:text-6xl lg:text-[7.5rem] leading-[0.9] mb-10"
            >
              Din bil,
              <br />
              i <span className="text-[#F59E0B]">rätt</span> händer.
            </motion.h1>

            <motion.p variants={fadeUp} className="text-lg md:text-xl text-white/70 max-w-2xl leading-relaxed mb-12">
              Verkstad, service, hjulskifte, däckhotell, biltvätt och rekond — allt under ett tak.
              Boka din tid online på 60 sekunder.
            </motion.p>

            <motion.div variants={fadeUp} className="flex flex-wrap gap-4 items-center">
              <Link to="/boka" className="btn-gold px-8 py-4 text-sm flex items-center gap-2" data-testid="hero-cta-boka">
                Boka tid nu <ArrowRight size={16} weight="bold" />
              </Link>
              <Link to="/tjanster" className="btn-ghost-dark px-8 py-4 text-sm" data-testid="hero-cta-tjanster">
                Se alla tjänster
              </Link>
            </motion.div>
          </motion.div>
        </div>

        {/* ticker bottom */}
        <div className="absolute bottom-0 left-0 right-0 z-10 border-t border-white/10 bg-black/40 backdrop-blur">
          <div className="max-w-[1400px] mx-auto px-6 md:px-12 py-4 grid grid-cols-2 md:grid-cols-4 gap-4 text-xs font-mono-ga text-white/60">
            <div className="flex items-center gap-2"><ShieldCheck size={16} weight="bold" className="text-[#F59E0B]" /> Godkänd verkstad</div>
            <div className="flex items-center gap-2"><Clock size={16} weight="bold" className="text-[#F59E0B]" /> Boka på 60 sek</div>
            <div className="flex items-center gap-2"><Medal size={16} weight="bold" className="text-[#F59E0B]" /> 4.9 / 5 kundbetyg</div>
            <div className="flex items-center gap-2"><Warehouse size={16} weight="bold" className="text-[#F59E0B]" /> Tempererat däckhotell</div>
          </div>
        </div>
      </section>

      {/* ============ SERVICES ============ */}
      <section className="relative py-24 md:py-32">
        <div className="max-w-[1400px] mx-auto px-6 md:px-12">
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-8 mb-16">
            <div>
              <div className="flex items-center gap-4 mb-6">
                <div className="amber-divider" />
                <span className="eyebrow text-[#F59E0B]">Våra tjänster</span>
              </div>
              <h2 className="font-display font-black text-4xl md:text-5xl lg:text-6xl tracking-[-0.03em] max-w-3xl">
                Sex discipliner.
                <br />
                <span className="text-white/40">Ett garage.</span>
              </h2>
            </div>
            <p className="text-white/60 max-w-md text-base leading-relaxed">
              Från diagnos till lackskydd — vi tar ansvar för hela fordonets livslängd.
              Samma team, samma kvalitet, varje gång.
            </p>
          </div>

          <motion.div
            variants={stagger}
            initial="hidden"
            whileInView="show"
            viewport={{ once: true, amount: 0.2 }}
            className="grid md:grid-cols-2 lg:grid-cols-3 gap-6"
          >
            {CATEGORIES.map((cat, i) => {
              const Icon = ICONS[cat.icon] || Wrench;
              return (
                <motion.div key={cat.key} variants={fadeUp} className="service-card group relative overflow-hidden" data-testid={`service-card-${cat.key}`}>
                  <div className="aspect-[4/3] overflow-hidden">
                    <img
                      src={cat.image}
                      alt={cat.title}
                      className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
                      loading="lazy"
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-[#111] via-transparent to-transparent" />
                  </div>
                  <div className="p-7">
                    <div className="flex items-start justify-between mb-4">
                      <div>
                        <div className="eyebrow text-[#F59E0B] mb-2">{String(i + 1).padStart(2, "0")} · {cat.subtitle}</div>
                        <h3 className="font-display font-bold text-2xl tracking-tight">{cat.title}</h3>
                      </div>
                      <Icon size={28} weight="duotone" className="text-[#F59E0B] shrink-0" />
                    </div>
                    <p className="text-white/60 text-sm leading-relaxed mb-6">{cat.blurb}</p>
                    <Link
                      to="/boka"
                      state={{ category: cat.key }}
                      className="inline-flex items-center gap-2 text-sm font-semibold text-white group-hover:text-[#F59E0B] transition"
                      data-testid={`service-card-cta-${cat.key}`}
                    >
                      Boka {cat.title.toLowerCase()}
                      <ArrowRight size={14} weight="bold" className="transition-transform group-hover:translate-x-1" />
                    </Link>
                  </div>
                </motion.div>
              );
            })}
          </motion.div>
        </div>
      </section>

      {/* ============ PROCESS ============ */}
      <section className="relative py-24 md:py-32 border-t border-white/10 bg-gradient-to-b from-[#0A0A0A] to-[#0f0f0f]">
        <div className="max-w-[1400px] mx-auto px-6 md:px-12">
          <div className="flex items-center gap-4 mb-6">
            <div className="amber-divider" />
            <span className="eyebrow text-[#F59E0B]">Hur det funkar</span>
          </div>
          <h2 className="font-display font-black text-4xl md:text-5xl lg:text-6xl tracking-[-0.03em] mb-20 max-w-3xl">
            Från bokning till utlämning — <span className="text-white/40">utan gissningar.</span>
          </h2>

          <div className="grid md:grid-cols-3 gap-10 md:gap-16">
            {[
              { n: "01", t: "Boka online", d: "Välj tjänst, datum och tid. Du får bekräftelse via e-post och SMS inom sekunder." },
              { n: "02", t: "Lämna in", d: "Incheckning går snabbt. Vi dokumenterar fordonet och meddelar när arbetet startar." },
              { n: "03", t: "Hämta & kör", d: "Fullständigt kvitto med alla utförda åtgärder. SMS när bilen är redo att hämtas." },
            ].map((step, i) => (
              <motion.div
                key={step.n}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6, delay: i * 0.1 }}
                className="relative"
              >
                <div className="font-display font-black text-7xl text-[#F59E0B]/20 mb-4">{step.n}</div>
                <h3 className="font-display font-bold text-2xl mb-3">{step.t}</h3>
                <p className="text-white/60 leading-relaxed">{step.d}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* ============ CTA BAND ============ */}
      <section className="relative py-24 md:py-32">
        <div className="max-w-[1400px] mx-auto px-6 md:px-12">
          <div className="relative overflow-hidden bg-[#111] border border-white/10 p-10 md:p-16 lg:p-20">
            <div className="absolute -right-20 -top-20 w-96 h-96 bg-[#F59E0B]/10 blur-[120px] rounded-full pointer-events-none" />
            <div className="relative grid md:grid-cols-2 gap-10 items-center">
              <div>
                <div className="eyebrow text-[#F59E0B] mb-4">Redo när du är</div>
                <h2 className="font-display font-black text-4xl md:text-5xl tracking-[-0.03em] mb-6">
                  Boka tid i ditt
                  <br />
                  garage på 60 sekunder.
                </h2>
                <p className="text-white/60 max-w-md leading-relaxed">
                  Inga telefonkoer, inga formulär i PDF. Bara en smidig upplevelse — från skärm till ratt.
                </p>
              </div>
              <div className="flex md:justify-end">
                <Link to="/boka" className="btn-gold px-10 py-5 text-base flex items-center gap-3" data-testid="cta-band-boka">
                  Starta bokning <ArrowRight size={18} weight="bold" />
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};

export default Home;
