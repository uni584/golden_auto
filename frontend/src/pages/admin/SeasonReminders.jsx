import React, { useState } from "react";
import { REMINDER_CAMPAIGNS, REMINDER_TEMPLATES, TIRE_HOTEL } from "@/mock/data";
import { Plus, PaperPlaneTilt, CalendarBlank, EnvelopeSimple, ChatCircleText, CheckCircle, Clock, PencilSimple, ChartBar, Users as UsersIcon, Snowflake, Sun } from "@phosphor-icons/react";
import { toast } from "sonner";

const STATUS_META = {
  sent: { label: "Skickad", color: "bg-emerald-100 text-emerald-800 border-emerald-200", Icon: CheckCircle },
  scheduled: { label: "Schemalagd", color: "bg-sky-100 text-sky-800 border-sky-200", Icon: Clock },
  draft: { label: "Utkast", color: "bg-slate-100 text-slate-700 border-slate-200", Icon: PencilSimple },
};

const SeasonReminders = () => {
  const [selected, setSelected] = useState(REMINDER_CAMPAIGNS[0]);
  const [showNew, setShowNew] = useState(false);
  const [segment, setSegment] = useState("winter_stored");
  const [channel, setChannel] = useState("email+sms");
  const [template, setTemplate] = useState("season_spring");

  const winterCount = TIRE_HOTEL.filter((t) => t.status === "stored" && t.season === "winter").length;
  const summerCount = TIRE_HOTEL.filter((t) => t.status === "stored" && t.season === "summer").length;

  const segmentSize = {
    winter_stored: winterCount,
    summer_stored: summerCount,
    no_spring_booking: 38,
    no_tire_hotel: 62,
  }[segment];

  const totals = {
    total: REMINDER_CAMPAIGNS.reduce((s, c) => s + c.targets, 0),
    sent: REMINDER_CAMPAIGNS.filter((c) => c.status === "sent").length,
    scheduled: REMINDER_CAMPAIGNS.filter((c) => c.status === "scheduled").length,
    booked: REMINDER_CAMPAIGNS.reduce((s, c) => s + (c.booked || 0), 0),
  };

  const sendNow = () => {
    toast.success(`Kampanj skickad till ${segmentSize} kunder`);
    setShowNew(false);
  };

  return (
    <div className="p-6 md:p-8" data-testid="reminders-page">
      <div className="flex items-center justify-between mb-8">
        <div>
          <div className="eyebrow text-slate-400 mb-1">Drift</div>
          <h1 className="font-display font-black text-3xl md:text-4xl tracking-tight text-slate-900">Säsongspåminnelser</h1>
          <p className="text-sm text-slate-500 mt-2">Automatiska utskick för hjulskifte, däckhotell och återkommande kunder.</p>
        </div>
        <button
          onClick={() => setShowNew(true)}
          className="bg-[#F59E0B] hover:bg-[#D97706] text-black font-bold px-5 py-2.5 text-sm flex items-center gap-2 rounded-sm"
          data-testid="new-campaign-btn"
        >
          <Plus size={16} weight="bold" /> Ny kampanj
        </button>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <Kpi label="Skickade utskick" value={totals.total.toLocaleString("sv-SE")} Icon={PaperPlaneTilt} accent="text-slate-700" />
        <Kpi label="Bokningar via kampanj" value={totals.booked} sub={`konv. ${Math.round((totals.booked / totals.total) * 100)}%`} Icon={ChartBar} accent="text-emerald-600" />
        <Kpi label="Schemalagda" value={totals.scheduled} sub="Nästa kör snart" Icon={CalendarBlank} accent="text-sky-600" />
        <Kpi label="Kunder i hotell" value={winterCount + summerCount} sub={`${winterCount} vinter · ${summerCount} sommar`} Icon={UsersIcon} accent="text-[#F59E0B]" />
      </div>

      <div className="grid lg:grid-cols-[1fr_420px] gap-6">
        {/* Campaign list */}
        <div className="bg-white border border-slate-200 rounded-sm" data-testid="campaign-list">
          <div className="px-5 py-4 border-b border-slate-100 flex items-center justify-between">
            <div>
              <div className="eyebrow text-slate-400 mb-1">Historik</div>
              <h3 className="font-display font-bold text-lg text-slate-900">Kampanjer</h3>
            </div>
            <span className="text-xs text-slate-500 font-mono-ga">{REMINDER_CAMPAIGNS.length} st</span>
          </div>
          <div className="divide-y divide-slate-100">
            {REMINDER_CAMPAIGNS.map((c) => {
              const s = STATUS_META[c.status];
              const isSel = selected?.id === c.id;
              return (
                <button
                  key={c.id}
                  onClick={() => setSelected(c)}
                  data-testid={`campaign-${c.id}`}
                  className={`w-full text-left px-5 py-4 transition ${isSel ? "bg-slate-900 text-white" : "hover:bg-slate-50"}`}
                >
                  <div className="flex items-start justify-between gap-4 mb-2">
                    <div className="min-w-0 flex-1">
                      <div className={`font-semibold truncate ${isSel ? "text-white" : "text-slate-900"}`}>{c.name}</div>
                      <div className={`text-xs mt-0.5 ${isSel ? "text-white/60" : "text-slate-500"}`}>{c.segment}</div>
                    </div>
                    <span className={`status-pill shrink-0 ${isSel ? "bg-white/10 text-white border-white/20" : s.color}`}>
                      <s.Icon size={11} weight="bold" /> {s.label}
                    </span>
                  </div>
                  <div className="flex items-center gap-5 flex-wrap mt-3 text-xs font-mono-ga">
                    <span className={`flex items-center gap-1.5 ${isSel ? "text-white/60" : "text-slate-500"}`}>
                      {c.channel.includes("email") && <EnvelopeSimple size={12} />}
                      {c.channel.includes("sms") && <ChatCircleText size={12} />}
                      {c.channel}
                    </span>
                    <span className={`tabular-nums ${isSel ? "text-white/80" : "text-slate-700"}`}>
                      <b>{c.targets}</b> kunder
                    </span>
                    {c.sent > 0 && (
                      <span className={`tabular-nums ${isSel ? "text-white/80" : "text-slate-700"}`}>
                        <b>{c.sent}</b> skickade
                      </span>
                    )}
                    {c.booked !== null && (
                      <span className={`tabular-nums font-bold ${isSel ? "text-[#F59E0B]" : "text-emerald-600"}`}>
                        {c.booked} bokningar
                      </span>
                    )}
                    {c.sentAt && (
                      <span className={`ml-auto ${isSel ? "text-white/50" : "text-slate-400"}`}>{c.sentAt}</span>
                    )}
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Right: detail or new campaign */}
        {showNew ? (
          <div className="bg-white border border-slate-200 rounded-sm" data-testid="new-campaign-panel">
            <div className="px-5 py-4 border-b border-slate-100 flex items-center justify-between">
              <h3 className="font-display font-bold text-lg text-slate-900">Skapa ny kampanj</h3>
              <button onClick={() => setShowNew(false)} className="text-slate-400 hover:text-slate-900 text-sm">Avbryt</button>
            </div>
            <div className="p-5 space-y-5">
              <div>
                <label className="eyebrow text-slate-500 block mb-2">Segment</label>
                <div className="space-y-2">
                  {[
                    { k: "winter_stored", l: "Vinterdäck i hotell (vårutskifte)", Icon: Snowflake, n: winterCount },
                    { k: "summer_stored", l: "Sommardäck i hotell (höstutskifte)", Icon: Sun, n: summerCount },
                    { k: "no_spring_booking", l: "Ej bokat vårskifte 2026", Icon: Clock, n: 38 },
                    { k: "no_tire_hotel", l: "Kunder utan däckhotell (upsell)", Icon: UsersIcon, n: 62 },
                  ].map((s) => (
                    <button
                      key={s.k}
                      onClick={() => setSegment(s.k)}
                      data-testid={`segment-${s.k}`}
                      className={`w-full p-3 border rounded-sm flex items-center gap-3 text-left transition ${
                        segment === s.k ? "border-slate-900 bg-slate-50" : "border-slate-200 hover:border-slate-400"
                      }`}
                    >
                      <s.Icon size={18} weight="duotone" className={segment === s.k ? "text-[#F59E0B]" : "text-slate-400"} />
                      <div className="flex-1">
                        <div className="text-sm font-semibold text-slate-900">{s.l}</div>
                      </div>
                      <span className="font-mono-ga font-bold text-slate-900 tabular-nums">{s.n}</span>
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="eyebrow text-slate-500 block mb-2">Kanal</label>
                <div className="flex gap-2">
                  {[
                    { k: "email", l: "E-post", Icon: EnvelopeSimple },
                    { k: "sms", l: "SMS", Icon: ChatCircleText },
                    { k: "email+sms", l: "Båda" },
                  ].map((c) => (
                    <button
                      key={c.k}
                      onClick={() => setChannel(c.k)}
                      data-testid={`channel-${c.k}`}
                      className={`flex-1 py-2.5 px-3 border text-sm font-semibold flex items-center justify-center gap-2 rounded-sm transition ${
                        channel === c.k ? "bg-slate-900 text-white border-slate-900" : "bg-white text-slate-600 border-slate-200 hover:border-slate-400"
                      }`}
                    >
                      {c.Icon && <c.Icon size={14} />} {c.l}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="eyebrow text-slate-500 block mb-2">Mall</label>
                <select
                  value={template}
                  onChange={(e) => setTemplate(e.target.value)}
                  data-testid="template-select"
                  className="w-full bg-slate-50 border border-slate-200 focus:border-slate-400 focus:bg-white outline-none px-3 py-2.5 text-sm rounded-sm"
                >
                  {REMINDER_TEMPLATES.map((t) => (
                    <option key={t.key} value={t.key}>{t.name}</option>
                  ))}
                </select>
                <div className="mt-3 p-3 bg-slate-50 border border-slate-200 text-xs text-slate-600 italic rounded-sm">
                  {REMINDER_TEMPLATES.find((t) => t.key === template)?.preview}
                </div>
              </div>

              <div className="pt-4 border-t border-slate-100 flex items-center justify-between">
                <div>
                  <div className="eyebrow text-slate-400">Mottagare</div>
                  <div className="font-display font-black text-2xl text-slate-900 tabular-nums">{segmentSize}</div>
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={() => { toast.success("Kampanj schemalagd"); setShowNew(false); }}
                    className="bg-white border border-slate-300 hover:bg-slate-50 text-slate-900 font-semibold px-4 py-2.5 text-sm rounded-sm flex items-center gap-2"
                    data-testid="schedule-campaign"
                  >
                    <Clock size={14} /> Schemalägg
                  </button>
                  <button
                    onClick={sendNow}
                    data-testid="send-campaign"
                    className="bg-[#F59E0B] hover:bg-[#D97706] text-black font-bold px-4 py-2.5 text-sm rounded-sm flex items-center gap-2"
                  >
                    <PaperPlaneTilt size={14} weight="bold" /> Skicka nu
                  </button>
                </div>
              </div>
            </div>
          </div>
        ) : selected ? (
          <div className="bg-white border border-slate-200 rounded-sm" data-testid="campaign-detail">
            <div className="px-5 py-4 border-b border-slate-100">
              <div className="eyebrow text-slate-400 mb-1">Detaljer</div>
              <h3 className="font-display font-bold text-lg text-slate-900 leading-tight">{selected.name}</h3>
              <div className="text-xs text-slate-500 mt-1">{selected.segment}</div>
            </div>
            <div className="p-5 space-y-4">
              {selected.status === "sent" && (
                <div className="grid grid-cols-3 gap-3 pb-5 border-b border-slate-100">
                  <Metric label="Skickade" value={selected.sent} />
                  <Metric label="Öppnade" value={selected.opened ?? "—"} />
                  <Metric label="Bokningar" value={selected.booked ?? "—"} accent="text-emerald-600" />
                </div>
              )}

              <Field label="Status">
                <span className={`status-pill ${STATUS_META[selected.status].color}`}>
                  {STATUS_META[selected.status].label}
                </span>
              </Field>
              <Field label="Kanal">
                <div className="flex items-center gap-2 text-sm text-slate-900">
                  {selected.channel.includes("email") && <span className="flex items-center gap-1"><EnvelopeSimple size={14} /> E-post</span>}
                  {selected.channel.includes("sms") && <span className="flex items-center gap-1"><ChatCircleText size={14} /> SMS</span>}
                </div>
              </Field>
              <Field label="Mall"><span className="font-mono-ga text-sm text-slate-900">{selected.template}</span></Field>
              {selected.sentAt && <Field label={selected.status === "sent" ? "Skickades" : "Schemalagd"}><span className="font-mono-ga text-sm text-slate-900">{selected.sentAt}</span></Field>}

              <div className="pt-4 border-t border-slate-100 p-0">
                <div className="eyebrow text-slate-500 mb-2">Förhandsgranskning</div>
                <div className="p-3 bg-slate-50 border border-slate-200 text-xs text-slate-700 leading-relaxed rounded-sm italic">
                  {REMINDER_TEMPLATES.find((t) => t.key === selected.template)?.preview}
                </div>
              </div>

              {selected.status === "draft" && (
                <button
                  onClick={() => toast.success("Kampanj skickad")}
                  className="w-full bg-[#F59E0B] hover:bg-[#D97706] text-black font-bold py-2.5 text-sm rounded-sm flex items-center justify-center gap-2"
                  data-testid="send-draft-campaign"
                >
                  <PaperPlaneTilt size={14} weight="bold" /> Skicka kampanj
                </button>
              )}
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
};

const Kpi = ({ label, value, sub, Icon, accent }) => (
  <div className="bg-white border border-slate-200 p-5 rounded-sm">
    <div className="flex items-center justify-between mb-3">
      <div className="eyebrow text-slate-400">{label}</div>
      {Icon && <Icon size={18} weight="duotone" className={accent || "text-slate-400"} />}
    </div>
    <div className="font-display font-black text-3xl tracking-tight text-slate-900 tabular-nums">{value}</div>
    {sub && <div className="mt-2 text-xs text-slate-500">{sub}</div>}
  </div>
);

const Field = ({ label, children }) => (
  <div>
    <div className="eyebrow text-slate-400 mb-1">{label}</div>
    {children}
  </div>
);

const Metric = ({ label, value, accent = "text-slate-900" }) => (
  <div>
    <div className="eyebrow text-slate-400 mb-1">{label}</div>
    <div className={`font-display font-black text-xl tabular-nums ${accent}`}>{value}</div>
  </div>
);

export default SeasonReminders;
