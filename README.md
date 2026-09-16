# StudyBot

A macOS app for managing a BSc Digital & Technology Solutions degree apprenticeship
(University of Exeter, September 2026 intake). One user, two Macs, an own-server sync
engine, and a programme calendar that already knows every date for three years.

The specification is [`studybot-build-spec.md`](studybot-build-spec.md). It is the
single source of truth; this README only tells you how to run things.

## What ships with the repo

| File | Purpose |
|---|---|
| `studybot-build-spec.md` | The complete specification. Read §0 first. |
| `DTS_L6_Sept_2026_intake.ics` | The real programme calendar, 156 events. Bundled into the app. |
| `programme-calendar.json` | The same data parsed, for seeding and tests. |
| `studybot-prototype.jsx` | Approved visual reference for the design system (§9). Not architecture. |

## Layout

```
Packages/
  StudyBotCore/   shared between app and server: models, DTOs, sync envelope, validation
  StudyBotKit/    client only, no UI: importers, scheduling (WorkingDays, TermCalendar), support
  StudyBotUI/     design system: §9 tokens and primitives
Apps/StudyBotMac/ views and app lifecycle, nothing else (project.yml → XcodeGen)
Server/           Vapor server: one binary, `studybotctl`, serve + operator commands
Tools/seed/       ICS → programme-calendar.json                  (later milestone)
```

Tests live inside each package under `Tests/`, which is where `swift test` looks.

## What milestone one built

Foundation only, no UI. Everything below is pure Swift with tests alongside.

**StudyBotCore** (shared with the server, Foundation only)

- The §4 models as value types, with the eight sync fields in one `SyncMetadata` struct.
  Relationships are ids, because a value type cannot hold a two-way object graph; SwiftData
  classes wrap these in the next milestone.
- Every §4 supporting enum in the spec's order, pinned by tests.
- The §3.5 sync envelope DTOs. `fields` is a partial map of `JSONValue`, so a field this
  build has never heard of is round-tripped rather than dropped.
- `UKCalendar` and `LocalDay`: en-GB, Europe/London, Monday-first, and all day arithmetic by
  calendar day so a BST change can never move a block by a day.
- `StableID`: deterministic UUIDs for records both Macs derive independently (events from
  the ICS UID, modules from their code, terms from year and number).
- Validation rules shared by client and server.

**StudyBotKit** (client logic, no UI)

- `ICSParser`: RFC 5545 tokenizer with line unfolding, CRLF/LF, quoted parameters, TEXT escapes.
- `ICSProgrammeCalendarReader`: VEVENTs → `ProgrammeEvent`s. All-day `DTEND` is exclusive
  and is pulled back a day. The real file yields 156 events and matches
  `programme-calendar.json` on every date and kind.
- `ProgrammeCalendarImporter`: idempotent merge on `sourceUID`. Changed dates update in
  place, removed events are cancelled rather than deleted so attached notes survive.
- `ModuleSeeder` and `AssignmentStubs`: the 26 modules and 30 backlog assignments the
  calendar implies, ready for the store to persist on first launch.
- `WorkingDays`: excludes weekends, bank holidays, closures and campus days, all read from
  the calendar. Never hardcoded.
- `TermCalendar`: the nine terms, eight campus blocks, week of term and days to the next
  block. The term rule is documented on the type; do not simplify it to a gap-based rule.
- `RelativeDate`: the one place dates become words.

## What milestone two built

Persistence only, still no UI.

- **`Database`**, one `@ModelActor` that owns the `ModelContainer`. Its public API speaks
  only Core types plus `StoredRecord`; the `@Model` classes are internal to StudyBotKit and
  cannot appear in a signature elsewhere. Every mutating call saves before it returns.
- **Sixteen `@Model` classes** under `Database/Models`, one per Core type. Each row holds the
  eight sync fields as columns, a few type-specific index columns, the whole value as a JSON
  body, and an `unknownFields` blob. See `docs/decisions.md` for why.
