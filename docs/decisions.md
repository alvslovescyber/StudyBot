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

## 2026-09-15 · Persisted rows are "sync columns + index columns + body blob"

**Spec said (§4, revised):** Kit wraps the Core structs in `@Model` classes; "SwiftData
relationships there are bidirectional with explicit inverses."

**Decision:** each `@Model` row holds the eight sync fields as real columns, a handful of
type-specific index columns (module id, due date, status, and so on), the whole Core value as
a JSON `body`, and an `unknownFields` blob. Relationships stay as id columns; there are no
SwiftData relationship properties or inverses.

**Why:** the body is the record and the columns are derived from it on every write, so the
struct-to-model conversion is one encode and one decode, and adding a field to a Core struct
needs no SwiftData migration at all. Relationship graphs would need object lookups at
conversion time and inverse maintenance with no consumer yet, and the sync envelope speaks in
ids anyway. Cascading deletion (§16 "Deletion means deletion") will be explicit code in the
stores, where it can be tested, rather than implicit SwiftData behaviour. Revisit if a query
ever genuinely needs a join; so far every planned query is served by the index columns.

## 2026-09-15 · The store's public API mentions only Core types

**Brief said:** "if a `@Model` type appears in a signature in Core or leaks toward the UI
packages, that's the bug."

**Decision:** the model classes are `internal` to StudyBotKit. `Database` is generic over a
public marker protocol `Persistable` and looks up the backing model in an internal registry.
The compiler, not a convention, stops a view from reaching a `@Model`.

## 2026-09-15 · Unknown fields live beside the value, not inside it

**Decision:** `StoredRecord<T>` pairs a Core value with `unknownFields: [String: JSONValue]`.
Saving a bare value keeps whatever unknown fields the row already had; only saving a
`StoredRecord` replaces them. `RecordFields` splits wire fields into known and unknown and
merges them back.

**Why:** putting an unknown-fields map on every Core struct would leak a wire concern into the
models and their equality. Keeping it at the storage boundary means the loss scenario in
§3.10a (newer Mac writes, stale Mac reads and writes back) is a store round trip, and that is
what `UnknownFieldPreservationTests` exercises, on disk and across a reopen.

## 2026-09-15 · Wire dates carry milliseconds when they have them

**Spec said:** §3.5's example uses second-precision ISO 8601 (`"2026-10-02T19:44:10Z"`).

**Decision:** `SyncCoding` writes whole-second dates exactly as the spec shows and writes
`.250Z`-style milliseconds only when a date has a fractional part. Decoding accepts both.

**Why:** `updatedAt` decides last-write-wins. Two edits inside the same second on two Macs
would tie under second precision, and a store round trip through the wire format would
silently change a timestamp. The store itself uses seconds-since-1970 doubles for the same
reason.

## 2026-09-15 · Dark mode from milestone three, not "light only in v1"

**Spec said (§9):** "Light mode only in v1."

**Decision:** every colour token is adaptive. The light values are §9 verbatim; the dark values
are the same palette re-pitched for a dark canvas (`SBColor`). Module colours are mid-tone and
do not change. Pinned by `TokenTests` under both appearances.

**Why:** Alvis's Macs run dark, and a light-only app drew light tokens over a dark window, which
looked broken on first sight (15 Sep 2026). Following the system appearance is cheaper than
explaining why the app does not.

## 2026-09-15 · The sidebar is our own view, not NavigationSplitView

**Spec said (§9):** `NavigationSplitView` "gives this by default".

**Decision:** `RootView` is an `HStack`: a fixed-width `SidebarChrome` (228pt, or the 56pt rail)
over an `NSVisualEffectView` with the `.sidebar` material and `.behindWindow` blending, a
hairline, then the opaque content pane. `⌥⌘S` toggles the width with the segmented-control spring.

**Why:** `NavigationSplitView` sized the sidebar itself, ignoring the requested width and
squeezing it when the detail panel opened. The spec's intent is Finder's sidebar at a known
width; owning the layout is the only way to guarantee it.

## 2026-09-15 · No em dashes anywhere in the interface

**Spec copy used them** ("StudyBot — your programme is already loaded.", "… — show all").

**Decision:** none in user-visible text. Sentences end and start instead ("Your programme is
already loaded.", "27 more submissions in later terms. Show all"). Empty cells draw nothing
rather than a dash. Date ranges keep the en dash ("22–24 Sept"), which is punctuation for a
range, not a pause.

**Why:** Alvis asked for it, 15 Sep 2026. It also reads cleaner in a Linear/Notion register.

## 2026-09-15 · Today is a ScrollView; the blank capture was the capture's fault

**Observation:** in the layer-tree snapshot, Today rendered blank inside a `ScrollView`. A
real screenshot of the same build (`Tools/screenshots.sh`, once Screen Recording was
available) shows it rendering correctly. The layer render cannot show SwiftUI's scroll view
content in that arrangement; the app was never at fault.

**Decision:** Today is a `ScrollView`, as §6.1 (the term strip below the fold) and §16 (the
largest accessibility text sizes without clipping on a 13-inch screen) require. Screenshots
in `docs/screenshots` are now real captures.

**Still open:** §9's exact point sizes do not scale with Dynamic Type, so §16's "largest
accessibility sizes" is only met by the system controls today. `SBType` needs a scale factor
per `DynamicTypeSize` before that row can be called done.

## 2026-09-15 · The brief is a drop zone until a brief exists

**Spec said (§6.2):** "The calendar gave the date and the module. The brief comes from ELE2 —
drop the PDF here when it appears."

**Decision:** the drop zone shows in read and edit mode alike while `briefText` is nil; a text
editor appears only once there is brief text to correct. The copy says "the date and the
module" only when the calendar did give a module; for the 30 stubs it did not, so it says
"the date". The drop action itself lands with the PDF importer.

**Why:** a brief is a file that arrives, not something typed, and the copy must not claim a
module the record does not have.

## 2026-09-15 · A debug snapshot tour instead of screen recording

**Decision:** `SnapshotTour` (DEBUG only) walks the app when launched with
`STUDYBOT_SNAPSHOT_DIR`, writing a PNG per step by rendering the window's layer tree, in light
or dark via `STUDYBOT_SNAPSHOT_APPEARANCE`. `docs/screenshots` holds the latest set.

**Why:** the build must be judged against the real import (milestone-three brief), and
screen-recording permission is not available to a build launched from a terminal. Layer
rendering needs no permission. Its limits: behind-window vibrancy shows as flat `canvas`, and
the Today question above.
