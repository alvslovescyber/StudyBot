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

## Requirements

- macOS 15 or later.
- Swift 6.x. The Xcode Command Line Tools are enough for the packages
  (`xcode-select --install`). The Mac app and the SwiftData store need full Xcode.
- Optional locally, required in CI: `brew install swiftlint`. `swift-format` ships with
  the toolchain and is run as `xcrun swift-format`.

## Build and test

Each package is built and tested from its own directory.

```bash
cd Packages/StudyBotCore && swift test
```

```bash
cd Packages/StudyBotKit && swift test
```

Or run everything the way CI does:

```bash
./Tools/ci.sh
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
