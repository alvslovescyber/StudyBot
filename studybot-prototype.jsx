import React, { useState, useEffect, useRef, useMemo } from "react";

/* ============================================================
   StudyBot — clickable prototype, v2
   Seeded from DTS_L6_Sept_2026_intake.ics (real programme calendar)
   Visual reference for studybot-build-spec.md §9
   AI responses are canned. Nothing is persisted.
   ============================================================ */

const C = {
  canvas: "#FBFBFA", surface: "#FFFFFF", rowHover: "#F6F6F5",
  border: "#E8E8E6", borderStrong: "#D4D4D1",
  text: "#1D1D1F", text2: "#6E6E73", text3: "#A1A1A6",
  accent: "#5E6AD2", accentSoft: "#EEF0FB",
  backlog: "#A1A1A6", todo: "#6E6E73", drafting: "#D9A441",
  review: "#5E6AD2", done: "#4A9E6B", danger: "#C4483D",
};

const SANS = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", system-ui, sans-serif';
const SERIF = '"New York", ui-serif, Georgia, "Times New Roman", serif';
const MONO = '"SF Mono", ui-monospace, Menlo, monospace';

const TODAY = new Date(2026, 8, 14);
const d = (m, day) => new Date(2026, m - 1, day);

/* ---- real year-1 modules, from the programme calendar ---- */
const MODULES = [
  { id: "prog", code: "COM1018DA", name: "Programming", short: "PROG", colour: "#5E6AD2", term: 1 },
  { id: "dm", code: "COM1014DA", name: "Discrete Mathematics for Computer Science", short: "DM", colour: "#4A9E6B", term: 1 },
  { id: "pd1", code: "COM1017DA", name: "Professional Development 1", short: "PD1", colour: "#B4695E", term: 0 },
  { id: "oop", code: "COM1013DA", name: "Object-Oriented Programming", short: "OOP", colour: "#7B6BA8", term: 2 },
  { id: "cm", code: "COM1016DA", name: "Computational Mathematics", short: "CM", colour: "#D9A441", term: 2 },
  { id: "cti", code: "COM1015DA", name: "Computers and the Internet", short: "CTI", colour: "#3E8E9E", term: 3 },
  { id: "spi", code: "COM1019DA", name: "Social and Professional Issues", short: "SPI", colour: "#9A7B5E", term: 3 },
];

/* ---- term 1 events, straight from the ICS ---- */
const EVENTS = [
  { date: d(9, 22), kind: "induction", title: "Induction" },
  { date: d(9, 23), kind: "campus", title: "On campus" },
  { date: d(9, 24), kind: "campus", title: "On campus" },
  { date: d(9, 28), kind: "lecture", title: "Online lectures" },
  { date: d(10, 5), kind: "workshop", title: "Online workshops" },
  { date: d(10, 12), kind: "lecture", title: "Online lectures" },
  { date: d(10, 15), kind: "deadline", title: "Submission" },
  { date: d(10, 19), kind: "workshop", title: "Online workshops" },
  { date: d(10, 26), kind: "lecture", title: "Online lectures" },
  { date: d(11, 2), kind: "workshop", title: "Online workshops" },
  { date: d(11, 9), kind: "lecture", title: "Online lectures" },
  { date: d(11, 16), kind: "workshop", title: "Online workshops" },
  { date: d(11, 23), kind: "lecture", title: "Online lectures" },
  { date: d(11, 30), kind: "workshop", title: "Online workshops" },
  { date: d(12, 3), kind: "deadline", title: "Submission" },
  { date: d(12, 7), kind: "workshop", title: "Online workshops" },
  { date: d(12, 17), kind: "deadline", title: "Submission" },
  { date: d(12, 21), kind: "closure", title: "University closed" },
];

const seedAssignments = [
  { id: "a1", title: "Programming coursework 1", module: "prog", status: "drafting", priority: 3, due: d(10, 15), progress: 0.42, words: null },
  { id: "a2", title: "Submission — Discrete Mathematics", module: "dm", status: "todo", priority: 2, due: d(12, 3), progress: 0, words: null, unnamed: true },
  { id: "a3", title: "Submission — Professional Development 1", module: "pd1", status: "backlog", priority: 1, due: d(12, 17), progress: 0, words: 2000, unnamed: true },
  { id: "a4", title: "Submission — Object-Oriented Programming", module: "oop", status: "backlog", priority: 0, due: new Date(2027, 2, 18), progress: 0, words: null, unnamed: true },
  { id: "a5", title: "Submission — Computational Mathematics", module: "cm", status: "backlog", priority: 0, due: new Date(2027, 3, 1), progress: 0, words: null, unnamed: true },
];

const STATUSES = [
  { id: "drafting", label: "Drafting" }, { id: "review", label: "In review" },
  { id: "todo", label: "Todo" }, { id: "backlog", label: "Backlog" },
  { id: "submitted", label: "Submitted" }, { id: "graded", label: "Graded" },
];

const BLOCK_SESSIONS = [
  { id: "s0", day: 0, time: "10:00", title: "Induction", module: "pd1" },
  { id: "s1", day: 1, time: "09:30", title: "Programming — first principles", module: "prog" },
  { id: "s2", day: 1, time: "13:30", title: "Sets, relations and functions", module: "dm" },
  { id: "s3", day: 2, time: "09:30", title: "Control flow and functions", module: "prog" },
  { id: "s4", day: 2, time: "13:30", title: "Proof techniques", module: "dm" },
];

const SEED_LIVE = `- set = unordered collection, no duplicates
- |A| cardinality. empty set is a subset of everything
- cartesian product A x B = all ordered pairs
- relation is just a subset of A x B
ASK: do we need to prove reflexivity formally in the coursework?
- equivalence relation = reflexive + symmetric + transitive
- function: every element of domain maps to exactly one in codomain
ASK: is induction examined in term 1 or term 2?`;

const CANNED = `## Sets, relations and functions

### Sets
A set is an unordered collection with no duplicates. Cardinality |A| counts its elements. The empty set is a subset of every set, including itself.

### Cartesian product
A × B is the set of all ordered pairs (a, b) where a ∈ A and b ∈ B. Its cardinality is |A| × |B|.

### Relations
A relation from A to B is any subset of A × B. Nothing more exotic than that — the definition is deliberately permissive.

An **equivalence relation** is reflexive, symmetric and transitive. These three together partition a set into disjoint equivalence classes, which is the property that makes them useful.

### Functions
A function assigns exactly one element of the codomain to every element of the domain. "Exactly one" and "every" are both load-bearing — dropping either gives you a relation, not a function.

### Open questions
- Does the coursework require formal proof of reflexivity?
- Is induction examined in term 1 or term 2?`;

const seedEvidence = [
  { id: "e1", title: "Rewrote the deployment pipeline checks", date: "11 Sep", ksbs: ["S7", "S12"], conf: true, src: "Work project" },
  { id: "e2", title: "Led the sprint retrospective", date: "8 Sep", ksbs: ["B3", "S15"], conf: true, src: "Work project" },
  { id: "e3", title: "Shadowed the security review", date: "22 Aug", ksbs: ["K9"], conf: true, src: "Work project" },
];

const seedKSBs = [
  { code: "K4", cat: "Knowledge", text: "Principles of software engineering and the development lifecycle", n: 2 },
  { code: "K9", cat: "Knowledge", text: "Security principles and organisational risk", n: 1 },
  { code: "K11", cat: "Knowledge", text: "Data structures, storage and retrieval", n: 0 },
  { code: "S2", cat: "Skill", text: "Apply structured approaches to problem solving", n: 2 },
  { code: "S7", cat: "Skill", text: "Build and test resilient systems", n: 3 },
  { code: "S12", cat: "Skill", text: "Apply automation to delivery processes", n: 1 },
  { code: "S15", cat: "Skill", text: "Communicate technical concepts to non-technical audiences", n: 1 },
  { code: "B3", cat: "Behaviour", text: "Works collaboratively and reflects on team outcomes", n: 2 },
  { code: "B4", cat: "Behaviour", text: "Acts with integrity and professional judgement", n: 0 },
];

const seedOTJ = [
  { id: "o1", date: "11 Sep", hours: 2, cat: "Project work", desc: "Pipeline checks rewrite", linked: true },
  { id: "o2", date: "10 Sep", hours: 1.5, cat: "Self-study", desc: "Pre-reading for induction", linked: false },
  { id: "o3", date: "9 Sep", hours: 1, cat: "Mentoring", desc: "Session with workplace mentor", linked: false },
  { id: "o4", date: "4 Sep", hours: 2.5, cat: "Self-study", desc: "Python refresher", linked: false },
  { id: "o5", date: "2 Sep", hours: 3, cat: "Shadowing", desc: "Architecture review", linked: true },
];

const seedCards = [
  { id: "c1", front: "What three properties define an equivalence relation?", back: "Reflexive, symmetric and transitive. Together they partition a set into disjoint equivalence classes.", box: 2 },
  { id: "c2", front: "What is a relation from A to B?", back: "Any subset of A × B. The definition is deliberately permissive — no further structure is required.", box: 1 },
  { id: "c3", front: "Why is the empty set a subset of every set?", back: "Vacuously: there is no element of ∅ that fails to be in the other set, so the condition holds trivially.", box: 3 },
  { id: "c4", front: "What distinguishes a function from a relation?", back: "Every element of the domain maps to exactly one element of the codomain. Both 'every' and 'exactly one' are required.", box: 1 },
];