- **Unknown-field preservation through storage.** `StoredRecord` carries fields from a newer
  build beside the value. Saving a bare value keeps them. `UnknownFieldPreservationTests`
  proves the §3.10a loss scenario does not happen: newer build writes, stale build reads,
  edits and writes back, fields intact, including across closing and reopening the file.
- **A versioned schema and migration plan** (`StudyBotSchemaV1`, `StudyBotMigrationPlan`).
  One version today; `MigrationTests` writes a store with V1 directly and opens it through
  the plan. When V2 arrives, add a stage and a V1→V2 test.
- **`ProgrammeStore`** protocol with two implementations, `Database` and
  `InMemoryProgrammeStore`, and **`ProgrammeCalendarService`** on top: first launch imports
  156 events, 9 terms, 26 modules and 30 backlog stubs; a second run changes nothing; a
  moved deadline reschedules a stub unless the user edited the date by hand; a removed event
  is cancelled and notes attached to it still resolve.

### How terms are derived

The calendar has no term markers, so terms are runs of module-bearing events that share one
module set. That gives eight boundaries and puts term 3 of years 1 and 2 at the April reading
week, which is where the file puts the term-3 modules. Year 3's Synoptic Project spans terms
2 and 3, so its set changes only once; a year with fewer than three runs is split at the first
teaching session after the Easter bank holidays (18 April 2029). Submissions, Gateway and the
EPA window extend a term's end; bank holidays, closures and the summer reading weeks do not,
so real gaps exist between terms. Open question 13 in the spec is to confirm the year-3 split
with Exeter.

**Do not replace this with a gap-based rule.** It looks simpler and it is wrong: year 3's final
term contains a 35-day gap with no sessions, between the workshop on 18 April 2029 and the
next on 23 May 2029, and a "long gap means new term" rule would cut that term in two. The
module-set rule survives it because both sides of the gap carry the same modules.
`TermCalendarTests` pins all nine boundaries, so the test suite will say so too.

## What milestone three built

The first thing you can look at. Screenshots of the real first run, light and dark, are in
`docs/screenshots`.

- **StudyBotUI**: §9 tokens verbatim (adaptive for dark mode) and the primitives: `Btn`,
  `ListRow`, `SectionHeader`, `StatusIcon`, `PriorityBars`, `ModuleChip`, `DueDateLabel`,
  `GradeBadge`, `ProgressBar`, `EmptyState`, `Chip`, and the input and card styles.
- **The Mac app** (`Apps/StudyBotMac`, generated into an Xcode project by XcodeGen): first run
  per §6.0 with the real numbers, a 228pt vibrancy sidebar that collapses to a 56pt rail on
  `⌥⌘S`, Today with the block banner and the next deadline, and the Assignments screen per
  §6.2: grouped by status, 38pt rows, current-term scope with the hidden-count footer, module
  filter, and a detail panel with edit mode (`⌘E`, `⌘S`, `⎋`, discard confirmation).
- **Under the screen**: `AssignmentStore` (scope, grouping, explicit save with field
  ownership), `LastWriteWins` with the deterministic device tie-break, partial-field merging,
  and every index column §6 needs promoted in the store.

## What milestone four built

Sync and the server, before any AI (§13). Two Macs can now diverge offline and converge.

- **`SyncMerge`** in Core: the one pure decision for a pushed record. Accept (naming any
  concurrent server version to archive), reject as a conflict, or "already applied" for a
  replayed push. Later `updatedAt` wins; a same-millisecond tie goes to the lower `deviceID`.
  The Vapor server and the in-memory test server both run this function.
- **The server** (`Server/`): Vapor over SQLite. `POST /v1/auth/pair`, `GET` and `POST
  /v1/sync`, `GET /v1/sync/archive/:id`, `GET /health`. Every push is one transaction. Losing
  versions land in `conflict_archive` whichever side lost, and the client is told which
  archive id its write replaced. A client more than one schema version behind gets `409`.
