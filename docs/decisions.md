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

**Resolved the same day:** the spec's Typography patch made §9's sizes base values; see
"One scale factor for text and the layout that follows it" below.

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

## 2026-09-15 · The merge rule is one pure function, run in three places

**Decision:** `SyncMerge.decide(incoming:from:against:)` in Core returns accept (naming any
concurrent server version to archive), reject, or already applied. The Vapor server, the
in-memory server the Kit tests use, and the client's own check for a pulled change against an
unpushed edit all call it.

**Why:** the two-client data-safety tests must exercise the real rule, not a test double's
idea of it, and Kit cannot depend on Vapor. Putting the decision in Core makes the in-memory
server a faithful stand-in and the same-millisecond tie provably identical on both sides.

## 2026-09-15 · A replayed push is recognised, not re-applied

**Decision:** a pushed record with the same `updatedAt` and the same writer as the server's
current version is "already applied": acknowledged with the existing version and seq, no new
version, no archive entry. The writer travels with the record (`SyncRecord.deviceID`) when it
names one, so a Mac re-offering records after a server restore is judged by who wrote them.

**Why:** the response to a push can be lost after the server committed. Without this, the
retry would look like a concurrent edit against itself, and every interruption would leave a
phantom version and a spurious archive entry.

## 2026-09-15 · Nil optionals go on the wire as explicit nulls

**Spec said (§3.5):** `fields` is a partial; an omitted key means unchanged.

**Decision:** the client sends every field it knows, with a nil optional as `null`, plus the
unknown fields it carries. The server merges: absent unchanged, null cleared.

**Why:** with synthesized `Codable`, a nil optional is simply absent, which under "absent means
unchanged" would make clearing a grade impossible. Sending the full known set costs nothing
and keeps the partial semantics for fields this build has never heard of.

## 2026-09-15 · A Mac learns when its accepted write was overridden

**Decision:** the server records, on each version, the archive id of the version it replaced
by last-write-wins, and sends it as `SyncRecord.archivedAs` in `changes`. A Mac applying such
a change to a clean copy it wrote keeps that copy as a `ConflictLoser` with the same archive id.

**Why:** the spec's conflict list only covers a push that loses. The other direction, an
accepted write overridden later by a concurrent edit, was silent on the losing Mac; the end-
to-end test found it. Now both directions leave a loser on the Mac that lost and on the server.

## 2026-09-15 · Schema V2 rather than amending V1

**Decision:** the sync engine's two local tables (`ConflictLoser`, `SyncState`) are schema
version 2 with a lightweight migration stage. V1's model classes are reused unchanged.

**Why:** the store on Alvis's Mac was created by the milestone-three build with V1. Amending
V1 in place would have left that store matching no version in the plan. `MigrationTests`
writes a V1 store and opens it as V2, and the real store migrated on the next launch.

## 2026-09-15 · The cursor lives in the store, not in defaults

**Decision:** `SyncState` (cursor, server address, last outcomes) is a row in the same SwiftData
store as the records. The bearer token is the one thing kept elsewhere, in the Keychain.

**Why:** a client store restored from a backup must bring the cursor that matches it. A cursor
in `UserDefaults` would point past records the restored store never received.

## 2026-09-15 · A server cursor behind ours means "restored from backup"

**Decision:** an empty page's cursor is `min(since, head)`. When the returned cursor is lower
than the client's, the client marks every local record dirty and pushes them all; the server
judges each by `updatedAt` and archives the version the restore brought back.

**Why:** `seq` is monotonic on a live server, so regression can only mean a restore. This is
the reconciliation §3.11 and the "Backup/restore" test row ask for, without any extra endpoint.

## 2026-09-15 · Keychain: data protection first, login keychain as fallback

**Spec said (§3.6):** the token lives in the Keychain with `AfterFirstUnlockThisDeviceOnly`.

**Decision:** `KeychainCredentialStore` tries the data protection keychain with that attribute
and, when the system answers `errSecMissingEntitlement`, uses the login keychain instead. Reads
check both.