/* ================= motion (spec §9) ================= */
const Motion = () => (
  <style>{`
    @keyframes sb-rise { from { opacity:0; transform:translateY(8px) } to { opacity:1; transform:none } }
    @keyframes sb-pop  { from { opacity:0; transform:translateY(6px) scale(.97) } to { opacity:1; transform:none } }
    @keyframes sb-slide{ from { transform:translateX(100%) } to { transform:none } }
    @keyframes sb-fade { from { opacity:0 } to { opacity:1 } }
    .sb-rise  { animation: sb-rise 320ms cubic-bezier(.2,.7,.3,1) both }
    .sb-pop   { animation: sb-pop 180ms cubic-bezier(.2,.9,.3,1) both }
    .sb-slide { animation: sb-slide 260ms cubic-bezier(.22,.9,.28,1) both }
    .sb-fade  { animation: sb-fade 140ms ease both }
    /* Controls never move. Colour and material only. (spec 9) */
    .sb-btn   { transition: background-color 120ms ease }
    .sb-flip  { transform-style: preserve-3d; transition: transform 420ms cubic-bezier(.4,0,.2,1) }
    .sb-flip.on { transform: rotateY(180deg) }
    .sb-face  { backface-visibility: hidden; -webkit-backface-visibility: hidden }
    .sb-bar   { transition: width 500ms cubic-bezier(.2,.7,.3,1) }
    .sb-pill  { transition: transform 220ms cubic-bezier(.3,.9,.3,1) }
    @media (prefers-reduced-motion: reduce) {
      .sb-rise,.sb-pop,.sb-slide { animation: sb-fade 100ms ease both }
      .sb-flip,.sb-bar,.sb-pill { transition: none }
    }
  `}</style>
);

/* ================= primitives ================= */

function StatusIcon({ status, size = 14 }) {
  const col = { backlog: C.backlog, todo: C.todo, drafting: C.drafting, review: C.review, submitted: C.done, graded: C.done }[status] || C.todo;
  const r = size / 2 - 1.5, cx = size / 2, circ = 2 * Math.PI * (r / 2);
  const fill = { drafting: 0.5, review: 0.75 }[status];
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ flexShrink: 0 }}>
      <circle cx={cx} cy={cx} r={r} fill="none" stroke={col} strokeWidth="1.5" strokeDasharray={status === "backlog" ? "2.5 2.5" : undefined} />
      {fill && <circle cx={cx} cy={cx} r={r / 2} fill="none" stroke={col} strokeWidth={r} strokeDasharray={`${circ * fill} ${circ}`} transform={`rotate(-90 ${cx} ${cx})`} />}
      {(status === "submitted" || status === "graded") && <path d={`M${cx - 3} ${cx} l2 2 l4 -4`} fill="none" stroke={col} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />}
    </svg>
  );
}

function PriorityBars({ level }) {
  if (!level) return <div style={{ width: 14 }} />;
  return (
    <div className="flex items-end" style={{ gap: 1.5, height: 11, width: 14 }}>
      {[0, 1, 2].map((i) => (
        <div key={i} style={{ width: 3, height: 4 + i * 3.5, borderRadius: 1, background: i < Math.ceil(level * 0.75) ? (level === 4 ? C.danger : C.text2) : C.border }} />
      ))}
    </div>
  );
}

function ModuleChip({ id }) {
  const m = MODULES.find((x) => x.id === id);
  if (!m) return null;
  return (
    <span className="inline-flex items-center" style={{ gap: 5, fontSize: 11, fontWeight: 500, color: m.colour }}>
      <span style={{ width: 6, height: 6, borderRadius: 3, background: m.colour }} />{m.short}
    </span>
  );
}

function DueLabel({ date }) {
  if (!date) return <span style={{ color: C.text3, fontSize: 12 }}>—</span>;
  const days = Math.round((date - TODAY) / 86400000);
  const txt = days < 0 ? `${-days}d overdue` : days <= 14 ? (days === 0 ? "today" : `in ${days}d`)
    : date.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: date.getFullYear() !== 2026 ? "2-digit" : undefined });
  return <span style={{ fontSize: 12, color: days < 0 ? C.danger : C.text2 }}>{txt}</span>;
}

function Bar({ value, colour = C.accent, width = 56, delay = 0 }) {
  const [w, setW] = useState(0);
  useEffect(() => { const t = setTimeout(() => setW(value), 60 + delay); return () => clearTimeout(t); }, [value, delay]);
  return (
    <div style={{ width, height: 4, borderRadius: 2, background: C.border, overflow: "hidden", flexShrink: 0 }}>
      <div className="sb-bar" style={{ width: `${w * 100}%`, height: "100%", background: colour, borderRadius: 2 }} />
    </div>
  );
}

/* Primary buttons carry a leading icon; secondary never do. `sparkle` means
   the action calls the AI and spends budget. Depth is reserved for pressable
   things — cards and rows stay flat. (spec 9) */
function Btn({ children, onClick, primary, small, disabled, icon }) {
  const [h, setH] = useState(false);
  const [down, setDown] = useState(false);
  const fg = disabled ? C.text3 : primary ? "#fff" : C.text;

  const base = {
    gap: 6, fontFamily: SANS, fontSize: small ? 12 : 13, fontWeight: primary ? 510 : 500,
    padding: small ? "4px 11px" : primary ? "6px 14px" : "6px 13px",
    borderRadius: 7, color: fg, whiteSpace: "nowrap",
    cursor: disabled ? "default" : "pointer",
    /* Nothing moves: no transform on hover or press. Colour and material only. */
    transition: "background 120ms ease, box-shadow 120ms ease",
  };

  const skin = disabled
    ? { background: C.canvas, border: `1px solid ${C.border}`, boxShadow: "none" }
    : primary
      ? {
          background: down
            ? "linear-gradient(180deg, #4F5ABD 0%, #4A55B8 100%)"
            : h
              ? "linear-gradient(180deg, #727DDF 0%, #626ED6 55%, #5964CD 100%)"
              : "linear-gradient(180deg, #6E79DC 0%, #5E6AD2 55%, #5561C9 100%)",
          border: "1px solid #4F5ABD",
          boxShadow: down
            ? "inset 0 1px 2px rgba(20,24,70,0.30)"
            : "inset 0 1px 0 rgba(255,255,255,0.20), 0 1px 2px rgba(30,35,90,0.16), 0 1px 4px rgba(94,106,210,0.18)",
        }
      : {
          background: down ? "#F0F0EE" : h ? "#F6F6F5" : "linear-gradient(180deg, #FFFFFF 0%, #FAFAF9 100%)",
          border: "1px solid #DEDEDB",
          boxShadow: down ? "inset 0 1px 2px rgba(0,0,0,0.07)" : "0 1px 1.5px rgba(0,0,0,0.05)",
        };

  return (
    <button onClick={onClick} disabled={disabled} className="inline-flex items-center"
      onMouseEnter={() => setH(true)}
      onMouseLeave={() => { setH(false); setDown(false); }}
      onMouseDown={() => setDown(true)} onMouseUp={() => setDown(false)}
      style={{ ...base, ...skin }}>
      {icon && <Icon name={icon} c={fg} size={13} />}
      {children}
    </button>
  );
}

function Row({ children, onClick, selected }) {
  const [h, setH] = useState(false);
  return (
    <button onClick={onClick} className="w-full flex items-center text-left"
      onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
      style={{
        gap: 11, height: 38, padding: "0 20px", border: "none",
        borderBottom: `1px solid ${C.border}`, cursor: "pointer", fontFamily: SANS,
        background: selected ? C.accentSoft : h ? C.rowHover : C.surface,
      }}>{children}</button>
  );
}

function SectionHeader({ title, count, note }) {
  return (
    <div className="flex items-center justify-between" style={{ padding: "7px 20px", background: C.canvas, borderTop: `1px solid ${C.border}`, borderBottom: `1px solid ${C.border}` }}>
      <div className="flex items-center" style={{ gap: 8 }}>
        <span style={{ fontSize: 12, fontWeight: 600, color: C.text }}>{title}</span>
        {count !== undefined && <span style={{ fontSize: 12, color: C.text3 }}>{count}</span>}
      </div>
      {note && <span style={{ fontSize: 11, color: C.text3 }}>{note}</span>}
    </div>
  );
}

/* ================= term strip ================= */