- **The engine** (`SyncEngine` in Kit): one serialised actor. Push dirty records in pages of
  500, pull until caught up, apply every response in a single store save with the cursor, so
  an interruption leaves all of it or none. Offline, blocked, unauthorised are outcomes in
  `SyncState`, never alerts. Triggers: launch, every five minutes, ten seconds after a local
  write settles (`SyncStore`).
- **Losers are kept on both sides.** A local version that loses is a `ConflictLoser` row for
  30 days (and a `NoteRevision` for session notes) with the server's archive id, so a replaced
  page of notes is recoverable from the Mac that wrote it and from the server.
- **Schema V2** adds the two local tables with a lightweight migration from V1.
- **The term strip** on Today (§9 "Signature details"): the current term as one line, campus
  blocks as accent marks, Monday sessions as ticks, submissions as hollow amber rings, today
  as a rule, with the spoken summary §16 asks for. `TermStrip` in Kit decides, `TermStripView`
  in UI draws.
- **Dynamic Type** (§9 patched, §16): every text size is a base value scaled by `SBScale`
  from the Dynamic Type size, along with row heights, paddings and icon frames; hairlines,
  module dots, the term strip and the 56pt rail stay fixed. Dense rows reflow to two lines at
  accessibility sizes instead of clipping. `docs/screenshots/*-accessibility5` show the
  largest size in a 1080×600 window.
- **Settings → Sync** pairs a Mac with a six-word code, shows the status in plain words, and
  can sync now or unpair. Today shows one quiet line only after an hour of failed syncs.
- **Tests**: `SyncMergeTests` (Core), `SyncEngineTests` and `SyncStoreTests` (Kit, two
  simulated Macs against the in-memory server: convergence, the same-millisecond tie from both
  sides, interrupted mid-push, replay, never concurrent, offline, unknown fields round-trip,
  one and two schema versions behind, restore from backup, tombstones, pagination), and the
  server's route tests plus an end-to-end run with the real server on a port and two real
  client stores over HTTP.

## What milestone five built

Capture, for induction week. AI is deliberately absent; it works on notes that already exist.

- **Session notes** (§6.3): every teaching event in the calendar is a session, one per day it
  covers, with an id both Macs derive so opening it on both creates one record. The live pane
  is a plain `NSTextView` styled in place: `- ` draws a bullet, `ASK:` lines take the accent
  band, and styling changes colour and decoration only, never size, weight or character count,
  so the caret never drifts. Restyling touches only the edited paragraph. Writes land once
  typing pauses; a `NoteRevision` is kept after 30 seconds idle; the transcript pane is
  paste-only for now. "History" shows every kept version and the losers of any sync race, each
  with a Restore that snapshots the current text first.
- **`ASK:` capture**: questions collect live beneath the editor and, in Block mode, across
  every day of the block.
- **Block mode** (§6.6): a column per day of the block, never assuming three; the selected
  session's notes; the questions list always visible; the capture bar fixed at the bottom
  (return files a note, shift-return a question, option-return opens evidence). Opens from
  Today's banner, from ⌘K or ⇧⌘B, and by itself when today is inside a block.
- **Evidence** (§6.5): title, date, what you did, KSBs as typed codes until Exeter's list
  exists. From ⌘K, ⇧⌘E, Portfolio, or the capture bar.
- **⌘K** (§6.7): navigation and actions. Search and AI wait for their milestones.
- **Modules & notes**: the current term's modules with their sessions in date order, a dot
  for sessions that have notes, and the workspace beside them.

## What milestone six built

Two things that stand between the app and induction, then the first AI.

- **Disk full is a first-class failure** (§16, patched). Every note write checks its
  result; a failure is a banner on the note that stays until a write succeeds, with the text
  still in the editor and a Try again. The store's volume is checked on launch and hourly:
  under 2 GB Today warns once, under 500 MB the line stays and revision snapshots are skipped.
  Quitting with unsaved notes asks first. `DiskFullTests` forces the failure.
