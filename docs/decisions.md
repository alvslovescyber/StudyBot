# Decisions

Places where the spec was wrong, silent, or contradicted by the real calendar, and what the
code does instead. One entry each: what the spec said, what we did, why. Read this before
"simplifying" anything it mentions.

Entries are dated. Newest at the bottom.

---

## 2026-09-14 · Models are value types in Core; SwiftData lives only in Kit

**Spec said (v1.0):** §4 opened with "SwiftData `@Model` classes. Relationships are
bidirectional with explicit inverses." §3.2 said `StudyBotCore/Models/` holds value types.

**Decision:** Core holds plain `struct`s. Relationships are stored as ids, not nested
objects. Kit wraps the structs in `@Model` classes and converts at that boundary. Nothing
outside Kit knows SwiftData exists.

**Why:** the same definitions compile into the Vapor server, which cannot use SwiftData.
A value type also cannot own a two-way object graph, so ids are the only honest
representation of a relationship in Core. The spec now says this (§4).

## 2026-09-14 · Eight sync fields, defined once

**Spec said:** §3.4 listed six sync fields; §4 listed eight (adding `createdAt` and `seq`).

**Decision:** eight, in one `SyncMetadata` struct embedded in every syncable type.

**Why:** §4 is the more specific section and `seq` is the cursor the whole sync design rests
on. One struct means the engine, the server and the tests share one definition of
"syncable"; a renamed field breaks the build rather than failing at runtime.

## 2026-09-14 · `ProgrammeEvent.cancelledAt`

**Spec said:** §4A required removed events to be "marked cancelled rather than deleted so any
notes attached to them survive", but the §4 `ProgrammeEvent` listing had no field for it.

**Decision:** added `cancelledAt: Date?`. The importer sets it when a reissued calendar no
longer contains the UID and clears it if the event reappears. The id never changes.

## 2026-09-14 · `WallClockTime` for anything scheduled by the clock

**Spec said:** `NotificationPrefs.morningPlanTime: Date`, while §4's own rule required
clock-scheduled things to be stored "in local wall-clock terms" so BST does not shift them.

**Decision:** a `WallClockTime(hour:minute:)` supporting type, used for the morning plan and
required for the 07:00 Monday prep and 18:00 Sunday review when those are built.

**Why:** a `Date` is an instant. "Seven in the morning" is not an instant; it resolves to a
different instant on either side of a clock change. Resolve to an instant only at scheduling
time, in Europe/London.

## 2026-09-14 · `archivedAs` on accepted records too

**Spec said:** §3.5's `conflicts` named where the losing version was archived. `accepted`
carried only `version` and `seq`.

**Decision:** `SyncAccepted.archivedAs: String?`. Set when the client's write was accepted
under last-write-wins but overwrote a concurrent server-side edit.

**Why:** the conflict list only covers the direction where the client loses. Without this,
the server-side loser would be archived with nothing telling the client, which is exactly the
silent loss §3.4 exists to prevent.

## 2026-09-14 · 26 modules, not 21

**Spec said:** first run shows "21 modules".

**Decision:** 26. Seven year-1, seven year-2, twelve year-3 (ten specialism options, the
Synoptic Project, Professional Development 3). The ten options are seeded with
`isSpecialismOption: true`; two get chosen and eight archived at the start of year 3.

**Why:** that is what the calendar contains. `ModuleSeederTests` pins the count.

## 2026-09-14 · Term boundaries come from module sets, not blocks and not gaps

**Spec said:** term dates are "derived from the first and last programme event" and §1
described "a short on-campus block at the start of each term". Nothing said which events
belong to which term.

**Decision:** a term is the contiguous run of module-bearing events sharing one module set.
Submissions, Gateway and the EPA window with no modules join the term before them and may
extend its end. Bank holidays, closures and the un-moduled summer reading weeks never do,
so real gaps exist between terms. Implemented in `TermCalendar`, pinned by
`TermCalendarTests` (all nine boundaries).

**Why the block rule is wrong:** the file contradicts it. The 19 April 2027 reading week and
the 26 April 2027 session already carry term-3 modules; Block 3 is 4–6 May. Same shape in 2028.

**Why a gap rule is wrong:** year 3's final term contains a 35-day gap with no sessions,
between 18 April and 23 May 2029. A "long gap means new term" rule cuts that term in two.
The module-set rule survives because both sides of the gap carry the same modules.

## 2026-09-14 · Year-3 term 3 starts at the first session after Easter

**Spec said:** nothing. The calendar gives no signal, because the Synoptic Project and the
second-specialism options run across terms 2 and 3, so the module set changes only once.

**Decision:** when a year has fewer than three module-set runs, split its last run at the
first teaching session after that year's March/April bank holidays. That is 18 April 2029,
matching the April term-3 starts in years 1 and 2. Encoded as the rule, not the date. Open
question 13 is to confirm it with Exeter.

## 2026-09-14 · Second-specialism options span the year

**Spec said:** only Professional Development and the Synoptic Project span terms.

**Decision:** `COM3106DA`, `COM3108DA`, `COM3110DA`, `COM3112DA` and `COM3114DA` also carry
`spansYear: true`.

**Why:** they appear on every year-3 event from 8 January to 23 May 2029, straight across the
term boundary. The data does not separate them from the Synoptic Project. May be a quirk of
how the calendar was written; confirm alongside question 13.

## 2026-09-14 · Induction merges into Block 1

**Spec said:** §4A's table listed Induction (22 Sep) and Block 1 (23–24 Sep) as separate
rows; the §6.1 mockup said "Block 1 starts in 8 days · 22–24 Sept".

**Decision:** adjacent campus-kind days merge into one `CampusBlock`. Block 1 is 22–24
September. No special case for induction; the merge is by adjacency.

**Also:** induction counts as a campus day for `WorkingDays`. You cannot do self-directed
work on it.

## 2026-09-14 · Submission stubs are titled by date, with no module

**Spec said:** the calendar-created assignment is "titled from the module it belongs to".

**Decision:** "Submission due 15 October 2026", `moduleID == nil`, until ELE2 supplies the
brief.

**Why:** of the 30 submission events, 20 name all three of their term's modules and 10 name
none. Guessing would be wrong about two-thirds of the time. The stub stays honest about not
knowing.

## 2026-09-14 · Deterministic ids for calendar-derived records

**Spec said:** ids are "client-generated, stable forever". Nothing about two clients
generating the same record independently.

**Decision:** `StableID` derives UUIDs from stable inputs: programme events from the ICS UID,
modules from their code, terms from year and number, assignment stubs from the event UID,
Settings from a fixed name. `StableIDTests` pins one value so a change is loud.

**Why:** both Macs import the bundled calendar on their own (§4 says `ProgrammeEvent` is
never synced). If each minted random ids for "COM1018DA" they would disagree about which
record is which, and the terms and modules that *are* synced would duplicate.

## 2026-09-14 · Tests live inside each package

**Brief said:** a `StudyBotTests/` folder at the repo root.

**Decision:** `Packages/<name>/Tests/`, using Swift Testing.

**Why:** `swift test` only runs test targets declared in a package manifest. A root folder
would need a third package that rebuilds both others. Swift Testing ships in the Swift 6
toolchain and needs no Xcode.

## 2026-09-14 · UKCalendar lives in Core, not Kit

**Plan said:** Kit.

**Decision:** Core.

**Why:** the server's Sunday digest and week arithmetic need exactly the same en-GB,
Europe/London, Monday-first calendar. Core is the only place both sides can see.