function TermStrip({ onJump }) {
  const start = d(9, 21).getTime(), end = d(12, 21).getTime();
  const pos = (dt) => ((dt.getTime() - start) / (end - start)) * 100;
  const kindStyle = {
    induction: { c: C.accent, h: 15, w: 3 }, campus: { c: C.accent, h: 15, w: 3 },
    lecture: { c: C.text3, h: 8, w: 1.5 }, workshop: { c: C.text3, h: 8, w: 1.5 },
    closure: { c: C.border, h: 8, w: 3 },
  };
  return (
    <div style={{ marginTop: 30 }}>
      <div className="flex items-baseline justify-between" style={{ marginBottom: 14 }}>
        <span style={{ fontSize: 12, fontWeight: 600, color: C.text2 }}>Term 1</span>
        <span style={{ fontSize: 11, color: C.text3 }}>22 Sep – 21 Dec</span>
      </div>
      <div style={{ position: "relative", height: 34 }}>
        <div style={{ position: "absolute", top: 16, left: 0, right: 0, height: 1, background: C.border }} />
        {EVENTS.map((e, i) => {
          const left = `${pos(e.date)}%`;
          if (e.kind === "deadline") {
            return (
              <div key={i} onClick={() => onJump("assignments")} title={`Submission · ${e.date.toLocaleDateString("en-GB", { day: "numeric", month: "short" })}`}
                style={{ position: "absolute", left, top: 11, width: 11, height: 11, marginLeft: -5.5, borderRadius: 6, background: C.surface, border: `2px solid ${C.drafting}`, cursor: "pointer" }} />
            );
          }
          const s = kindStyle[e.kind]; if (!s) return null;
          return <div key={i} style={{ position: "absolute", left, top: 16 - s.h / 2, width: s.w, marginLeft: -s.w / 2, height: s.h, borderRadius: 1, background: s.c }} />;
        })}
        <div style={{ position: "absolute", left: `${pos(TODAY)}%`, top: 4, bottom: 4, width: 1.5, marginLeft: -0.75, background: C.text }} />
        <div style={{ position: "absolute", left: `${pos(TODAY)}%`, top: 0, fontSize: 10, color: C.text, transform: "translateX(-50%)" }}>今</div>
      </div>
      <div className="flex" style={{ gap: 16, marginTop: 8 }}>
        {[["On campus", C.accent], ["Online session", C.text3], ["Submission", C.drafting]].map(([l, c]) => (
          <span key={l} className="inline-flex items-center" style={{ gap: 5, fontSize: 11, color: C.text3 }}>
            <span style={{ width: 6, height: 6, borderRadius: 3, background: c }} />{l}
          </span>
        ))}
      </div>
    </div>
  );
}

/* ================= Today ================= */

function Today({ setView, openBlock }) {
  const [accepted, setAccepted] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const next = seedAssignments[0];
  const plan = [
    { t: "Work through the Programming pre-reading", m: "60m" },
    { t: "Set up your dev environment before induction", m: "45m" },
    { t: "Log Thursday's pipeline work as evidence", m: "10m" },
  ];
  const S = (i) => ({ animationDelay: `${i * 50}ms` });

  return (
    <div style={{ padding: "28px 32px 60px", maxWidth: 720 }}>
      <div className="sb-rise" style={{ ...S(0), fontSize: 20, fontWeight: 600, letterSpacing: "-0.01em" }}>Monday 14 September</div>

      <button onClick={openBlock} className="w-full flex items-center justify-between sb-rise sb-btn"
        style={{ ...S(1), marginTop: 18, padding: "12px 14px", borderRadius: 10, border: `1px solid ${C.border}`, background: C.accentSoft, cursor: "pointer", fontFamily: SANS }}>
        <span style={{ fontSize: 13, fontWeight: 550, color: C.accent }}>Induction starts in 8 days</span>
        <span style={{ fontSize: 12, color: C.accent }}>22–24 Sept →</span>
      </button>

      <div className="sb-rise" style={{ ...S(2), marginTop: 26 }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: C.text2, marginBottom: 10 }}>Next deadline</div>
        <button onClick={() => setView("assignments")} className="w-full flex items-start text-left sb-btn"
          style={{ gap: 11, padding: "14px 16px", borderRadius: 10, border: `1px solid ${C.border}`, background: C.surface, cursor: "pointer", fontFamily: SANS }}>
          <div style={{ marginTop: 2 }}><StatusIcon status="drafting" size={15} /></div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 550 }}>Programming coursework 1</div>
            <div style={{ fontSize: 12, color: C.text2, marginTop: 3 }}>COM1018DA · due in 31 days · 15 October</div>
            <div className="flex items-center" style={{ gap: 8, marginTop: 9 }}>
              <Bar value={0.42} width={160} delay={260} /><span style={{ fontSize: 11, color: C.text3 }}>42%</span>
            </div>
          </div>
        </button>
      </div>

      {!dismissed && (
        <div className="sb-rise" style={{ ...S(3), marginTop: 26 }}>
          <div className="flex items-center justify-between" style={{ marginBottom: 10 }}>
            <span style={{ fontSize: 12, fontWeight: 600, color: C.text2 }}>Today's plan</span>
            <span style={{ fontSize: 11, color: C.text3 }}>Suggested</span>
          </div>
          <div style={{ borderRadius: 10, border: `1px solid ${C.border}`, background: C.surface, overflow: "hidden" }}>
            {plan.map((p, i) => (
              <div key={i} className="flex items-center" style={{ gap: 11, padding: "11px 16px", borderTop: i ? `1px solid ${C.border}` : "none" }}>
                <StatusIcon status={accepted ? "todo" : "backlog"} size={14} />
                <span style={{ flex: 1, fontSize: 13, color: accepted ? C.text : C.text2 }}>{p.t}</span>
                <span style={{ fontSize: 11, color: C.text3, fontFamily: MONO }}>{p.m}</span>
              </div>
            ))}
            <div className="flex items-center justify-end" style={{ gap: 8, padding: "10px 14px", borderTop: `1px solid ${C.border}`, background: C.canvas }}>
              {accepted ? <span className="sb-fade" style={{ fontSize: 12, color: C.done }}>Added to today</span> : (
                <><Btn small onClick={() => setDismissed(true)}>Dismiss</Btn><Btn small primary icon="check" onClick={() => setAccepted(true)}>Accept plan</Btn></>
              )}
            </div>
          </div>
        </div>
      )}

      <div className="sb-rise" style={{ ...S(4), marginTop: 26 }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: C.text2, marginBottom: 10 }}>Off-the-job</div>
        <button onClick={() => setView("portfolio")} className="w-full flex items-center justify-between sb-btn"
          style={{ padding: "14px 16px", borderRadius: 10, border: `1px solid ${C.border}`, background: C.surface, cursor: "pointer", fontFamily: SANS }}>
          <div className="flex items-center" style={{ gap: 12 }}>
            <span style={{ fontSize: 13 }}>4.5 of 6 hours this week</span>
            <Bar value={0.75} colour={C.drafting} width={90} delay={320} />
          </div>
          <span style={{ fontSize: 12, color: C.accent }}>Log hours →</span>
        </button>
      </div>

      <div className="sb-rise" style={S(5)}><TermStrip onJump={setView} /></div>
    </div>
  );
}

/* ================= Assignments ================= */