- **Export and restore** (§16). Weekly and automatic, twelve kept, plus on demand from
  Settings → Data. A folder in Downloads: notes as
  Markdown, records as JSON with their sync metadata and unknown fields, the calendar, every
  kept version. Restore reads it back. `ExportBundleTests` exports, restores into an empty
  store and asserts equality type by type. Format: `docs/export-format.md`.
- **AI, through the server only** (§3.7, §7). `structureNotes`, `makeFlashcards` and
  `explain`. The client assembles prompts from §7.3a's versioned templates through one
  function that refuses confidential content before any string exists; the server refuses a
  flagged payload with 422 anyway, caches by content, reserves budget before each call so
  concurrent requests cannot pass the cap, answers 402 at the cap and 429 with Retry-After,
  and writes every run to `ai_runs`. Every run also lands in the AI-use record on the Mac
  (Settings → AI). Live notes are never written by the AI. Without `OPENAI_API_KEY` the
  server answers from a canned provider, so nothing costs money until you set it.

### Turn the AI on

Set `OPENAI_API_KEY` and `AI_MONTHLY_CAP_PENCE` in the server's env file and restart it.
The Mac needs nothing: it already talks to the server it is paired with. Settings → AI shows
spend against the cap and the AI-use record.

### Export after every block

The app exports itself every seven days, on launch and then hourly when due, into
`~/Downloads/StudyBot exports/` (folders ending "(automatic)", twelve kept). Settings → Data →
Export everything does the same on demand, and after a block it is still worth pressing:
notes as Markdown, every record as JSON, the calendar, every kept version. Copy the newest
folder somewhere that is not this Mac. The format is documented in
[`docs/export-format.md`](docs/export-format.md); restore is the button beside it, and
`ExportBundleTests` proves an export restores into an empty store with nothing lost.

### Copy it to the other Mac

```bash
./Tools/release.sh
```

Unzip `dist/StudyBot-<version>.zip` on the other Mac, move the app to Applications, and
right-click → Open the first time (locally signed, §3.10a). Then Settings → Sync → pair it.

### The two-machine drill (§3.11, §16)

Before relying on the app: edit the same note on both Macs while both are offline, reconnect,
and confirm the losing version is retrievable. On one Mac, `./Tools/drill.sh` runs the drill
with two copies of the Debug build on separate stores and device ids against a local server,
prints what each store holds and what the server archived, and screenshots both instances
into `docs/drill`. Run it once a term. With two real Macs: turn Wi-Fi off on both, type a
different line into the same session on each, turn Wi-Fi on, wait for the sync, and open
History on the note that changed.

### Running the app

```bash
xcodegen generate
```

```bash
open StudyBot.xcodeproj
```

Or build and launch from the terminal:

```bash
xcodebuild -project StudyBot.xcodeproj -scheme StudyBotMac -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGN_IDENTITY=- build && open .build/DerivedData/Build/Products/Debug/StudyBot.app
```

The store lives in the app's sandbox container under `Library/Application Support/StudyBot`.
To judge a build without screen recording, launch with `STUDYBOT_SNAPSHOT_DIR=<folder inside
the container>` and optionally `STUDYBOT_SNAPSHOT_APPEARANCE=light|dark`; a PNG per screen is
written and the app quits.

## Requirements

- macOS 15 or later.
- Swift 6.x with a toolchain that can run tests. That is either full Xcode, or the
  Command Line Tools **plus** a swift.org toolchain from <https://www.swift.org/install/macos/>.
  Apple's Command Line Tools alone build the packages but cannot load the Swift Testing
  framework at test time. The Mac app and the SwiftData store (later milestones) need full Xcode.
- Optional locally, required in CI: `brew install swiftlint xcodegen`. `swift-format` ships
  with the toolchain and is run as `xcrun swift-format`.

