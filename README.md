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
  StudyBotUI/     design system primitives                       (later milestone)
Apps/StudyBotMac/ views and app lifecycle, nothing else          (later milestone)
Server/           Vapor server                                   (later milestone)
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

## Requirements

- macOS 15 or later.
- Swift 6.x with a toolchain that can run tests. That is either full Xcode, or the
  Command Line Tools **plus** a swift.org toolchain from <https://www.swift.org/install/macos/>.
  Apple's Command Line Tools alone build the packages but cannot load the Swift Testing
  framework at test time. The Mac app and the SwiftData store (later milestones) need full Xcode.
- Optional locally, required in CI: `brew install swiftlint`. `swift-format` ships with
  the toolchain and is run as `xcrun swift-format`.

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

Not yet built. When it is, this section will carry the runnable steps §3.10b requires:
running locally with a seeded database, generating a pairing code, restoring from a
Litestream replica, and rotating each credential. The environment keys are already listed
in [`.env.example`](.env.example); the real file lives outside the repo with mode `0600`.

## Conventions

See spec §3.13. In short: one type per file, no force unwraps, no `try!` outside tests,
dates are `Date` internally and formatted only at the edge, money and token counts are
integers, every `TODO` carries a date and a name.