function Assignments({ onOpen, selected }) {
  const [filter, setFilter] = useState("all");
  const groups = STATUSES.map((s) => ({ ...s, items: seedAssignments.filter((a) => a.status === s.id && (filter === "all" || a.module === filter)) })).filter((g) => g.items.length);

  return (
    <div>
      <div className="flex items-center justify-between" style={{ padding: "14px 20px", borderBottom: `1px solid ${C.border}` }}>
        <span style={{ fontSize: 15, fontWeight: 600 }}>Assignments</span>
        <div className="flex items-center" style={{ gap: 8 }}>
          <select value={filter} onChange={(e) => setFilter(e.target.value)}
            style={{ fontFamily: SANS, fontSize: 12, color: C.text2, padding: "4px 8px", borderRadius: 6, border: `1px solid ${C.border}`, background: C.surface, cursor: "pointer" }}>
            <option value="all">All modules</option>
            {MODULES.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
          </select>
          <Btn small primary icon="plus">New</Btn>
        </div>
      </div>

      <div style={{ padding: "9px 20px", fontSize: 11.5, color: C.text2, background: C.accentSoft, borderBottom: `1px solid ${C.border}` }}>
        30 submissions imported from the programme calendar. Rename them as ELE2 tells you what they are.
      </div>

      {groups.map((g) => (
        <div key={g.id}>
          <SectionHeader title={g.label} count={g.items.length} />
          {g.items.map((a) => (
            <Row key={a.id} onClick={() => onOpen(a)} selected={selected?.id === a.id}>
              <StatusIcon status={a.status} />
              <span className="truncate" style={{ flex: 1, fontSize: 13, color: a.unnamed ? C.text2 : C.text, fontStyle: a.unnamed ? "italic" : "normal" }}>{a.title}</span>
              <div style={{ width: 58 }}><ModuleChip id={a.module} /></div>
              <PriorityBars level={a.priority} />
              <div style={{ width: 78, textAlign: "right" }}><DueLabel date={a.due} /></div>
              <div style={{ width: 56, display: "flex", justifyContent: "flex-end" }}>
                {a.progress > 0 ? <Bar value={a.progress} width={44} /> : <span style={{ fontSize: 12, color: C.text3 }}>—</span>}
              </div>
            </Row>
          ))}
        </div>
      ))}
    </div>
  );
}

function Field({ label, hint, children }) {
  return (
    <div style={{ marginTop: 22 }}>
      <div className="flex items-center justify-between" style={{ marginBottom: 8 }}>
        <span style={{ fontSize: 12, fontWeight: 600, color: C.text2 }}>{label}</span>
        {hint && <span style={{ fontSize: 11, color: C.text3 }}>{hint}</span>}
      </div>
      {children}
    </div>
  );
}

function AssignmentPanel({ a, onClose }) {
  const [busy, setBusy] = useState(false);
  const [checked, setChecked] = useState(false);
  const initialRubric = a.id === "a1" ? "1. Correctness against the specification (40%)\n2. Code quality and readability (25%)\n3. Testing and edge cases (20%)\n4. Written commentary (15%)" : "";
  const [rubric, setRubric] = useState(initialRubric);
  const [title, setTitle] = useState(a.title);
  const [editing, setEditing] = useState(false);
  const [snapshot, setSnapshot] = useState(null);
  const m = MODULES.find((x) => x.id === a.module);

  const startEdit = () => { setSnapshot({ rubric, title }); setEditing(true); };
  const cancel = () => {
    const changed = snapshot && (snapshot.rubric !== rubric || snapshot.title !== title);
    if (changed && !window.confirm("Discard changes to this assignment?")) return;
    if (snapshot) { setRubric(snapshot.rubric); setTitle(snapshot.title); }
    setEditing(false);
  };

  return (
    <div className="sb-slide" style={{ width: 440, flexShrink: 0, borderLeft: `1px solid ${C.border}`, background: C.surface, overflowY: "auto", height: "100%" }}>
      <div className="flex items-center justify-between" style={{ padding: "12px 18px", borderBottom: `1px solid ${C.border}`, position: "sticky", top: 0, background: C.surface, zIndex: 2 }}>
        <ModuleChip id={a.module} />
        <div className="flex items-center" style={{ gap: 8 }}>
          {editing ? (
            <><Btn small onClick={cancel}>Cancel</Btn><Btn small primary icon="check" onClick={() => setEditing(false)}>Save changes</Btn></>
          ) : (
            <Btn small primary icon="pencil" onClick={startEdit}>Edit</Btn>
          )}
          <button onClick={onClose} className="sb-btn" style={{ border: "none", background: "transparent", color: C.text3, fontSize: 15, cursor: "pointer", paddingLeft: 2 }}>✕</button>
        </div>
      </div>

      <div style={{ padding: "18px 18px 48px" }}>
        {editing ? (
          <input value={title} onChange={(e) => setTitle(e.target.value)}
            style={{ width: "100%", fontSize: 17, fontWeight: 600, letterSpacing: "-0.01em", fontFamily: SANS, color: C.text,
                     padding: "5px 9px", marginLeft: -9, borderRadius: 6, border: `1px solid ${C.accent}`, outline: "none", background: C.surface }} />
        ) : (
          <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: "-0.01em" }}>{title}</div>
        )}
        <div style={{ fontSize: 12, color: C.text2, marginTop: 4 }}>{m?.code} {m?.name}</div>

        <div className="flex items-center" style={{ gap: 8, marginTop: 16, flexWrap: "wrap" }}>
          {[{ l: STATUSES.find((s) => s.id === a.status)?.label, i: <StatusIcon status={a.status} size={12} />, ed: true },
            { l: a.due?.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }), ed: true },
            { l: "via ELE2", ed: false }].map((c, i) => (
            <span key={i} className="inline-flex items-center"
              style={{ gap: 6, fontSize: 12, color: editing && c.ed ? C.text : C.text2, padding: "4px 9px", borderRadius: 6,
                       border: `1px solid ${editing && c.ed ? C.borderStrong : C.border}`,
                       background: editing && c.ed ? C.surface : "transparent",
                       cursor: editing && c.ed ? "pointer" : "default",
                       boxShadow: editing && c.ed ? "0 1px 2px rgba(0,0,0,0.05)" : "none" }}>
              {c.i}{c.l}{editing && c.ed && <span style={{ color: C.text3, fontSize: 10 }}>▾</span>}
            </span>
          ))}
        </div>

        <Field label="Brief" hint={a.unnamed ? "not published yet" : undefined}>
          {a.unnamed ? (
            <div style={{ fontSize: 12.5, color: C.text3, lineHeight: 1.6, padding: "14px 14px", borderRadius: 8, border: `1px dashed ${C.borderStrong}` }}>
              The calendar gave the date and the module. The brief comes from ELE2 — drop the PDF here when it appears.
            </div>
          ) : (
            <div style={{ fontSize: 13, color: C.text2, lineHeight: 1.55 }}>
              Implement the specified program, test it against the provided cases, and write a short commentary explaining your design decisions.
            </div>
          )}
        </Field>

        <Field label="Rubric" hint={rubric ? undefined : "needed before the checker can mark anything"}>
          {editing ? (
            <textarea value={rubric} onChange={(e) => setRubric(e.target.value)} placeholder="Paste the real marking criteria here"
              onFocus={(e) => (e.target.style.borderColor = C.accent)} onBlur={(e) => (e.target.style.borderColor = C.borderStrong)}
              style={{ width: "100%", minHeight: 76, resize: "vertical", padding: "9px 11px", borderRadius: 6, border: `1px solid ${C.borderStrong}`, fontFamily: SANS, fontSize: 12, lineHeight: 1.6, background: C.surface, outline: "none", color: C.text }} />
          ) : rubric ? (
            <div style={{ fontSize: 12, lineHeight: 1.7, color: C.text2, whiteSpace: "pre-wrap" }}>{rubric}</div>
          ) : (
            <div style={{ fontSize: 12.5, color: C.text3 }}>No rubric yet. Press Edit and paste the marking criteria.</div>
          )}
        </Field>

        {!a.unnamed && (
          <Field label="Draft">
            <div className="flex items-center justify-between" style={{ marginBottom: 8 }}>
              <span style={{ fontSize: 12, color: C.text2 }}>Commentary · 420 words</span><Bar value={0.42} width={110} />
            </div>
            <div style={{ padding: "12px 14px", borderRadius: 8, border: `1px solid ${C.border}`, fontFamily: SERIF, fontSize: 14, lineHeight: 1.6, background: C.canvas }}>
              <strong style={{ fontWeight: 600 }}>Design decisions.</strong> I separated parsing from evaluation so that each could be
              tested independently. The parser returns a token list rather than acting on input directly, which made the edge cases…
            </div>
          </Field>
        )}

        <div className="flex items-center" style={{ gap: 8, marginTop: 18 }}>
          <Btn primary small icon="sparkle" disabled={!rubric || busy} onClick={() => { setBusy(true); setTimeout(() => { setBusy(false); setChecked(true); }, 1000); }}>
            {busy ? "Checking…" : "Check against rubric"}
          </Btn>
          <Btn small>Outline</Btn><Btn small>Draft a section</Btn>
        </div>

        {checked && (
          <div className="sb-pop" style={{ marginTop: 14, borderRadius: 10, border: `1px solid ${C.border}`, background: C.canvas, overflow: "hidden" }}>
            <div style={{ padding: "8px 13px", borderBottom: `1px solid ${C.border}`, fontSize: 11, fontWeight: 600, color: C.text2, background: C.surface }}>
              Marked against your rubric · logged to AI use
            </div>
            {[{ c: "Correctness against the specification", b: "Distinction", col: C.done, g: "All provided cases pass and you handle empty input. Nothing to fix." },
              { c: "Code quality and readability", b: "Merit", col: C.accent, g: "Naming is consistent but three functions exceed forty lines. Splitting the evaluator would show the separation you argue for in the commentary." },
              { c: "Testing and edge cases", b: "Pass", col: C.text2, g: "You test the happy path thoroughly and nothing else. Add cases for malformed input — that gap is what separates a pass from a distinction here." }].map((r, i) => (
              <div key={i} style={{ padding: "11px 13px", borderTop: i ? `1px solid ${C.border}` : "none" }}>
                <div className="flex items-center justify-between">
                  <span style={{ fontSize: 12, fontWeight: 550 }}>{r.c}</span>
                  <span style={{ fontSize: 11, fontWeight: 600, color: r.col }}>{r.b}</span>
                </div>
                <div style={{ fontSize: 12, color: C.text2, marginTop: 4, lineHeight: 1.55 }}>{r.g}</div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

/* ================= session notes ================= */

function Markdown({ text }) {
  return (
    <div style={{ fontFamily: SERIF, fontSize: 14.5, lineHeight: 1.62, color: C.text, maxWidth: "62ch" }}>
      {text.split("\n").map((line, i) => {
        if (!line.trim()) return <div key={i} style={{ height: 9 }} />;
        if (line.startsWith("### ")) return <div key={i} style={{ fontFamily: SANS, fontSize: 12.5, fontWeight: 650, color: C.text2, marginTop: 14, marginBottom: 4 }}>{line.slice(4)}</div>;
        if (line.startsWith("## ")) return <div key={i} style={{ fontFamily: SANS, fontSize: 16, fontWeight: 600, marginBottom: 8, letterSpacing: "-0.01em" }}>{line.slice(3)}</div>;
        if (line.startsWith("- ")) return <div key={i} style={{ paddingLeft: 14, marginTop: 2 }}>· {line.slice(2)}</div>;
        const parts = line.split(/\*\*(.+?)\*\*/g);
        return <div key={i} style={{ marginTop: 4 }}>{parts.map((p, j) => (j % 2 ? <strong key={j} style={{ fontWeight: 650 }}>{p}</strong> : p))}</div>;
      })}
    </div>
  );
}

/* Notion-style live editor: a transparent textarea over a styled mirror.
   Styling may change colour, background and left decoration — never font
   size, weight or character count, or the caret drifts. (spec 6.3) */
const NOTE_TYPE = {
  fontFamily: SANS, fontSize: 15, lineHeight: 1.7,
  padding: "20px 28px 28px", whiteSpace: "pre-wrap", wordBreak: "break-word",
  margin: 0, border: "none", boxSizing: "border-box", letterSpacing: "normal",
};

function NotesEditor({ value, onChange }) {
  const ta = useRef(null), mir = useRef(null);
  const sync = () => { if (mir.current && ta.current) mir.current.scrollTop = ta.current.scrollTop; };
  return (
    <div style={{ position: "relative", flex: 1, minHeight: 0, background: C.surface }}>
      <div ref={mir} aria-hidden style={{ ...NOTE_TYPE, position: "absolute", inset: 0, overflow: "hidden", color: C.text, pointerEvents: "none" }}>
        {value.split("\n").map((l, i) => {
          const ask = l.trimStart().startsWith("ASK:");
          const dash = l.indexOf("- ");
          const bullet = /^\s*- /.test(l);
          return (
            <div key={i} style={{
              minHeight: "1.7em",
              background: ask ? C.accentSoft : "transparent",
              boxShadow: ask ? `inset 2px 0 0 ${C.accent}` : "none",
              borderRadius: ask ? 3 : 0,
              marginLeft: -10, paddingLeft: 10, marginRight: -10, paddingRight: 10,
              color: ask ? C.accent : C.text,
            }}>
              {bullet
                ? <><span style={{ color: C.text3 }}>{l.slice(0, dash + 1)}</span>{l.slice(dash + 1)}</>
                : (l || "\u200b")}
            </div>
          );
        })}
      </div>
      <textarea ref={ta} value={value} spellCheck={false} onScroll={sync}
        onChange={(e) => { onChange(e.target.value); sync(); }}
        placeholder="Type. Sort it out later."
        style={{ ...NOTE_TYPE, position: "absolute", inset: 0, width: "100%", height: "100%", resize: "none", outline: "none", background: "transparent", color: "transparent", caretColor: C.text, overflowY: "auto" }} />
    </div>
  );
}

function SessionView({ session }) {
  const [live, setLive] = useState(SEED_LIVE);
  const [structured, setStructured] = useState("");
  const [busy, setBusy] = useState(false);
  const [tab, setTab] = useState("structured");
  const questions = useMemo(() => live.split("\n").filter((l) => l.trim().startsWith("ASK:")).map((l) => l.trim().replace("ASK:", "").trim()), [live]);
  const words = live.trim() ? live.trim().split(/\s+/).length : 0;

  return (
    <div className="flex flex-col" style={{ height: "100%" }}>
      <div style={{ padding: "14px 20px", borderBottom: `1px solid ${C.border}` }}>
        <div className="flex items-center" style={{ gap: 9 }}>
          <ModuleChip id={session.module} />
          <span style={{ fontSize: 15, fontWeight: 600 }}>{session.title}</span>
        </div>
        <div style={{ fontSize: 12, color: C.text3, marginTop: 3 }}>
          {["Tue 22", "Wed 23", "Thu 24"][session.day]} September · {session.time} · on campus
        </div>
      </div>

      <div className="flex" style={{ flex: 1, minHeight: 0 }}>
        <div className="flex flex-col" style={{ flex: 1, borderRight: `1px solid ${C.border}`, minWidth: 0 }}>
          <div className="flex items-center justify-between" style={{ padding: "9px 28px", borderBottom: `1px solid ${C.border}` }}>
            <span style={{ fontSize: 12, fontWeight: 600, color: C.text2 }}>Live notes</span>
            <span style={{ fontSize: 11, color: C.text3 }}>{words} words</span>
          </div>
          <NotesEditor value={live} onChange={setLive} />
          {questions.length > 0 && (
            <div style={{ borderTop: `1px solid ${C.border}`, background: C.canvas, padding: "11px 28px" }}>
              <div style={{ fontSize: 11, fontWeight: 600, color: C.accent, marginBottom: 6 }}>Ask the tutor · {questions.length}</div>
              {questions.map((q, i) => (
                <div key={i} className="sb-fade flex items-start" style={{ gap: 8, fontSize: 12.5, lineHeight: 1.65 }}>
                  <span style={{ color: C.text3 }}>·</span><span>{q}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="flex flex-col" style={{ flex: 1, minWidth: 0 }}>
          <div className="flex items-center justify-between" style={{ padding: "6px 20px", borderBottom: `1px solid ${C.border}` }}>
            <div className="flex" style={{ gap: 14 }}>
              {["structured", "transcript"].map((t) => (
                <button key={t} onClick={() => setTab(t)} style={{
                  border: "none", background: "transparent", cursor: "pointer", fontFamily: SANS, fontSize: 12, fontWeight: 600,
                  padding: "3px 0", color: tab === t ? C.text : C.text3, borderBottom: tab === t ? `2px solid ${C.accent}` : "2px solid transparent",
                }}>{t === "structured" ? "Structured" : "Transcript"}</button>
              ))}
            </div>
            <Btn small primary icon="sparkle" disabled={busy} onClick={() => { setBusy(true); setTab("structured"); setTimeout(() => { setStructured(CANNED); setBusy(false); }, 1100); }}>
              {busy ? "Structuring…" : "Structure these notes"}
            </Btn>
          </div>

          <div style={{ flex: 1, overflowY: "auto", padding: "20px 24px" }}>
            {tab === "transcript" ? (
              <div style={{ border: `1px dashed ${C.borderStrong}`, borderRadius: 8, padding: "26px 18px", textAlign: "center", color: C.text3, fontSize: 12.5, lineHeight: 1.6 }}>
                Drop a .vtt, .srt or .txt transcript here, or paste it in.<br />Timestamps are stripped on import.
              </div>
            ) : structured ? <div className="sb-pop"><Markdown text={structured} /></div> : (
              <div style={{ color: C.text3, fontSize: 13, lineHeight: 1.65, maxWidth: "48ch" }}>
                Nothing structured yet. Run it on your live notes — they stay exactly as you typed them.
              </div>
            )}
          </div>

          {structured && (
            <div className="flex items-center sb-fade" style={{ gap: 8, padding: "10px 20px", borderTop: `1px solid ${C.border}`, background: C.canvas }}>
              <Btn small>Make flashcards</Btn><Btn small>Make a quiz</Btn>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}


/* ================= Revision ================= */

function Revision() {
  const [i, setI] = useState(0);
  const [flip, setFlip] = useState(false);
  const [done, setDone] = useState([]);
  const card = seedCards[i];
  const answer = (ok) => { setFlip(false); setTimeout(() => { setDone([...done, ok]); setI(i + 1); }, 180); };

  return (
    <div style={{ padding: "26px 32px", maxWidth: 620 }}>
      <div style={{ fontSize: 15, fontWeight: 600, marginBottom: 4 }}>Revision</div>
      <div style={{ fontSize: 12, color: C.text2 }}>Sets, relations and functions · Discrete Mathematics</div>

      <div style={{ marginTop: 18, padding: "12px 14px", borderRadius: 8, border: `1px solid ${C.border}`, background: C.canvas }}>
        <div style={{ fontSize: 11, fontWeight: 600, color: C.text2, marginBottom: 7 }}>Weak areas</div>
        <div className="flex" style={{ gap: 7, flexWrap: "wrap" }}>
          {["Equivalence classes", "Cardinality proofs", "Injective vs surjective"].map((t) => (
            <span key={t} style={{ fontSize: 11.5, padding: "3px 9px", borderRadius: 999, border: `1px solid ${C.border}`, background: C.surface }}>{t}</span>
          ))}
        </div>
      </div>

      {card ? (
        <>
          <div className="flex items-center justify-between" style={{ marginTop: 22, marginBottom: 10 }}>
            <span style={{ fontSize: 12, color: C.text2 }}>{i + 1} of {seedCards.length} due</span>
            <span style={{ fontSize: 11, color: C.text3 }}>Box {card.box}</span>
          </div>

          <div style={{ perspective: 1400 }}>
            <div className={`sb-flip ${flip ? "on" : ""}`} onClick={() => setFlip(!flip)}
              style={{ position: "relative", minHeight: 196, cursor: "pointer" }}>
              <div className="sb-face" style={{
                position: "absolute", inset: 0, padding: "34px 28px", borderRadius: 14,
                border: `1px solid ${C.border}`, background: C.surface, boxShadow: "0 4px 16px rgba(0,0,0,0.05)",
                display: "flex", flexDirection: "column", justifyContent: "center",
              }}>
                <div style={{ fontSize: 11, color: C.text3, marginBottom: 12 }}>Question</div>
                <div style={{ fontSize: 18, fontWeight: 550, lineHeight: 1.45, letterSpacing: "-0.01em" }}>{card.front}</div>
                <div style={{ fontSize: 11.5, color: C.text3, marginTop: 18 }}>Click to flip</div>
              </div>
              <div className="sb-face" style={{
                position: "absolute", inset: 0, padding: "34px 28px", borderRadius: 14, transform: "rotateY(180deg)",
                border: `1px solid ${C.border}`, background: C.surface, boxShadow: "0 4px 16px rgba(0,0,0,0.05)",
                display: "flex", flexDirection: "column", justifyContent: "center",
              }}>
                <div style={{ fontSize: 11, color: C.text3, marginBottom: 12 }}>Answer</div>
                <div style={{ fontFamily: SERIF, fontSize: 15.5, lineHeight: 1.55 }}>{card.back}</div>
              </div>
            </div>
          </div>

          <div className="flex" style={{ gap: 9, marginTop: 16, opacity: flip ? 1 : 0, pointerEvents: flip ? "auto" : "none", transition: "opacity 160ms ease" }}>
            <Btn onClick={() => answer(false)}>Again</Btn>
            <Btn primary icon="check" onClick={() => answer(true)}>Got it</Btn>
          </div>
        </>
      ) : (
        <div className="sb-pop" style={{ marginTop: 22, padding: "34px 24px", borderRadius: 14, textAlign: "center", border: `1px solid ${C.border}`, background: C.surface }}>
          <div style={{ fontSize: 15, fontWeight: 550 }}>Queue clear</div>
          <div style={{ fontSize: 12.5, color: C.text2, marginTop: 6 }}>{done.filter(Boolean).length} of {done.length} right. Next cards are due tomorrow.</div>
          <div style={{ marginTop: 14 }}><Btn small onClick={() => { setI(0); setDone([]); }}>Start again</Btn></div>
        </div>
      )}
    </div>
  );
}

/* ================= Portfolio ================= */

function Stat({ label, value, sub, warn }) {
  return (
    <div>
      <div style={{ fontSize: 11, color: C.text2 }}>{label}</div>
      <div className="flex items-baseline" style={{ gap: 5, marginTop: 2 }}>
        <span style={{ fontSize: 17, fontWeight: 600, color: warn ? C.drafting : C.text, letterSpacing: "-0.01em" }}>{value}</span>
        {sub && <span style={{ fontSize: 11.5, color: C.text3 }}>{sub}</span>}
      </div>
    </div>
  );
}

function Portfolio() {
  const [seg, setSeg] = useState(0);
  const segs = ["KSBs", "Evidence", "Off-the-job"];

  return (
    <div>
      <div style={{ padding: "14px 20px", borderBottom: `1px solid ${C.border}` }}>
        <div style={{ fontSize: 15, fontWeight: 600, marginBottom: 11 }}>Portfolio</div>
        <div style={{ position: "relative", display: "inline-flex", padding: 2, borderRadius: 8, background: C.canvas, border: `1px solid ${C.border}` }}>
          <div className="sb-pill" style={{
            position: "absolute", top: 2, left: 2, width: 104, height: "calc(100% - 4px)",
            borderRadius: 6, background: C.surface, boxShadow: "0 1px 2px rgba(0,0,0,0.07)",
            transform: `translateX(${seg * 104}px)`,
          }} />
          {segs.map((l, i) => (
            <button key={l} onClick={() => setSeg(i)} style={{
              position: "relative", width: 104, fontFamily: SANS, fontSize: 12, fontWeight: 500,
              padding: "4px 0", borderRadius: 6, border: "none", background: "transparent",
              color: seg === i ? C.text : C.text2, cursor: "pointer",
            }}>{l}</button>
          ))}
        </div>
      </div>

      {seg === 0 && (
        <div className="sb-fade">
          <div style={{ padding: "10px 20px", fontSize: 11.5, color: C.text2, background: C.accentSoft, borderBottom: `1px solid ${C.border}` }}>
            Placeholder codes. Import the real KSB list from Exeter at induction.
          </div>
          {["Knowledge", "Skill", "Behaviour"].map((cat) => (
            <div key={cat}>
              <SectionHeader title={cat} count={seedKSBs.filter((k) => k.cat === cat).length} />
              {seedKSBs.filter((k) => k.cat === cat).map((k) => {
                const col = k.n === 0 ? C.border : k.n < 3 ? C.drafting : C.done;
                return (
                  <div key={k.code} className="flex items-center" style={{ gap: 12, padding: "9px 20px", borderBottom: `1px solid ${C.border}` }}>
                    <span style={{ width: 34, fontSize: 12, fontWeight: 600, fontFamily: MONO }}>{k.code}</span>
                    <span style={{ flex: 1, fontSize: 12.5, color: k.n ? C.text : C.text2 }}>{k.text}</span>
                    <div className="flex" style={{ gap: 3 }}>
                      {[0, 1, 2].map((n) => <span key={n} style={{ width: 14, height: 4, borderRadius: 2, background: n < k.n ? col : C.border }} />)}
                    </div>
                    <span style={{ width: 58, textAlign: "right", fontSize: 11.5, color: C.text3 }}>{k.n === 0 ? "none" : `${k.n} item${k.n > 1 ? "s" : ""}`}</span>
                  </div>
                );
              })}
            </div>
          ))}
        </div>
      )}

      {seg === 1 && (
        <div className="sb-fade">
          <div className="flex items-center justify-between" style={{ padding: "10px 20px" }}>
            <span style={{ fontSize: 12, color: C.text2 }}>{seedEvidence.length} items</span>
            <Btn small primary icon="plus">New evidence</Btn>
          </div>
          {seedEvidence.map((e) => (
            <div key={e.id} className="flex items-start" style={{ gap: 12, padding: "11px 20px", borderTop: `1px solid ${C.border}` }}>
              <div style={{ flex: 1 }}>
                <div className="flex items-center" style={{ gap: 8 }}>
                  <span style={{ fontSize: 13, fontWeight: 500 }}>{e.title}</span>
                  {e.conf && <span style={{ fontSize: 10.5, color: C.text2, padding: "1px 7px", borderRadius: 999, border: `1px solid ${C.border}`, background: C.canvas }}>work · no AI</span>}
                </div>
                <div className="flex items-center" style={{ gap: 6, marginTop: 6 }}>
                  {e.ksbs.map((k) => <span key={k} style={{ fontSize: 10.5, fontFamily: MONO, fontWeight: 600, color: C.accent, padding: "1px 6px", borderRadius: 4, background: C.accentSoft }}>{k}</span>)}
                  <span style={{ fontSize: 11.5, color: C.text3 }}>· {e.src}</span>
                </div>
              </div>
              <span style={{ fontSize: 11.5, color: C.text3 }}>{e.date}</span>
            </div>
          ))}
        </div>
      )}

      {seg === 2 && (
        <div className="sb-fade">
          <div className="flex items-center justify-between" style={{ padding: "14px 20px" }}>
            <div className="flex items-center" style={{ gap: 22 }}>
              <Stat label="This week" value="4.5 h" sub="of 6" warn />
              <Stat label="This month" value="10 h" />
              <Stat label="Total logged" value="38.5 h" />
            </div>
            <div className="flex" style={{ gap: 8 }}><Btn small>Export</Btn><Btn small primary icon="clock">Log hours</Btn></div>
          </div>
          <SectionHeader title="Entries" count={seedOTJ.length} />
          {seedOTJ.map((o) => (
            <div key={o.id} className="flex items-center" style={{ gap: 12, height: 38, padding: "0 20px", borderBottom: `1px solid ${C.border}` }}>
              <span style={{ width: 52, fontSize: 12, color: C.text2 }}>{o.date}</span>
              <span style={{ width: 44, fontSize: 12, fontWeight: 550, fontFamily: MONO }}>{o.hours}h</span>
              <span style={{ width: 92, fontSize: 11.5, color: C.text2 }}>{o.cat}</span>
              <span className="truncate" style={{ flex: 1, fontSize: 12.5 }}>{o.desc}</span>
              {o.linked && <span style={{ fontSize: 11, color: C.accent }}>evidence</span>}
            </div>
          ))}
          <div style={{ padding: "12px 20px", fontSize: 11.5, color: C.text3 }}>
            Export columns are configurable — set them once Exeter gives you their template.
          </div>
        </div>
      )}
    </div>
  );
}

/* ================= Block mode ================= */

function BlockMode({ open }) {
  const days = ["Tue 22 Sept", "Wed 23 Sept", "Thu 24 Sept"];
  const qs = [
    { q: "Do we need to prove reflexivity formally in the coursework?", d: "Wed" },
    { q: "Is induction examined in term 1 or term 2?", d: "Wed" },
    { q: "Which Python version is graded against?", d: "Tue" },
  ];
  return (
    <div className="flex flex-col" style={{ height: "100%" }}>
      <div style={{ padding: "14px 20px", borderBottom: `1px solid ${C.border}` }}>
        <div style={{ fontSize: 15, fontWeight: 600 }}>Induction & Block 1</div>
        <div style={{ fontSize: 12, color: C.text2, marginTop: 2 }}>22–24 September · Programming, Discrete Maths, Professional Development 1</div>
      </div>
      <div className="flex" style={{ flex: 1, minHeight: 0 }}>
        {days.map((dl, di) => (
          <div key={dl} style={{ flex: 1, borderRight: di < 2 ? `1px solid ${C.border}` : "none", display: "flex", flexDirection: "column", minWidth: 0 }}>
            <div style={{ padding: "9px 16px", fontSize: 12, fontWeight: 600, color: C.text2, borderBottom: `1px solid ${C.border}`, background: C.canvas }}>{dl}</div>
            <div style={{ padding: 12, flex: 1, overflowY: "auto" }}>
              {BLOCK_SESSIONS.filter((s) => s.day === di).map((s) => (
                <button key={s.id} onClick={() => open(s)} className="w-full text-left sb-btn"
                  style={{ padding: "11px 13px", marginBottom: 9, borderRadius: 9, border: `1px solid ${C.border}`, background: C.surface, cursor: "pointer", fontFamily: SANS }}>
                  <div style={{ fontSize: 11, color: C.text3, fontFamily: MONO }}>{s.time}</div>
                  <div style={{ fontSize: 13, fontWeight: 550, marginTop: 3 }}>{s.title}</div>
                  <div style={{ marginTop: 6 }}><ModuleChip id={s.module} /></div>
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>
      <div style={{ borderTop: `1px solid ${C.border}`, background: C.accentSoft, padding: "12px 20px" }}>
        <div style={{ fontSize: 11.5, fontWeight: 600, color: C.accent, marginBottom: 7 }}>Ask the tutor before you leave · {qs.length}</div>
        <div className="flex" style={{ gap: 22, flexWrap: "wrap" }}>
          {qs.map((q, i) => <span key={i} style={{ fontSize: 12.5 }}>{q.q} <span style={{ color: C.text3 }}>· {q.d}</span></span>)}
        </div>
      </div>
      <div className="flex items-center" style={{ gap: 10, padding: "10px 20px", borderTop: `1px solid ${C.border}`, background: C.surface }}>
        <input placeholder="Capture a thought, a question, or evidence…"
          style={{ flex: 1, border: "none", outline: "none", fontFamily: SANS, fontSize: 13, background: "transparent", color: C.text }} />
        <span style={{ fontSize: 11, color: C.text3, fontFamily: MONO }}>⏎</span>
      </div>
    </div>
  );
}

/* ================= command palette ================= */

function Palette({ context, onClose, go }) {
  const [q, setQ] = useState("");
  const [ans, setAns] = useState(null);
  const [busy, setBusy] = useState(false);
  const ref = useRef(null);
  useEffect(() => { ref.current?.focus(); }, []);

  const actions = [
    { g: "Actions", label: "Check this draft against the rubric" },
    { g: "Actions", label: "Outline this assignment" },
    { g: "Actions", label: "Log off-the-job hours", run: () => go("portfolio") },
    { g: "Actions", label: "New evidence", run: () => go("portfolio") },
    { g: "Go to", label: "Discrete Mathematics", run: () => go("session") },
    { g: "Go to", label: "Revision queue", run: () => go("revision") },
    { g: "Go to", label: "Induction & Block 1", run: () => go("block") },
  ];
  const filtered = actions.filter((a) => a.label.toLowerCase().includes(q.toLowerCase()));
  const ask = () => {
    setBusy(true);
    setTimeout(() => {
      setBusy(false);
      setAns("An equivalence relation is reflexive, symmetric and transitive. The payoff is that those three properties together carve a set into disjoint equivalence classes — every element lands in exactly one.\n\nFor the Programming coursework this matters only if you're modelling grouping behaviour. Otherwise it belongs in the Discrete Maths notes.");
    }, 850);
  };

  return (
    <div onClick={onClose} className="sb-fade" style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.14)", display: "flex", alignItems: "flex-start", justifyContent: "center", paddingTop: 110, zIndex: 50 }}>
      <div onClick={(e) => e.stopPropagation()} className="sb-pop"
        style={{ width: 560, maxWidth: "92vw", borderRadius: 14, background: C.surface, border: `1px solid ${C.border}`, boxShadow: "0 12px 40px rgba(0,0,0,0.16)", overflow: "hidden" }}>
        <div className="flex items-center" style={{ gap: 10, padding: "12px 16px" }}>
          <span style={{ fontSize: 12, fontFamily: MONO, color: C.text3 }}>⌘K</span>
          {context && <span style={{ fontSize: 11.5, color: C.accent, padding: "2px 9px", borderRadius: 6, background: C.accentSoft, whiteSpace: "nowrap" }}>{context}</span>}
          <input ref={ref} value={q} onChange={(e) => { setQ(e.target.value); setAns(null); }}
            onKeyDown={(e) => { if (e.key === "Enter" && q && !filtered.length) ask(); }}
            placeholder="Ask anything, or jump somewhere…"
            style={{ flex: 1, border: "none", outline: "none", fontFamily: SANS, fontSize: 14, background: "transparent", color: C.text }} />
        </div>
        <div style={{ borderTop: `1px solid ${C.border}`, maxHeight: 340, overflowY: "auto" }}>
          {q && !filtered.length && !ans && !busy && (
            <button onClick={ask} className="w-full flex items-center text-left" style={{ gap: 10, padding: "11px 16px", border: "none", background: "transparent", cursor: "pointer", fontFamily: SANS }}>
              <span style={{ fontSize: 12, color: C.accent, fontWeight: 600 }}>Ask AI</span>
              <span className="truncate" style={{ fontSize: 13 }}>{q}</span>
            </button>
          )}
          {busy && <div style={{ padding: 16, fontSize: 13, color: C.text3 }}>Thinking…</div>}
          {ans && (
            <div className="sb-fade" style={{ padding: "14px 16px" }}>
              <div style={{ fontFamily: SERIF, fontSize: 14, lineHeight: 1.6, whiteSpace: "pre-wrap" }}>{ans}</div>
              <div className="flex items-center justify-between" style={{ marginTop: 14 }}>
                <div className="flex" style={{ gap: 8 }}><Btn small>Save to notes</Btn><Btn small>Make a card</Btn></div>
                <span style={{ fontSize: 11, color: C.text3 }}>logged to AI use · ~£0.004</span>
              </div>
            </div>
          )}
          {["Actions", "Go to"].map((g) => {
            const rows = filtered.filter((a) => a.g === g);
            if (!rows.length) return null;
            return (
              <div key={g} style={{ padding: "6px 0" }}>
                <div style={{ padding: "4px 16px", fontSize: 11, fontWeight: 600, color: C.text3 }}>{g}</div>
                {rows.map((a) => <PaletteRow key={a.label} label={a.label} onClick={() => { a.run?.(); onClose(); }} />)}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function PaletteRow({ label, onClick }) {
  const [h, setH] = useState(false);
  return (
    <button onClick={onClick} className="w-full text-left" onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
      style={{ padding: "7px 16px", border: "none", background: h ? C.rowHover : "transparent", fontSize: 13, color: C.text, fontFamily: SANS, cursor: "pointer" }}>{label}</button>
  );
}

/* ================= sidebar ================= */

/* Hollow outline icons — SF Symbols equivalents (spec 9, The sidebar).
   In the Swift build these are SF Symbols, not an icon font. */
const Icon = ({ name, c, size = 16 }) => {
  const P = { width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: c,
              strokeWidth: 1.6, strokeLinecap: "round", strokeLinejoin: "round" };
  const paths = {
    today: <><circle cx="12" cy="12" r="4" /><path d="M12 2.5v2M12 19.5v2M5.2 5.2l1.4 1.4M17.4 17.4l1.4 1.4M2.5 12h2M19.5 12h2M5.2 18.8l1.4-1.4M17.4 6.6l1.4-1.4" /></>,
    assignments: <><path d="M10 5.5h9M10 12h9M10 18.5h9" /><path d="M4 5.5l1.3 1.3L7.8 4.3" /><path d="M4 12l1.3 1.3L7.8 10.8" /><path d="M4 18.5l1.3 1.3L7.8 17.3" /></>,
    modules: <><path d="M4 5.8A2.8 2.8 0 0 1 6.8 3H19.5v15.5H6.8A2.8 2.8 0 0 0 4 21.3z" /><path d="M4 18.3A2.8 2.8 0 0 1 6.8 15.5H19.5" /></>,
    revision: <><rect x="8.5" y="3" width="11.5" height="13.5" rx="2.2" /><path d="M16 19.8a1.7 1.7 0 0 1-1.7 1.7H5.7A1.7 1.7 0 0 1 4 19.8V7.6" /></>,
    portfolio: <><path d="M12 2.6l2.3 1.5 2.7-.3 1.1 2.5 2.3 1.5-.8 2.6.8 2.6-2.3 1.5-1.1 2.5-2.7-.3L12 18.8l-2.3-1.6-2.7.3-1.1-2.5-2.3-1.5.8-2.6-.8-2.6 2.3-1.5 1.1-2.5 2.7.3z" /><path d="M9.2 10.8l1.9 1.9 3.7-3.7" /></>,
    pencil: <><path d="M4 20h4L19.5 8.5a2.1 2.1 0 0 0-3-3L5 17z" /><path d="M14.5 6.5l3 3" /></>,
    check: <><path d="M5 12.5l4.5 4.5L19 7.5" /></>,
    plus: <><path d="M12 5v14M5 12h14" /></>,
    clock: <><circle cx="12" cy="12" r="8.5" /><path d="M12 7.2V12l3.2 2" /></>,
    sparkle: <><path d="M12 3.5l1.7 4.6 4.6 1.7-4.6 1.7L12 16.1l-1.7-4.6L5.7 9.8l4.6-1.7z" /><path d="M18.5 15.5l.7 1.9 1.9.7-1.9.7-.7 1.9-.7-1.9-1.9-.7 1.9-.7z" /></>,
    collapse: <><rect x="3" y="4" width="18" height="16" rx="2.4" /><path d="M9.5 4v16" /></>,
    upload: <><path d="M12 16V4.5" /><path d="M8 8.5L12 4.5l4 4" /><path d="M4.5 14.5v3.2A1.8 1.8 0 0 0 6.3 19.5h11.4a1.8 1.8 0 0 0 1.8-1.8v-3.2" /></>,
  };
  return <svg {...P} style={{ flexShrink: 0 }}>{paths[name]}</svg>;
};

/* App mark: the term strip motif — campus blocks, session ticks, a submission ring.
   In the Swift build this is the .icns, drawn on the macOS icon grid (spec 9). */
const AppMark = ({ size = 20 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ flexShrink: 0 }}>
    <rect x="1.5" y="1.5" width="21" height="21" rx="6" fill={C.accent} />
    <path d="M4.5 12h15" stroke="#fff" strokeOpacity="0.45" strokeWidth="1" strokeLinecap="round" />
    <path d="M6 8.2v7.6M8 8.2v7.6M10 8.2v7.6" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" />
    <path d="M13.2 10.4v3.2M15.4 10.4v3.2" stroke="#fff" strokeOpacity="0.6" strokeWidth="1" strokeLinecap="round" />
    <circle cx="18.4" cy="12" r="2.1" fill="none" stroke="#fff" strokeWidth="1.5" />
  </svg>
);

function SideRow({ active, icon, label, onClick, collapsed }) {
  const [h, setH] = useState(false);
  const col = active ? C.accent : C.text2;
  return (
    <button onClick={onClick} onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
      title={collapsed ? label : undefined}
      className="w-full flex items-center"
      style={{
        gap: 10, height: 28, padding: "0 8px", borderRadius: 6, border: "none",
        justifyContent: collapsed ? "center" : "flex-start",
        background: active ? C.accentSoft : h ? "rgba(0,0,0,0.035)" : "transparent",
        color: col, fontSize: 13, fontWeight: active ? 550 : 450,
        fontFamily: SANS, cursor: "pointer", textAlign: "left",
        transition: "background-color 120ms ease, color 120ms ease",
      }}>
      <span style={{ width: 20, display: "flex", justifyContent: "center", flexShrink: 0 }}><Icon name={icon} c={col} /></span>
      {!collapsed && <span style={{ whiteSpace: "nowrap" }}>{label}</span>}
    </button>
  );
}

function Sidebar({ view, setView, expanded, setExpanded, open, collapsed, setCollapsed }) {
  const items = [
    ["today", "Today", "today"], ["assignments", "Assignments", "assignments"],
    ["modules", "Modules & notes", "modules"], ["revision", "Revision", "revision"],
    ["portfolio", "Portfolio", "portfolio"],
  ];
  return (
    <div style={{
      width: collapsed ? 56 : 228, flexShrink: 0, display: "flex", flexDirection: "column", padding: "14px 8px",
      transition: "width 220ms cubic-bezier(.3,.9,.3,1)", overflow: "hidden",
      /* Approximates the macOS .sidebar vibrancy. The real build uses
         NSVisualEffectView with .behindWindow blending. */
      background: "rgba(249,249,248,0.72)",
      backdropFilter: "blur(30px) saturate(180%)",
      WebkitBackdropFilter: "blur(30px) saturate(180%)",
      borderRight: "1px solid rgba(0,0,0,0.07)",
    }}>
      <div className="flex items-center justify-between" style={{ padding: "0 6px 16px", height: 22 }}>
        <div className="flex items-center" style={{ gap: 9, minWidth: 0 }}>
          <AppMark size={20} />
          <span style={{ fontSize: 13, fontWeight: 600, opacity: collapsed ? 0 : 1, transition: "opacity 80ms ease", whiteSpace: "nowrap" }}>StudyBot</span>
        </div>
        {!collapsed && (
          <button onClick={() => setCollapsed(true)} title="Hide sidebar  ⌥⌘S"
            className="sb-btn" style={{ border: "none", background: "transparent", cursor: "pointer", padding: 2, lineHeight: 0 }}>
            <Icon name="collapse" c={C.text3} size={15} />
          </button>
        )}
      </div>

      {items.map(([id, label, icon]) => {
        const active = view === id || (id === "modules" && view === "session");
        return (
          <div key={id}>
            <SideRow active={active} icon={icon} label={label} collapsed={collapsed} onClick={() => setView(id)} />
            {!collapsed && id === "modules" && (view === "modules" || view === "session") && (
              <div className="sb-fade" style={{ padding: "2px 0 8px 0" }}>
                {[1, 2, 3].map((t) => (
                  <div key={t}>
                    <div style={{ padding: "7px 8px 3px 38px", fontSize: 10.5, fontWeight: 600, color: C.text3 }}>Term {t}</div>
                    {MODULES.filter((m) => m.term === t || (m.term === 0 && t === 1)).map((m) => (
                      <div key={m.id}>
                        <button onClick={() => setExpanded(expanded === m.id ? null : m.id)} className="w-full flex items-center"
                          title={`${m.code} ${m.name}`}
                          style={{ gap: 8, padding: "4px 8px 4px 38px", border: "none", background: "transparent", fontSize: 12.5, color: C.text2, fontFamily: SANS, cursor: "pointer", textAlign: "left" }}>
                          <span style={{ width: 6, height: 6, borderRadius: 3, background: m.colour, flexShrink: 0 }} />
                          <span className="truncate">{m.name}</span>
                        </button>
                        {expanded === m.id && BLOCK_SESSIONS.filter((s) => s.module === m.id).map((s) => (
                          <button key={s.id} onClick={() => open(s)} className="w-full text-left truncate sb-fade"
                            style={{ padding: "3px 8px 3px 52px", border: "none", background: "transparent", fontSize: 12, color: C.text3, fontFamily: SANS, cursor: "pointer" }}>{s.title}</button>
                        ))}
                      </div>
                    ))}
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })}

      <div style={{ flex: 1 }} />
      {collapsed ? (
        <button onClick={() => setCollapsed(false)} title="Show sidebar  ⌥⌘S" className="sb-btn"
          style={{ border: "none", background: "transparent", cursor: "pointer", padding: "6px 0", display: "flex", justifyContent: "center" }}>
          <Icon name="collapse" c={C.text3} size={15} />
        </button>
      ) : (
        <div style={{ padding: "10px 11px", borderRadius: 8, border: "1px solid rgba(0,0,0,0.06)", background: "rgba(255,255,255,0.55)" }}>
          <div style={{ fontSize: 11, color: C.text2, marginBottom: 3 }}>Year 1 · Term 1</div>
          <div style={{ fontSize: 12, fontWeight: 600, whiteSpace: "nowrap" }}>Induction 22 Sept</div>
          <div style={{ fontSize: 11, color: C.accent, marginTop: 2 }}>in 8 days</div>
        </div>
      )}
    </div>
  );
}

/* ================= shell ================= */

export default function StudyBot() {
  const [view, setView] = useState("today");
  const [expanded, setExpanded] = useState("dm");
  const [session, setSession] = useState(BLOCK_SESSIONS[2]);
  const [sel, setSel] = useState(null);
  const [palette, setPalette] = useState(false);
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    const h = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") { e.preventDefault(); setPalette(true); }
      if ((e.metaKey || e.ctrlKey) && e.altKey && e.key.toLowerCase() === "s") { e.preventDefault(); setCollapsed((c) => !c); }
      if (e.key === "Escape") { setPalette(false); setSel(null); }
      if ((e.metaKey || e.ctrlKey) && ["1", "2", "3", "4", "5"].includes(e.key)) {
        e.preventDefault(); setSel(null);
        setView(["today", "assignments", "modules", "revision", "portfolio"][+e.key - 1]);
      }
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, []);

  const open = (s) => { setSession(s); setView("session"); setExpanded(s.module); };
  const context = sel ? `${sel.title}` : view === "session" ? session.title : null;

  return (
    <div style={{ fontFamily: SANS, color: C.text, height: "100vh", display: "flex", overflow: "hidden", WebkitFontSmoothing: "antialiased",
      background: "linear-gradient(135deg, #EDEFF7 0%, #F7F6F3 45%, #EFF3F0 100%)" }}>
      <Motion />
      <Sidebar view={view} setView={(v) => { setView(v); setSel(null); }} expanded={expanded} setExpanded={setExpanded} open={open}
        collapsed={collapsed} setCollapsed={setCollapsed} />
      <div className="flex" style={{ flex: 1, minWidth: 0, background: C.surface }}>
        <div style={{ flex: 1, overflowY: "auto", minWidth: 0 }}>
          {view === "today" && <Today setView={setView} openBlock={() => setView("block")} />}
          {view === "assignments" && <Assignments onOpen={setSel} selected={sel} />}
          {view === "modules" && (
            <div style={{ padding: "26px 32px", color: C.text2, fontSize: 13, lineHeight: 1.7, maxWidth: 470 }}>
              <div style={{ fontSize: 15, fontWeight: 600, color: C.text, marginBottom: 8 }}>Modules & notes</div>
              Seven year-one modules, imported from the programme calendar. Discrete Maths is expanded —
              try "Sets, relations and functions".
            </div>
          )}
          {view === "session" && <SessionView session={session} />}
          {view === "revision" && <Revision />}
          {view === "portfolio" && <Portfolio />}
          {view === "block" && <BlockMode open={open} />}
        </div>
        {sel && <AssignmentPanel a={sel} onClose={() => setSel(null)} />}
      </div>
      {palette && <Palette context={context} onClose={() => setPalette(false)} go={(v) => { setSel(null); setView(v); }} />}
      <button onClick={() => setPalette(true)} className="sb-btn"
        style={{ position: "fixed", bottom: 18, right: 18, padding: "7px 13px", borderRadius: 999, border: `1px solid ${C.border}`, background: C.surface, color: C.text2, fontSize: 12, fontFamily: SANS, cursor: "pointer", boxShadow: "0 4px 16px rgba(0,0,0,0.08)" }}>⌘K</button>
    </div>
  );
}