**Why:** the data protection keychain needs an application identifier, which a locally-signed
build without the Developer Program does not have. The fallback is still the Keychain and still
not `UserDefaults`; the accessibility attribute is what waits for real signing. Found by pairing
the sandboxed app against a local server: save fell back, the read did not, and the engine saw
no token.

## 2026-09-15 · Pairing from the environment in Debug builds

**Decision:** `STUDYBOT_PAIR_URL`, `STUDYBOT_PAIR_CODE` and `STUDYBOT_PAIR_NAME` pair a Debug
build on launch, and `Tools/screenshots.sh` passes them through.

**Why:** the only way to prove the sandboxed app, the Keychain, URLSession and the server agree
is to run them together, and the snapshot tour cannot type into a text field.

## 2026-09-15 · The Assignments header sheds the module filter when narrow

**Decision:** at the minimum window width with the panel open, `ViewThatFits` drops the module
picker rather than clipping New.

**Why:** seen in the 1080×600 capture. Every day-one stub has no module, so the filter is the
least useful control to lose.

## 2026-09-15 · The term strip has no tap yet

**Spec said (§6.1, §9):** "no interaction beyond tapping a marker to jump to it."

**Decision:** the strip ships drawn, with the VoiceOver summary, and without the tap. It
arrives when there are screens to jump to (a session's notes, a block in Block mode).

**Why:** today a tap on a submission could only open the Assignments list, which the deadline
card above it already does. Deadline density shading is also left for later, per §9's "worth
building" list.

## 2026-09-15 · One scale factor for text and the layout that follows it

**Spec said (§9 Typography, patched):** every size is a base value; `SBType` scales it by the
Dynamic Type category; row heights, icon frames, chip and button padding, measures and icon
gaps scale with it; hairlines, module dots, the term strip's marks and the 56pt rail do not.

**Decision:** `SBScale` in the environment, derived from `dynamicTypeSize` with the system's
body ramp (17pt body at each size, divided by 17, so 3.1× at the largest). `sbType(_:)` and
`sbFont(_:weight:design:)` are the only ways a view names a size; `swiftlint`-visible
`.system(size:)` calls are gone from every view. Metrics go through `scale(_:)`, rounded to
half a point.

**What reflows rather than clipping at accessibility sizes:** list rows put the title on its
own line and the columns beneath, and drop empty columns; sidebar labels wrap to two lines;
the screen header stacks title over controls; the detail panel's chips stack; the detail
panel takes the whole content pane instead of a third column, since a 13-inch window cannot
hold three; the title field wraps to three lines. System pickers step up to `.large`.

**Two judgement calls:** the sidebar grows with text only up to 1.8×, enough for
"Assignments" to fit on one line at the largest size, so it never eats the content pane; and
the detail panel's width grows only to 1.4× when it is still a third column.

**Checked** in a 1080×600 window at `accessibility5` (`docs/screenshots/*-accessibility5`).

## 2026-09-16 · Milestone five is capture only; AI moves to milestone six

**Spec said (§13 v1):** `structureNotes`, `makeFlashcards`, the palette's `explain`.

**Decision:** cut from this milestone. Session notes, Block mode and evidence capture ship;
the two AI buttons are present and disabled with the reason.

**Why:** induction is 22 September. A missing AI feature costs an evening in October; a
missing capture surface costs a day of lectures permanently.

## 2026-09-16 · A session's id comes from the event and the day

**Decision:** `Session.stableID(eventSourceUID:dayISO:)`. A two-day on-campus event is two
sessions. `NotesStore.open` creates the record on first open with that id.

**Why:** two Macs opening the same session offline must produce one record on the server, not
two with different ids and no way to merge them.

## 2026-09-16 · The module tree lives in the Modules & notes screen, not the sidebar

**Spec said (§6.3):** "Sidebar expands to modules, each module expands to its lectures."

**Decision:** the sidebar keeps its five items; the Modules & notes screen has its own column
with the current term's modules as collapsible sections and their sessions beneath.

**Why:** the 228pt sidebar with 41 Professional Development sessions under it would be a
scrolling tree beside a scrolling list. One list, in the screen that owns it, is quieter. The
sidebar can grow the tree later without moving anything else.

## 2026-09-16 · Styling in place, TextKit 1, restyle per paragraph

**Spec said (§6.3):** a transparent text view over a styled mirror, or attributed-string
styling in place; never change size, weight or character count.

**Decision:** in place. The `-` of a bullet stays in the text with a clear colour and the
layout manager draws `•` over it on the baseline; `ASK:` lines carry a custom attribute the
layout manager fills the band and rule from. Every attribute set is colour, background or a
marker. Restyling runs from `didProcessEditing` on the edited paragraphs only. A test pins the
parser at under 16ms for a 400-line note.

**Why:** one text storage means one caret and no mirror to keep in step. TextKit 1 because
custom glyph drawing needs `NSLayoutManager`.

## 2026-09-16 · Identical content is agreement, not a conflict

**Observation:** in the first drill both Macs imported the calendar separately and pushed the
same 66 records; the second push archived 60 identical "losers".

**Decision:** `SyncMerge` treats a push whose fields equal what the server holds as already
applied: acknowledged with the existing version, no new version, no archive entry.

**Why:** an archive full of identical copies hides the one real loss.

## 2026-09-16 · The capture bar's one keystroke is a modifier

**Spec said (§6.6):** "one field, one keystroke to file a thought as a note, a question, or an
evidence item."

**Decision:** return files a note line into the selected session, shift-return an `ASK:` line,
option-return opens the evidence sheet with the text as its title. The hint sits beside the
field.

## 2026-09-16 · The drill runs with two instances on one Mac

**Spec said (§3.11):** a two-machine drill before relying on the app.

**Decision:** `Tools/drill.sh` runs two copies of the Debug build with `STUDYBOT_STORE_PATH`,
`STUDYBOT_DEVICE_ID` and per-store Keychain accounts against a local server, drives them with
`STUDYBOT_DRILL=append:…|show`, and prints both stores and the archive. It is not two Macs: the
network, the clocks and the Keychain are one machine's. The real drill on two Macs is written
up in the README and remains Alvis's to run.

## 2026-09-16 · Disk full: one write path, one banner, snapshots yield

**Spec said (§16 Reliability, patched):** a failed store write must surface immediately and
persistently on the note, the text stays; check free space on launch and hourly; snapshots
are skipped rather than allowed to fail; a test forces the failure.

**Decision:** `NotesStore.write` is the only path to the store for notes. A failure lands in
`saveFailures` with `DiskSpace.saveFailureMessage`, which recognises Cocoa's out-of-space
code, POSIX `ENOSPC` and SQLite's "database or disk is full" however SwiftData wraps them.
The workspace shows a banner in `danger` above the editor with Try again; it clears only when
a write succeeds. `DiskMonitor` checks the store's volume on launch and hourly: under 2 GB
Today warns once with Dismiss, under 500 MB the line stays and revision snapshots are
skipped. Quitting with unsaved notes puts up an alert whose default button keeps the app
open. `DiskFullTests` forces the failure through a store whose writes throw, and asserts the
banner text, the retained text, the retry and the silent snapshot skip.

**Not done:** ⌘W closes the window but the app and its in-memory notes stay alive, so nothing
is lost; a window-close guard would need an `NSWindowDelegate` SwiftUI does not hand over.

## 2026-09-16 · The export is a folder, in Downloads, on demand

**Spec said (§16):** weekly automatic export plus one on demand, JSON bundle plus
attachments, notes as Markdown readable without StudyBot, restore tested end to end.

**Decision:** on demand only for now, from Settings → Data, into `~/Downloads/StudyBot
exports/` (the sandbox's Downloads entitlement, so no save panel and a place Alvis can see).
Records carry their sync metadata verbatim and every field including unknown ones; notes are
one Markdown file per session; revisions, losers, the calendar and the sync state (never the
token) come too. Restore reads the folder back and replaces records by id. The format is
`docs/export-format.md`. `ExportBundleTests` exports a store holding every type, restores into
an empty store and asserts equality type by type. The README says to run it after every block.

**Why not automatic yet:** a weekly timer that writes into Downloads unasked needs its own
retention rule and a place in Settings to see it ran; that is a small follow-up, and the
on-demand path is the one that must exist before the 22nd.