## Build and test

Run everything the way CI does. The script picks a working `swift` for you: Xcode's if
Xcode is selected, otherwise the swift.org toolchain in `~/Library/Developer/Toolchains`.

```bash
./Tools/ci.sh
```

To run one package by hand with full Xcode installed:

```bash
cd Packages/StudyBotCore && swift test
```

With the Command Line Tools only, call the swift.org toolchain directly:

```bash
cd Packages/StudyBotKit && ~/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/swift test
```

## Formatting and lint

Both are blocking in CI. To check locally:

```bash
xcrun swift-format lint --strict --recursive Packages
```

```bash
swiftlint --strict
```

To fix formatting in place:

```bash
xcrun swift-format format --in-place --recursive Packages
```

## Server

One binary, `studybotctl`. The environment keys are listed in [`.env.example`](.env.example);
the real file lives outside the repo with mode `0600` (§3.10b). Two are needed today:
`STUDYBOT_DB_PATH` and `STUDYBOT_PAIRING_SECRET`.

### Run it locally

```bash
cd Server && swift build
```

```bash
mkdir -p ~/studybot-server && export STUDYBOT_DB_PATH=~/studybot-server/studybot.sqlite STUDYBOT_PAIRING_SECRET="$(openssl rand -hex 32)" && ./Server/.build/debug/studybotctl serve --hostname 0.0.0.0 --port 8080
```

The database is created and migrated on first start. `curl http://localhost:8080/health` says
`{"status":"ok"}`. There is no seed step: the first Mac that pairs pushes the programme it
imported, and the second Mac pulls it.

### Pair a Mac

On the server, with the same environment variables:

```bash
./Server/.build/debug/studybotctl pair
```

It prints six words, valid for ten minutes, single use. On the Mac: StudyBot → Settings (`⌘,`)
→ Sync → enter the server address (`http://<host>:8080` locally, `https://…` behind Caddy), a
name for the Mac, and the six words → Pair this Mac. Repeat on the other Mac with a new code.

```bash
./Server/.build/debug/studybotctl devices
```

```bash
./Server/.build/debug/studybotctl revoke <device-id>
```

Revoking a token is how a lost laptop is handled. That Mac keeps working offline and must
pair again to sync. Nothing is deleted anywhere.

### Rotate a credential

- **A device token**: `studybotctl revoke <id>`, then pair the Mac again. Tokens are stored
  only as SHA-256 hashes; the plain token exists in the Mac's Keychain and nowhere else.
- **The pairing secret**: change `STUDYBOT_PAIRING_SECRET` and restart. Codes issued before
  the change stop working; existing device tokens are unaffected.

### Restore from a backup

Litestream is not wired up yet (it arrives with the VPS deployment), so today a backup is a
copy of the SQLite file. To restore: stop the server, put the copy at `STUDYBOT_DB_PATH`,
start the server. Each Mac notices on its next sync that the server's cursor has gone
backwards, marks everything it holds dirty, and offers it all back; the server keeps the newer
version of each record and archives what the restore had brought back. `SyncEngineTests`
"a server restored from a backup is reconciled" runs exactly this. The two-Mac drill in §3.11
is the same test done by hand: edit the same note on both Macs offline, reconnect, and find
the losing version under the record's conflict losers and in `conflict_archive`.

### Housekeeping

```bash
./Server/.build/debug/studybotctl purge-tombstones
```

Removes deletions older than 90 days. `sync_log` keeps every sequence number, so cursors stay valid.

### Server tests

```bash
cd Server && swift test
```

`EndToEndTests` starts the server on a random port and runs two real client stores through
`HTTPSyncTransport`; the rest run the routes against in-memory SQLite.

## Conventions

See spec §3.13. In short: one type per file, no force unwraps, no `try!` outside tests,
dates are `Date` internally and formatted only at the edge, money and token counts are
integers, every `TODO` carries a date and a name.
