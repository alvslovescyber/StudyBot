# StudyBot — Build Specification v1.0

A study and apprenticeship management app for a BSc Digital & Technology Solutions degree apprenticeship at the University of Exeter, employed at Cambridge Kinetics.

This document is the single source of truth for whoever builds the app, human or AI.

---

## 0. How to use this spec

**Read these five first, in this order, before writing anything:** §1 Context (who and why), §3 Architecture (how it's put together), §4A The programme calendar (the data everything else hangs off), §6.0 First run (what launch one looks like), §13 Delivery plan (what to build first).

**Do not invent these — they are specified, and guessing will produce something subtly wrong:** the supporting types and enum orders (§4), date and locale rules (§4, Dates/times/locale), the sync payload shape (§3.5), AI prompt templates (§7.3a), design tokens and component values (§9), empty-state and error copy (§9), and environment variable names (§3.10b).

**Authority.** Where sections disagree, the more specific wins: §9's exact component values beat any general design statement, §3's architecture decisions beat any implementation convenience, and §14's open questions mark things nobody has answered yet — do not invent answers to them, build the seam and leave it empty.

**Ship order.** Build in this sequence, because each depends on the last: shared models → local store → design system primitives → the ICS importer → Assignments → Session notes → sync → server → AI proxy → everything else. Sync before AI: an app that loses notes is worthless however clever its AI is.

**Two files ship with this spec and are not optional:** `DTS_L6_Sept_2026_intake.ics` (the real programme calendar, bundled into the app) and `programme-calendar.json` (the same data parsed, for seeding and tests). A third file, `studybot-prototype.jsx`, is a visual reference for §9 — read it alongside the design system, and treat it as authoritative for look and feel but not for architecture.

**Terminology**, used precisely throughout:

| Term | Meaning |
|---|---|
| **ELE2** | Exeter Learning Environment — the university's Moodle. Where briefs are published and submissions are made. |
| **KSB** | Knowledge, Skills and Behaviours — the apprenticeship standard's competency list, which must be evidenced. |
| **EPA** | End-Point Assessment — the final independent assessment, July 2029. |
| **Gateway** | The checkpoint confirming readiness for EPA, June 2029. The portfolio must be complete by then. |
| **Off-the-job / OTJ** | Learning done during paid working hours, which must be logged and evidenced. |
| **Block** | An on-campus teaching period, two or three days, eight in total. |
| **Session** | Any single teaching event, on campus or online, lecture or workshop. The model is `Session`; the UI word is "session" because most are workshops. |
| **Proposal** | Something automation suggests, awaiting the user's confirmation. Never applied automatically. |
| **Signature detail** | A small, specific touch that earns the app its feel. §9. |
| **Routine** | One of the five scheduled jobs in §8.11. |
| **Working day** | A weekday that isn't a bank holiday, a closure or an on-campus day. |

**What this spec does not contain:** the real KSB list, the titles and briefs of the 30 submissions, Exeter's OTJ export format, and Exeter's AI policy. All four arrive at induction. §14 lists them and the models are built to receive them.

---

## 1. Context

| | |
|---|---|
| **User** | One person. Sole user, sole author of the data. Not multi-tenant. |
| **Course** | BSc Digital & Technology Solutions, University of Exeter |
| **Employer** | Cambridge Kinetics |
| **Programme** | Level 6 Digital & Technology Solutions, September 2026 intake. Three years, three terms a year. |
| **Teaching pattern** | A short on-campus block at the start of each term, then **weekly Monday online sessions** alternating lectures and workshops. Everything else is self-directed, around a full-time job. |
| **First block** | Induction 22 September 2026, on campus 23–24 September 2026 |
| **Assessment** | 30 mandatory submissions via ELE2 across the three years |
| **Ends** | Gateway 14 June 2029, EPA window 16–27 July 2029 |
| **Goal** | Distinction-level grades across all assignments, and a complete EPA portfolio at the end. |

All dates come from the official programme calendar, supplied as `DTS_L6_Sept_2026_intake.ics` and parsed into `programme-calendar.json`. Both ship with this spec. See §4A.

### The problem the app actually solves

A normal student app assumes a campus, a timetable and a term that fills your week. This one runs alongside a full-time job, on a rhythm of one evening-sized session a Monday plus three short bursts on campus a year. Four failure modes follow, and the app exists to prevent all four:

1. **The on-campus blocks overflow.** Two or three days produce more material than can be processed live, and the next face-to-face contact is four months away. Notes get half-written, questions go unasked.
2. **The Monday drumbeat slips.** Weekly online sessions are easy to attend passively and never revisit. Miss the follow-up three weeks running and the material is gone. The first deadline lands on **15 October 2026 — three weeks after induction**, so there is no gentle start.
3. **Deadlines cluster viciously.** Five submissions fall between 1 and 20 July 2027. That crunch is visible from the first week of the course, ten months ahead, and is only survivable if work starts months before it feels urgent.
4. **Evidence is never captured.** Off-the-job hours go unlogged, KSB evidence from work at Cambridge Kinetics is never written down, and at Gateway in June 2029 it all has to be reconstructed from memory.

Every feature below should be judged against those four problems.

---

## 2. Product principles

1. **Capture must be faster than the thought.** If logging a piece of evidence or a lecture point takes more than a few seconds, it won't happen during a busy day. Speed of capture beats completeness of capture.
2. **The weeks between are the product.** Eight on-campus blocks in three years, against 87 Monday sessions and roughly 150 weeks of self-directed work. Design for the Mondays and the quiet weeks, not for the blocks.
3. **Quiet until it matters.** No streaks, no badges, no gamification. The app earns trust by being calm and being right about deadlines.
4. **The user writes the work.** AI drafts, structures, questions and checks. It does not hand over prose to be pasted into a submission unreviewed, and it keeps a record of what it did.
5. **Typing is the last resort.** The only things the user should ever type are notes and their own reflections. Deadlines, briefs, resources, hours and evidence should arrive by import, pull or timer. Every field in this app should be interrogated with: where could this come from instead?
6. **Confirm, never compose.** Automation drafts; the user approves with one tap. Nothing auto-created is silently treated as true, and nothing auto-created is hidden either.
7. **Small moves, not big features.** The details that make this feel made-for-one-person are cheap and specific: a term strip, an `ASK:` prefix, a working-days count that excludes bank holidays. Budget for them. See §9 Signature details.
8. **Work data stays put.** Cambridge Kinetics material never leaves the device.
9. **Keyboard first on Mac, thumb first on iPhone.** Same data, same model, different input assumptions.

---

## 3. Platforms and architecture

### 3.1 Decisions and their reasons

| Decision | Choice | Why |
|---|---|---|
| First platform | macOS 15+, on **two Macs** | The Apple Developer Program is deferred, so iPhone install isn't viable yet. A free Apple ID signs a Mac build fine, and a locally-signed Mac app can be copied to a second Mac — unlike iOS, there is no per-device provisioning. |
| Second platform | iOS 18+, later | Added when the £99/yr membership is taken. Nothing in the design may block it. |
| Local store | SwiftData | Swift-native, fast to work with, and used purely as a local store. |
| Sync | Own server | **Not CloudKit.** CloudKit needs the paid membership, and swapping it out later would mean rewriting persistence. Server sync works today on the Mac and works unchanged when iOS arrives. |
| Server | Vapor | One language across client and server, and a shared package means one definition of every model. |
| Server DB | SQLite + Litestream | Single user. One file, continuous replication, trivial restore. Postgres would be ceremony for no gain. |
| Hosting | £5/mo VPS | Always on, which is what ingestion needs. |
| AI | Proxied through the server | Key never reaches a device, and it's the only place spend caps and caching can actually be enforced. |
| Offline | Fully offline-first | Notes are irreplaceable and campus wifi is not to be trusted. |

**Two Macs from day one.** The user works across two machines — likely one at home and one carried to campus and work. This is not a later concern to be designed around; it is the v1 reality, and it makes three things load-bearing rather than nice-to-have:

1. **Sync is v1, not v2.** A second machine with stale data is worse than no second machine. There is no single-device shortcut to take and pay back later.
2. **Conflicts are real, not theoretical.** Two offline Macs editing the same note is an ordinary Tuesday, not an edge case. Last-write-wins stands as chosen, and the conflict archive in §3.4 stops being optional — it is the only thing between you and a silently replaced set of lecture notes.
3. **Neither Mac is primary.** No "main machine" concept, no manual push or pull, no device roles. Both are peers; whichever one is open is the one that's right.

**On CloudKit, explicitly:** do not add it later "as well". Two sync systems over one dataset is how data gets lost.

### 3.2 Repository layout

A monorepo. The shared package is the point — a renamed field breaks the build on both sides rather than failing silently at runtime.

```
studybot/
├── Packages/
│   ├── StudyBotCore/          # shared between app and server
│   │   ├── Models/            # value types: Assignment, Evidence, Note…
│   │   ├── DTOs/              # wire types, Codable, versioned
│   │   ├── Sync/              # envelope, cursor, conflict rules
│   │   └── Validation/        # one set of rules, both sides
│   ├── StudyBotKit/           # client only, no UI
│   │   ├── Database/          # SwiftData container + Database actor
│   │   ├── Stores/            # @Observable, one per domain
│   │   ├── Sync/              # SyncEngine
│   │   ├── Importers/         # PDF, DOCX, PPTX, VTT, ICS
│   │   ├── Scheduling/        # WorkingDays, TermCalendar, study planner
│   │   └── Support/           # Debouncer, Retrier, TokenBucket, Keychain
│   └── StudyBotUI/            # design system only
│       ├── Tokens/            # colour, type, spacing — §9 verbatim
│       └── Primitives/        # Btn, ListRow, StatusIcon, SectionHeader…
├── Apps/
│   ├── StudyBotMac/           # views + app lifecycle, nothing else
│   └── StudyBotiOS/           # added later, same Kit and UI packages
├── Server/
│   └── Sources/App/
│       ├── Routes/            # sync, ai, blobs, auth, health
│       ├── Ingestion/         # ELE2, mail, GitHub pollers
│       ├── AI/                # OpenAI client, cache, budget
│       └── Migrations/
├── Tools/seed/                # ICS → programme-calendar.json
└── .github/workflows/
```

**The rule that keeps this honest:** `Apps/` contains views and app lifecycle and nothing else. Any logic that appears in an app target belongs in a package. If a feature can't be tested without launching the app, it's in the wrong place.

### 3.3 Client architecture

`@Observable` services, plain SwiftUI views, no view models.

- One `Database` actor owns the `ModelContainer`. It is the only thing that touches SwiftData directly, which makes threading a non-question.
- One `@Observable` store per domain — `AssignmentStore`, `NotesStore`, `PortfolioStore`, `RevisionStore`, `SyncStore` — injected through the environment. Stores expose intent methods (`confirmProposal(_:)`, `logHours(_:)`), never raw model contexts.
- Views read from stores and call intent methods. A view never performs a fetch, never formats a date by hand, never decides what "overdue" means.
- No singletons except the database actor. Everything else is constructed at app launch and injected, so tests build their own.

**Reusable helpers, named so nobody reinvents them:** `WorkingDays` (excludes bank holidays, closures, campus days), `TermCalendar` (which term, which week, days to next block), `DeadlineDensity`, `TextExtractor`, `Debouncer`, `Retrier` (backoff with jitter, honours `Retry-After`), `TokenBucket`, `MarkdownRenderer`, `RelativeDate`.

### 3.4 The sync engine

The hardest part of the build. Treat it as its own component with its own tests.

**Every syncable record carries the eight fields defined in §4** — `id`, `createdAt`, `updatedAt`, `version`, `baseVersion`, `seq`, `deletedAt`, `dirty` — grouped in a single `SyncMetadata` value embedded in each syncable type. §4 is authoritative; this section describes how they behave, not what they are.

**The cursor is a server sequence number, not a timestamp.** A monotonic `seq` assigned per write. Timestamps and clock skew do not mix.

**Pull** — `GET /sync?since={seq}&limit=500` returns records with `seq > since`, oldest first, plus the new cursor. Paginate until caught up.

**Push** — `POST /sync` with dirty records including their `baseVersion`. For each, the server either accepts it (assigns a new `version` and `seq`) or reports a conflict. The response is authoritative and the client overwrites local state with it.

**Conflicts: last write wins by `updatedAt`,** as chosen. With one safety net, because silently losing a page of notes is unacceptable even when you've accepted the trade-off: the losing version is written to a `conflict_archive` table on the server and kept as a local `NoteRevision` for 30 days, surfaced as a one-line notice on the note — "An older version of this note was replaced. View it." Cheap to build, and the one time it matters it matters enormously.

**Note bodies also get local revision history** regardless of sync: the last 20 versions, snapshotted on a 30-second idle debounce. This is independent insurance against the app itself, not just against sync.

**Identical content is agreement, not a conflict.** Before resolving, compare the two bodies; if they are equal, accept silently and archive nothing. Both Macs derive the same records from the same bundled calendar, so without this rule a first sync produces dozens of "losers" that are byte-identical to the winners — noise that trains the user to ignore the one conflict notice that matters.

**Deletions** are tombstones, purged server-side after 90 days, long past any plausible sync gap.

**Attachments never go through the sync envelope.** Content-addressed by SHA-256: `PUT /blobs/{sha}` is idempotent and skippable if the server already has it, `GET /blobs/{sha}` streams it back. Records reference hashes. Uploads are resumable and happen on a separate queue that can be slow without blocking anything.

**Concurrency:** sync is a single serialised actor. Never two runs in flight. It triggers on launch, on returning to foreground, every 5 minutes while active, and after any local write settles for 10 seconds.

**Failure is normal.** Offline is not an error state and must never produce an alert. The only sync UI is a small status in Settings and, if a push has failed repeatedly for over an hour, one quiet line in Today.

### 3.5 API surface

Versioned under `/v1`. All bodies are `StudyBotCore` DTOs, so client and server can't disagree about shape.

| Route | Purpose |
|---|---|
| `POST /v1/auth/pair` | Exchange a one-time pairing code for a device token |
| `GET /v1/sync` | Pull changes since a cursor |
| `POST /v1/sync` | Push dirty records, receive authoritative versions |
| `PUT /v1/blobs/{sha}` | Upload an attachment, idempotent |
| `GET /v1/blobs/{sha}` | Download an attachment |
| `POST /v1/ai/run` | Run an AI capability, streamed via SSE |
| `GET /v1/ai/budget` | Spend this month, cap, remaining |
| `GET /v1/ingest/status` | Per-source last sync, next attempt, last error |
| `POST /v1/ingest/run` | Force a poll now |
| `GET /health` | Liveness, for uptime monitoring |

**A worked example**, so payload shapes aren't guessed at:

```http
POST /v1/sync
Authorization: Bearer {token}
Content-Type: application/json

{
  "schemaVersion": 3,
  "deviceID": "1F0C…",
  "cursor": 4821,
  "records": [
    { "type": "assignment", "id": "9A3F…", "baseVersion": 7,
      "updatedAt": "2026-10-02T19:44:10Z", "deletedAt": null,
      "fields": { "title": "Programming coursework 1", "status": "drafting",
                  "dueDate": "2026-10-15", "fieldOverrides": ["dueDate"] } }
  ]
}
```

```json
{
  "cursor": 4839,
  "accepted": [ { "id": "9A3F…", "version": 8, "seq": 4839, "archivedAs": null } ],
  "conflicts": [ { "id": "2B71…", "serverVersion": 12, "resolution": "serverWins",
                   "archivedAs": "c_5512" } ],
  "changes": [ /* records with seq > request cursor, same shape as above */ ]
}
```

`archivedAs` appears on accepted records too, not only conflicts. When a client's write is accepted but overwrites a concurrent server-side edit, that server version is archived and named here. Without it, that direction of loss is silent — the conflict list only covers the case where the client loses.

Notes on the shape: `fields` is a partial — only what changed — so an older client that omits fields it doesn't know about cannot erase them. `conflicts` always names where the losing version was archived. `changes` and `accepted` arrive in the same response so one round trip completes a sync.

DTOs carry a `schemaVersion`. The server accepts the current version and one behind, so a client that hasn't updated keeps working.

### 3.6 Authentication

Single user, no passwords, no email infrastructure.

1. `studybotctl pair` on the server prints a six-word code, valid ten minutes, single use.
2. The Mac posts it to `/v1/auth/pair` and receives a long-lived token.
3. The token lives in the Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Sent as `Authorization: Bearer`.
4. The server's `device_tokens` table records a device name, creation date and last-seen time. Any token is revocable individually, so a lost laptop costs one revocation rather than a migration.

Each Mac pairs separately and holds its own token, named so you can tell them apart in Settings ("MacBook Pro", "Mac mini") and revoke one without touching the other.

**Installing on the second Mac:** build once, copy the `.app` across. macOS has no per-device provisioning, so a locally-signed build runs anywhere — Gatekeeper shows an unidentified-developer warning the first time, cleared with right-click → Open. Once the Developer Program is taken and the app is notarised, that warning disappears and the iPhone becomes one more pairing. Nothing else changes.

### 3.7 The AI proxy

The client never holds the OpenAI key and never calls OpenAI. It calls `/v1/ai/run` with a capability name and a payload; the server assembles the provider request.

Everything that needs enforcing lives here because it's the only place enforcement is possible:

- **Hard spend cap.** A monthly ceiling. At 80% the response carries a warning flag the UI surfaces. At 100% the server returns `402` with the remaining budget and refuses to call the provider. No exceptions, no "just this one". A bill that surprises you is a failure of the system, not of your discipline.
- **Response cache.** Keyed on `SHA256(capability + model + normalised input)`, 30-day TTL. Re-running `structureNotes` on unchanged notes costs nothing and returns instantly. This alone will cut spend substantially, since re-running after a small edit is the common case.
- **Rate limit.** Token bucket per device token: 60 requests/minute overall, 10/minute for AI. `429` with `Retry-After`; the client's `Retrier` honours it with jitter.
- **Accounting.** Every run writes capability, model, token counts and cost to `ai_runs`. This table is both the budget ledger and the AI-use record required by §7.5.
- **Confidentiality, twice.** The client excludes work-confidential content at prompt assembly (§7.4). The server additionally rejects any payload flagged confidential with a `422`. Defence in depth, because the failure mode is company data leaving the estate.
- **Provider seam.** One `ModelProvider` protocol. Swapping model or vendor is one file on the server and no client change at all.

Responses stream back over SSE so long outputs appear progressively rather than after a ten-second pause.

### 3.8 Ingestion on the server

Polling runs server-side on a schedule, which is the entire reason for having a server: ELE2 gets checked whether or not the Mac is open.

- ELE2 hourly, university mail every 15 minutes, GitHub every 30. All with ETag or `If-Modified-Since` so unchanged responses cost nothing.
- Every poller is idempotent and keyed on an upstream ID. Running twice must never duplicate anything.
- Results become **proposals** (§8.7), never direct writes.
- A failing source backs off exponentially to a one-hour floor and records a plain-language error visible at `/v1/ingest/status`.

**On the university token living on the VPS** — you've accepted this, and it's a reasonable call on a box you control. Three things make it defensible, and they should be built rather than assumed:

1. The token is read-only in scope. Never store a password; use Moodle's token endpoint or the private calendar URL, both of which are revocable from your ELE2 account without touching your login.
2. Real controls are access controls: SSH keys only, root login disabled, password auth off, UFW allowing 80/443/22 only, fail2ban, unattended security upgrades.
3. Encrypting secrets at rest on the same machine that holds the decryption key is theatre. Don't build it and don't let it create false confidence. Secrets live in a `0600` env file outside the repo.

If ELE2 access is ever revoked or the box is compromised, the blast radius is read access to your own coursework. Worth being clear-eyed about rather than anxious.

### 3.9 Caching and performance

**Client.** SwiftData is the cache; there is no second cache layer. Attachments on disk keyed by SHA. Derived values that are expensive and stable — working-days-until, deadline density, KSB coverage — are computed once per data change and stored, not recomputed per view render.

**Server.** AI response cache (§3.7), HTTP `ETag` on sync pulls, upstream response caching on all pollers.

**Budgets, to be measured rather than hoped for:**

| | Target |
|---|---|
| Cold launch to interactive | < 400ms |
| Keystroke to glyph in live notes | < 16ms |
| Assignment list scroll | 120fps on ProMotion |
| Sync round trip, typical delta | < 500ms |
| Any UI thread block | never > 50ms |

The live-notes editor is the one real performance risk: the styled mirror layer must diff by line and re-style only what changed. Re-laying out the whole document per keystroke will feel broken by the second page, and this is exactly the kind of thing that only shows up in a real lecture.

### 3.10 Security

- TLS via Caddy with automatic certificates. HTTP redirects to HTTPS. HSTS on.
- All tokens in the Keychain on device, `0600` env file on the server, nothing in the repo, nothing in `UserDefaults`.
- **No user content in logs, ever.** Log that a sync ran and how many records moved. Never what they contained.
- Request bodies capped; blob uploads capped at 100MB with a content-type allowlist.
- The server holds one user's data and should be firewalled accordingly: no public ports beyond 80, 443 and SSH.
- Dependencies pinned, reviewed on update. A server with four dependencies is a server you can actually reason about.

### 3.10a Distribution and updates

Not on the App Store, and two Macs to keep level. "Which machine is running the old build" must never be a question you have to investigate.

**The check.** An `UpdateChecker` protocol with one job: compare the running build against the latest published release.

- `GitHubReleaseChecker` polls `GET /repos/{owner}/{repo}/releases/latest` once a day and on launch, with `ETag` so unchanged checks are free. It compares the release tag against the build's embedded version, which is stamped at build time from `git describe`.
- Result surfaces quietly: a line in Settings, and one line in Today only when the build is more than one release behind.

**The install, two paths behind the same protocol:**

| | Free (now) | With the Developer Program (later) |
|---|---|---|
| Mechanism | App reports a new version; a `./update.sh` on each Mac pulls and rebuilds | Sparkle appcast on GitHub Releases, signed, self-installing |
| User action | Run one command | None |
| Why not Sparkle now | An un-notarised downloaded build can be quarantined and blocked outright by Gatekeeper, so a self-install would fail confusingly | — |

Build `GitHubReleaseChecker` now and add `SparkleUpdater` later. Only the installer changes.

**The two-Mac guard, which matters more than the updater.** DTOs carry a `schemaVersion` (§3.5). If one Mac is updated and the other isn't:

- The server accepts the current schema version and one behind, so a one-version gap is invisible and everything keeps working.
- A client more than one version behind gets `409` from `/v1/sync` with the required version. It stops syncing, keeps working fully offline, and shows: "This Mac is running an old version of StudyBot. Update it to sync again." It does not silently half-sync, and it never drops a local change.
- Local data is never migrated downward. An old client that sees records it doesn't understand preserves them untouched rather than dropping unknown fields on the next write — otherwise the stale Mac quietly erases fields the updated one just added.

That last point is the single most likely way this setup loses data, and it's cheap to prevent: unknown fields are round-tripped, not discarded.

### 3.10b Server configuration and deployment

**Environment**, in a `0600` file outside the repo. No secret is ever committed, and the repo carries a `.env.example` with every key present and every value blank.

```
STUDYBOT_DB_PATH          /var/lib/studybot/studybot.sqlite
STUDYBOT_BLOB_PATH        /var/lib/studybot/blobs
STUDYBOT_PAIRING_SECRET   used to sign pairing codes
OPENAI_API_KEY
OPENAI_MODEL              the default capability model
AI_MONTHLY_CAP_PENCE
ELE2_BASE_URL
ELE2_TOKEN                Moodle web-services token, read-only scope
ELE2_ICS_URL              the private calendar fallback
MS_CLIENT_ID / MS_CLIENT_SECRET / MS_TENANT / MS_REFRESH_TOKEN
GITHUB_TOKEN              fine-grained, read-only
SMTP_* or RESEND_API_KEY  for the Sunday digest
LITESTREAM_*              replica bucket credentials
LOG_LEVEL
```

**Deployment** is `docker compose up` on the VPS behind Caddy, which handles TLS automatically. Three containers: app, Caddy, Litestream. Deploy on tag push via GitHub Actions over SSH; the previous image stays for rollback.

**The repo README must carry, as runnable steps rather than prose:** how to run the server locally with a seeded database, how to generate a pairing code, how to restore from a Litestream replica, and how to rotate each credential. Written the week they're built, not the week they're needed — a restore procedure you're reading for the first time during an actual loss is not a procedure.

**Local development** uses a separate database and a fake `ModelProvider` that returns canned responses, so building a feature never costs money and tests never touch the network.

### 3.11 Backup and recovery

- **Litestream** replicating the SQLite file continuously to object storage (Backblaze B2 or Cloudflare R2, pennies a month). Point-in-time recovery.
- **Nightly `VACUUM INTO` snapshot**, retained 30 days, in the same bucket.
- **Blobs** replicated to the same bucket on upload.
- **A two-machine drill before you rely on the app:** edit the same note on both Macs while both are offline, bring them back, and confirm the losing version is archived and reachable rather than gone. Repeat once a term.
- **A restore drill before you rely on the app**, and once a term after that. Untested backups are decoration. Write the restore steps in the repo README, not in your head.
- The client's own export (§16) remains independent of all of this, because the server is one machine and one machine can be lost.

### 3.12 Testing

Enough to sleep, not so much it eats the build. The bar below is the required minimum, not an aspiration.

**Three tiers:**

| Tier | Scope | Runs |
|---|---|---|
| Unit | Pure logic in `StudyBotCore` and `StudyBotKit`. No database, no network. | Every commit |
| Integration | API routes against an in-memory SQLite server; sync against two simulated clients. | Every commit |
| Data-safety | Crash, conflict and restore scenarios. Slower, allowed to take minutes. | Every commit; blocking on release |

**The full matrix.** Every row is required before the component ships.

| Component | Must be tested | Tier |
|---|---|---|
| ICS import | 156 events parse; line unfolding; all-day `DTEND` is exclusive so a 22–25 event is 22–24; re-import is idempotent on `sourceUID`; a changed date updates in place; a removed event is marked cancelled and its notes survive | Unit |
| `WorkingDays` | Excludes bank holidays, closures and campus days; counts across a term boundary; returns 0 rather than negative for a past date | Unit |
| `TermCalendar` | Correct term for any date in the three years; days-to-next-block; week-of-term; behaviour in the gap between terms | Unit |
| `DeadlineDensity` | Detects the 1–20 July 2027 cluster from a date in October 2026; does not fire on two spaced submissions | Unit |
| Sync merge | Clean push; clean pull; conflicting edit resolves to later `updatedAt`; an exact `updatedAt` tie resolves identically on both clients via `deviceID`; loser is archived; tombstone propagates; cursor paginates past 500 records; a replayed push is idempotent | Unit |
| Sync engine | Interrupted mid-push leaves no partial state; resumes from the last cursor; never runs twice concurrently; offline produces no user-facing error | Data-safety |
| Two-client convergence | Two simulated clients edit different records offline, both converge; both edit the same record, one wins and the loser is retrievable | Data-safety |
| Confidentiality guard | Content flagged confidential never appears in an assembled prompt, through any code path; the server rejects a flagged payload with 422 | Unit + Integration |
| AI budget | Blocks at 100%; warns at 80%; a cache hit costs nothing and is not counted; concurrent requests cannot exceed the cap | Unit + Integration |
| AI cache | Identical input returns the cached response; whitespace-only change still hits; a changed capability misses | Unit |
| Rate limiter | Token bucket refills correctly; returns 429 with `Retry-After`; the client's `Retrier` honours it with jitter | Unit |
| Auth | A pairing code is single-use and expires in 10 minutes; a revoked token is refused; two devices hold independent tokens | Integration |
| Blob store | Upload is idempotent on SHA; a corrupted upload is rejected; download streams; a missing blob 404s rather than hanging | Integration |
| VTT/SRT import | Timestamps and cue numbers stripped; consecutive same-speaker lines merged; malformed input fails cleanly | Unit |
| PDF/DOCX/PPTX extraction | Text extracted; a scanned PDF falls through to OCR; an encrypted PDF produces a legible error | Unit |
| Leitner scheduling | Correct promotes a box; incorrect resets to box 1 and increments lapses; intervals are 1/3/7/16/35; the due queue excludes future cards | Unit |
| Grade arithmetic | Weighted progress; mark needed on remaining assessments; reports honestly when a target has become unreachable | Unit |
| OTJ totals | Weekly and cumulative totals; week boundaries; export mapping produces the configured column order | Unit |
| Proposal queue | Confirming applies the payload exactly once; dismissing prevents re-proposal of the same `sourceRef`; a duplicate poll creates no second proposal | Unit + Integration |
| Ingestion pollers | Running twice creates nothing new; a 304 does no work; a failure backs off exponentially and records a legible error | Integration |
| Migrations | One test per schema version loading a store written by the previous version | Data-safety |
| Backup/restore | Export, wipe, restore into a clean install with nothing lost; restore from a Litestream replica and reconcile a client | Data-safety |
| Scheduled routines | Each is idempotent across repeat runs; a routine never calls the AI without a tap; a missed Monday prep is skipped rather than fired late; a failure is silent and logged | Integration |
| Work-back plan | Milestones land on working days only, never on campus days or closures; the 2-day submit buffer is preserved; insufficient time is reported rather than compressed | Unit |
| Menu bar | Timer elapsed time survives the app being backgrounded; quick note files without a module; Escape discards | Unit + UI |
| Edit mode | Cancel with changes prompts and discards; Save writes once and marks dirty; `⎋` exits edit mode before closing the panel; editing offline never blocks | Unit + UI |
| Field ownership | ELE2 updates an untouched field directly; an overridden field is preserved and raises a proposal plus a marker; "use theirs" clears the override | Integration |
| Draft import | `.docx` with footnotes, tables and references extracts in reading order; a file changed on disk re-extracts and snapshots; switching source keeps the old text | Unit |
| Schema-version guard | A client one version behind syncs normally; two behind is refused with 409 and loses nothing; an old client round-trips unknown fields instead of dropping them | Data-safety |
| Update checker | Correct comparison of build tag to release tag; a 304 does no work; a network failure is silent | Unit |
| Search index | Incremental update on save; rebuild from models produces identical results; `module:` and `before:` filters parse; an unknown filter is treated as text | Unit |
| OneNote mirror | A changed page updates in place and keeps a revision; a deleted page is orphaned, not removed; nothing is ever written back | Integration |
| Grade ingest | A new grade applies directly and notifies; a changed grade goes to the proposal queue instead | Integration |
| Notes editor | Styling never changes character count or metrics; caret position after a styled line matches an unstyled one; 500-line document stays under the 16ms keystroke budget | Unit + performance |

**UI tests: two only.** Type a note, relaunch, confirm it survives. Confirm a proposal, verify it becomes a real assignment. Everything else is covered below the UI.

**The rule that matters more than the matrix:** any bug that lost or corrupted data gets a regression test written *before* the fix ships. No exceptions. Everything else can be fixed twice.

**Coverage target:** 80% on `StudyBotCore` and `StudyBotKit`. No target on view code — chasing coverage there produces tests that assert what the code does rather than what it should do.

**CI** on GitHub Actions: build both targets, run all three tiers, `swift-format` and SwiftLint as blocking checks. Deploy on tag push over SSH to a Docker Compose stack, previous image kept for instant rollback.

### 3.13 Code conventions

Written down because a three-year solo project is really you collaborating with someone who has forgotten everything.

- One type per file, named for the type.
- No force unwraps outside tests. No `try!`. Typed throws where the error is actionable.
- No logic in views. If a view has an `if` with more than two branches, it's a store's decision.
- Dates are always `Date` internally and formatted only at the edge, through `RelativeDate`.
- Money and token counts are integers. Never `Double` for currency.
- Every `TODO` carries a date and a name. Untracked TODOs get deleted on sight.
- Public API in packages carries doc comments; private implementation carries comments only where the *why* isn't obvious from the *what*.

---

## 4. Data model

**These are defined as value types (`struct`) in `StudyBotCore`**, because the same definitions compile into the Vapor server, which cannot use SwiftData. Relationships between value types are held as IDs, not nested objects — a struct cannot own a two-way object graph.

`StudyBotKit` wraps them in SwiftData `@Model` classes for local storage, converting to and from the Core structs at that boundary. SwiftData relationships there are bidirectional with explicit inverses. Nothing outside `StudyBotKit` knows SwiftData exists.

**Storage shape.** Each persisted row holds: the eight sync fields as real columns, a small set of promoted index columns, the whole Core value encoded as a JSON `body`, and an `unknownFields` blob. There are no SwiftData relationship properties and no inverses — relationships are id columns, as they are in Core.

The body is the record; index columns are derived from it on every write. This means adding a field to a Core struct needs no SwiftData migration, which over three years of revisions matters more than object-graph convenience. Cascading deletion (§16) is explicit code in the stores where it can be tested, rather than implicit SwiftData behaviour.

The cost, stated plainly: you can only query, sort or filter on a promoted column. Promoting one later is a migration, and it will want doing mid-feature when nobody has time. So promote everything a specified screen needs before building that screen, not when the query fails. The list is knowable from §6 in every case.

**Every syncable model carries the same eight fields**, defined once in `StudyBotCore` and not repeated in each listing below:

```
id: UUID              // client-generated, stable forever
createdAt: Date
updatedAt: Date       // bumped on every local edit; drives last-write-wins
version: Int          // server-assigned, 0 until first sync
baseVersion: Int      // the version this local edit was made against
seq: Int              // server sequence number, the sync cursor
deletedAt: Date?      // tombstone; rows are never hard-deleted
dirty: Bool           // has local changes not yet acknowledged
```

`ProgrammeEvent` is the one exception: it is derived from the bundled ICS, identical on every device, and therefore never synced. Each Mac imports it independently and arrives at the same result.

### Module

```
name: String               // "Discrete Mathematics for Computer Science"
code: String               // "COM1014DA"
colour: ModuleColour       // enum, from a fixed palette of 8
year: Int                  // 1, 2, 3
term: Term?                // nil when spansYear is true
spansYear: Bool            // Professional Development, Synoptic Project
credits: Int?
weighting: Double?         // share of the year, once known
isSpecialismOption: Bool   // year 3: offered but not yet chosen
isArchived: Bool           // unchosen specialisms, completed modules
assignments: [Assignment]
sessions: [Session]
```

Seed from the real programme structure. These are confirmed, not placeholders — codes and titles come from the official calendar.

**Year 1** — COM1018DA Programming · COM1014DA Discrete Mathematics for Computer Science · COM1013DA Object-Oriented Programming · COM1016DA Computational Mathematics · COM1015DA Computers and the Internet · COM1019DA Social and Professional Issues · COM1017DA Professional Development 1

**Year 2** — COM2022DA Database Theory and Design · COM2023DA Network and Computer Security · COM2024DA Software Development · COM2027DA Artificial Intelligence and Applications · COM2025DA Web Development · COM2026DA Team Project · COM2028DA Professional Development 2

**Year 3** — all ten specialism options are seeded from the calendar (COM3105DA–COM3114DA, covering Software Engineering, Business Analysis, IT Consulting, Data Analysis and Cyber Security) with `isSpecialismOption: true`. Two are chosen and the other eight archived. Plus COM3104DA Synoptic Project and COM3103DA Professional Development 3. Seven year-1 modules, seven year-2, twelve year-3 — **26 in total**, which is what the calendar yields.

Professional Development runs across all three terms of its year rather than sitting in one. Model it as a module with `spansYear: true` so the term grouping doesn't misplace it. The Synoptic Project runs across terms 2 and 3 of year 3 and needs the same treatment.

Year 3 specialisms are a choice not yet made. Show all five as selectable at the start of year 3 and archive the unchosen ones.

### Term

```
year: Int                  // 1, 2, 3
number: Int                // 1, 2, 3
startDate / endDate: Date  // derived from the first and last programme event
modules: [Module]
events: [ProgrammeEvent]
```

Nine terms total, September 2026 to July 2029.

### ProgrammeEvent

Every dated thing the university has told you about. Read-only: these come from the programme calendar, and the user cannot edit them — only attach their own work to them.

```
startDate / endDate: Date
kind: EventKind            // induction, onCampus, online, assignment,
                           // readingWeek, closure, bankHoliday, gateway, epa
title: String
moduleCodes: [String]      // which modules that block covers
sourceUID: String          // the ICS UID, for idempotent re-import
cancelledAt: Date?         // set when a re-import no longer contains this UID;
                           // never deleted, so attached notes survive
sessions: [Session]        // notes the user attaches to this event
assignment: Assignment?    // for kind == .assignment
```

`kind` drives colour and weight in every calendar surface. Bank holidays and closures are shown greyed and never generate a notification.

### Assignment

```
title: String
module: Module?
status: AssignmentStatus   // backlog, todo, drafting, review, submitted, graded
priority: Priority         // none, low, medium, high, urgent
dueDate: Date?
briefText: String?         // extracted from the PDF brief
rubricText: String?        // pasted by the user, drives the checker
wordLimit: Int?
weighting: Double?         // % of module mark
draftSource: DraftSource   // inApp | importedFile | oneNote
draftText: String?         // current text, whatever the source
draftSnapshots: [DraftSnapshot]
grade: Double?             // actual mark once returned
targetGrade: Double        // default 70
fieldOverrides: Set<String> // fields edited by hand; ELE2 must not overwrite these
feedback: String?          // tutor feedback, pasted in
subtasks: [Subtask]
attachments: [Attachment]
aiRuns: [AIRun]
evidence: [Evidence]       // assignments can also be KSB evidence
```

`AssignmentStatus` mirrors Linear's issue states in feel and ordering: backlog → todo → drafting → review → submitted → graded. Each has its own icon (§9).

### Session

```
title: String
module: Module?
block: Block?
date: Date
liveNotes: String          // typed during the session, raw and messy
transcript: String?        // pasted or imported
structuredNotes: String?   // AI output, markdown
openQuestions: [String]    // things to ask the tutor, captured live
attachments: [Attachment]  // slides
decks: [Deck]
```

Three text fields, deliberately separate. `liveNotes` is never overwritten by AI — structuring produces a new field so the user's own words survive.

### Deck / Card

```
Deck:  title, lecture?, module?, cards: [Card], lastStudied: Date?
Card:  front: String, back: String, source: String?   // which note it came from
       box: Int               // Leitner box 1–5
       dueDate: Date
       lapses: Int
```

Scheduling: Leitner intervals of 1, 3, 7, 16, 35 days. Correct answer promotes a box, incorrect resets to box 1 and increments `lapses`. Simple, predictable, no SM-2 tuning parameters to explain.

### QuizAttempt

```
deck: Deck?  or  session: Session?
questions: [QuizQuestion]   // prompt, options, correctIndex, explanation
answers: [Int]
score: Double
takenAt: Date
```

### KSB

```
code: String               // e.g. "K3", "S12", "B4"
category: KSBCategory      // knowledge, skill, behaviour
text: String               // the official wording
evidence: [Evidence]
coverage: CoverageLevel     // derived: none, partial, strong
```

**Important:** the KSB list must be imported from the published apprenticeship standard and whatever Exeter issues at induction. Do not invent codes or wording. Ship with an empty list and an import screen that accepts a pasted list or a CSV. See Open Questions (§14).

### Evidence

```
title: String
date: Date
summary: String            // what the user did, in their own words
ksbs: [KSB]                // many-to-many
source: EvidenceSource     // workProject, assignment, lecture, reflection, codeCommit
isWorkConfidential: Bool    // true blocks all AI processing — see §7.4
attachments: [Attachment]
otjEntry: OTJEntry?        // evidence can double as an off-the-job entry
reflection: String?        // what went well, what you'd change
```

### OTJEntry

```
date: Date
hours: Double
category: OTJCategory      // see Supporting types
description: String
assignment: Assignment?
evidence: Evidence?
isSubmittedToProvider: Bool
```

The required format from Exeter is unknown until induction. Build the model with the fields above, and make the **export** configurable rather than the model — a column-mapping screen where the user picks which fields go into which columns, in which order, with a chosen date format. That way an unexpected provider template is a settings change, not a migration.

### Proposal

The queue in §8.6. Central to the product and previously undermodelled.

```
kind: ProposalKind         // newAssignment, dateChange, briefImported,
                           // resourceImported, hoursEntry, evidenceSuggestion
source: ProposalSource     // ele2, universityMail, workCalendar, github,
                           // programmeCalendar, aiSuggestion
sourceRef: String          // upstream ID; makes ingestion idempotent
title: String              // one line, as shown in the queue
payload: Data              // the proposed change, a Codable DTO
targetID: UUID?            // the record it would modify, if it exists
state: ProposalState       // pending, confirmed, dismissed
dismissedReason: String?   // feeds back into classification
createdAt / resolvedAt: Date?
```

Rules: a proposal is never auto-applied. Confirming it applies `payload` and sets `state = .confirmed`. Dismissing keeps the row so the same upstream item is never proposed twice. **Proposals never expire.** Uniqueness is `(source, sourceRef, kind)`.

### NoteRevision

Local-only, never synced. Independent insurance against both the sync engine and the app.

```
session: Session
body: String
capturedAt: Date
reason: RevisionReason     // idleSnapshot, preSync, conflictLoser
```

Last 20 per session on a 30-second idle debounce, plus one before any sync overwrite. Conflict losers (§3.4) are kept 30 days and surfaced on the note.

### Settings

One row. Local, synced, so both Macs agree.

```
targetOTJHoursPerWeek: Double      // default 6
gradeBands: [GradeBand]            // distinction 70, merit 60, pass 50, threshold 40
monthlyAIBudgetPence: Int
notificationPrefs: NotificationPrefs
otjExportMapping: [ExportColumn]   // configurable until Exeter's format is known
specialismChoices: [String]        // year 3
```

### Server-only tables

Not SwiftData; these live in the server's SQLite and have no client model.

```
device_tokens    id, name, tokenHash, createdAt, lastSeenAt, revokedAt
conflict_archive id, recordID, recordType, body, losingUpdatedAt, archivedAt
ai_runs          id, capability, model, inputTokens, outputTokens,
                 costPence, cacheHit, createdAt, relatedAssignmentID
ai_cache         inputHash, capability, model, response, createdAt
ingest_state     source, lastSuccessAt, nextAttemptAt, etag,
                 consecutiveFailures, lastError
sync_log         seq, recordID, recordType, deviceID, at
```

`ai_runs` is both the budget ledger and the AI-use record required by §7.5.

### Attachment

```
filename: String
uti: String
localURL: URL
extractedText: String?     // from the importer
sourceKind: enum           // localFile, oneDrive, sharePoint, github
remoteID: String?
```

### AIRun

```
capability: AICapability   // see §7.2
promptSummary: String      // human-readable, for the AI-use record
inputTokens / outputTokens: Int
model: String
output: String
acceptedByUser: Bool
timestamp: Date
relatedAssignment: Assignment?
```

This table is the AI-use record. It exists so the user can answer "where did AI help on this piece of work" with a real answer rather than a recollection.

### Supporting types

Referenced throughout and defined once here. All live in `StudyBotCore`.

```
Subtask               title: String, isDone: Bool, dueDate: Date?,
                      order: Int, createdBy: .user | .workBackPlan

GradeBand             label: String, minimum: Double, colour: BandColour
                      defaults: Distinction 70, Merit 60, Pass 50, Threshold 40

NotificationPrefs     deadlines: Bool, morningPlan: Bool, morningPlanTime: WallClockTime,
                      otjPacing: Bool, gradeReturned: Bool, sessionStarting: Bool,
                      sundayReview: Bool, sundayReviewEmail: Bool

ExportColumn          header: String, field: OTJField, order: Int,
                      dateFormat: String?        // configurable until Exeter's format is known

ModuleColour          One of eight fixed values, all desaturated so no module dominates:
                      indigo #5E6AD2 · green #4A9E6B · amber #D9A441 · clay #B4695E
                      violet #7B6BA8 · teal #3E8E9E · brown #9A7B5E · slate #6B7280
                      Assigned round-robin on import; user-changeable.

AssignmentStatus      backlog, todo, drafting, review, submitted, graded   (list order)
Priority              none, low, medium, high, urgent
OTJCategory           lecture, workshop, selfStudy, mentoring, shadowing,
                      projectWork, research, writingUp, training
EventKind             induction, onCampus, online, assignment, readingWeek,
                      closure, bankHoliday, gateway, epa
RevisionReason        idleSnapshot, preSync, conflictLoser
DraftSource           inApp, importedFile, oneNote

WallClockTime         hour: Int, minute: Int
                      A time of day with no date and no timezone. Required
                      anywhere a thing is scheduled by the clock — the 07:00
                      Monday prep, the 18:00 Sunday review, the morning plan.
                      Storing these as `Date` silently shifts them by an hour
                      twice a year when BST changes. Resolve to an instant
                      only at scheduling time, in Europe/London.
```

**What counts as attended.** A session is attended if it has notes with any content, or an off-the-job entry linked to it, or the user explicitly marked it attended. This matters because "session gap" (§4A) and the Sunday review both depend on it, and an app that decides you skipped a lecture because you took notes on paper will be wrong in an annoying way. Marking attended is one tap from the session and from the Sunday digest.

### Dates, times and locale

Silent bugs live here. All of it is fixed, not configurable.

- **Locale `en-GB`, timezone `Europe/London`** throughout. The user is in England for the whole three years.
- **Weeks start Monday.** Every "this week" calculation, the off-the-job weekly target, and the Sunday review all run Monday 00:00 to Sunday 23:59.
- **Programme events are all-day and date-only.** Never given a time, never converted through a timezone. Store as `Date` at local midnight and compare by calendar day, not by interval.
- **The ICS `DTEND` on all-day events is exclusive.** A `DTSTART:20260923 / DTEND:20260925` event runs 23–24 September, not 23–25. This caught me parsing the real file; get it wrong and every block is a day too long.
- `updatedAt` keeps milliseconds when it has them. It decides last-write-wins, and two edits a second apart on two Macs would otherwise tie. Whole-second dates still encode exactly as the §3.5 example shows, so the wire format is unchanged for them.
- Ties break deterministically on `deviceID`, lexicographically, lower wins. Two edits can still land in the same millisecond, and worse, the two Macs' clocks will drift — `updatedAt` is client wall clock, so a machine running 400ms fast can win an exchange it should have lost. Neither problem is worth solving properly for one user, but both Macs must reach the same answer. A tie resolved differently on each machine is how a record ends up permanently disagreeing with itself, and that failure is very hard to see and very hard to undo.
- **British Summer Time changes twice a year during term.** Anything scheduled by wall-clock time (the 07:00 Monday prep, the 18:00 Sunday review) must be scheduled in local wall-clock terms, not as a fixed UTC offset, or it drifts by an hour twice a year.
- Dates are formatted only at the edge, through `RelativeDate`: under 14 days relative ("in 11 days"), beyond that absolute ("15 Oct"), and the year shown only when it isn't the current one.
- **Working days** exclude weekends, bank holidays, closures and on-campus days — all read from the programme calendar, never hardcoded.

---

## 4A. The programme calendar

*(Numbered 4A deliberately: it was added after the section numbering was set, and renumbering would break cross-references throughout.)*

The whole three years is known in advance. This is the single biggest advantage the app has, and most of its value comes from using it.

**Files shipped with this spec:**
- `DTS_L6_Sept_2026_intake.ics` — the official calendar, 156 events
- `programme-calendar.json` — the same data parsed into `{ start, end, kind, title, modules[] }`

### What's in it

| Kind | Count | Notes |
|---|---|---|
| Online sessions | 87 | Mondays, alternating lectures and workshops |
| Mandatory submissions | 30 | All via ELE2 |
| Bank holidays | 21 | |
| On-campus blocks | 8 | Two or three days each |
| Reading weeks | 5 | |
| University closures | 2 | Christmas |
| Induction | 1 | 22 September 2026 |
| Gateway | 1 | 14 June 2029 |
| EPA window | 1 | 16–27 July 2029 |

### On-campus blocks

| | Dates | Term | |
|---|---|---|---|
| Block 1 | Tue 22 – Thu 24 Sep 2026 | Y1 T1 | induction + 2 on-campus days |
| Block 2 | Mon 4 – Wed 6 Jan 2027 | Y1 T2 |
| Block 3 | Tue 4 – Thu 6 May 2027 | Y1 T3 |
| Block 4 | Tue 21 – Wed 22 Sep 2027 | Y2 T1 |
| Block 5 | Tue 11 – Thu 13 Jan 2028 | Y2 T2 |
| Block 6 | Wed 3 – Fri 5 May 2028 | Y2 T3 |
| Block 7 | Mon 18 – Wed 20 Sep 2028 | Y3 T1 |
| Block 8 | Mon 8 – Wed 10 Jan 2029 | Y3 T2 |

### Year 1 deadlines

15 Oct 2026 · 3 Dec 2026 · 17 Dec 2026 · 18 Mar 2027 · 1 Apr 2027 · 1 Jul 2027 · 8 Jul 2027 · 13 Jul 2027 · 15 Jul 2027 · 20 Jul 2027

Note the shape: a quiet autumn, a very quiet spring, then five submissions in twenty days at the end of the year. The app must make that July cluster visible from October, not from June.

### Import behaviour

- The ICS is **bundled in the app** and imported on first launch. No setup step, no file picker, no empty first run.
- Re-import is idempotent, matched on `sourceUID`. The university will reissue the calendar; changed dates update in place, new events are added, removed events are marked cancelled rather than deleted so any notes attached to them survive.
- Settings offers "Update programme calendar" with a file picker for the reissued ICS.
- A mandatory submission event creates a matching `Assignment` in backlog status with the due date already set. **It is titled by date — "Submission due 15 October 2026" — with no module attached.** Titling by module is impossible and the file shows why: of the 30 submissions, 20 name all three of their term's modules and 10 name none at all. Guessing which module a submission belongs to would be wrong roughly two-thirds of the time. The module arrives with the brief from ELE2, and until then the stub stays honest about not knowing.
- **Adjacent on-campus days merge into one block.** Induction on 22 September and the on-campus days of 23–24 September are three consecutive days on campus and are presented as a single block, 22–24 September, not as two things. The merge is by adjacency of campus-kind days, not a special case for induction.
- **Nobody should ever type a deadline into this app by hand.**

### Term boundaries

The calendar never labels its terms, so they are derived. The rule, verified against the real file:

**A term is the contiguous run of module-bearing events sharing one module set.** The set changes at exactly eight points across the three years, and those eight points are the term boundaries. Events with no modules attached — deadlines, bank holidays, closures, Gateway, the EPA window — join the term before them and may extend its end date, except bank holidays, closures and the un-moduled summer reading weeks, which never extend a term. Real gaps therefore exist between terms, which is correct.

**Do not assume a term starts at its on-campus block.** The file contradicts this: in 2027 the reading week of 19 April and the session of 26 April already carry term-3 modules, while Block 3 is 4–6 May. The same shape repeats in 2028. A gap-based rule also fails — year 3's final term has a 35-day gap inside it, between 18 April and 23 May 2029.

**Year 3's specialism-2 options and the Synoptic Project are year-spanning.** All of `COM3106DA`, `COM3108DA`, `COM3110DA`, `COM3112DA`, `COM3114DA` and `COM3104DA` appear on every event from 8 January to 23 May 2029, across the term-2/term-3 boundary. They therefore carry `spansYear: true`, the same as Professional Development. Confirm with Exeter alongside open question 13 — it may be a quirk of how the calendar was written rather than how the modules are actually taught.

**Year 3 is the exception.** Its module set changes only once, because the Synoptic Project spans terms 2 and 3, so the calendar gives no signal for where year-3 term 3 begins. Default to **18 April 2029**, the first teaching event after the Easter bank holidays, which matches the April term-3 starts in years 1 and 2. Encode it as that rule, not as a hardcoded date, and confirm it with Exeter (§14).

### Derived signals

These are computed from the calendar and used across the app:

- **Days to the next on-campus block** — drives the Today banner and the promotion of Block mode.
- **Deadline density** — a rolling count of submissions in any 21-day window. When a future window exceeds two, it is a crunch, and it appears in Today from eight weeks out with the work that should be happening now.
- **Session gap** — days since the last attended online session with no notes attached. Three consecutive empty Mondays is the signal that the drumbeat has slipped.
- **Working days available** before a deadline, excluding bank holidays, closures and on-campus blocks. This is what the study planner schedules into, and it is usually a lot less than the raw day count suggests.

---

## 5. Information architecture

### Sidebar (macOS) / Tab bar (iOS)

1. **Today** — landing view
2. **Assignments**
3. **Modules & notes** — expandable, each module lists its lectures
4. **Revision**
5. **Portfolio** — KSBs, evidence, and the off-the-job log as a segmented section within

Nested rather than top-level:
- **Off-the-job log** lives inside Portfolio, since every hour logged is potential evidence and the two are entered together.
- **Files & briefs** have no home of their own. A file belongs to an assignment, a lecture or a piece of evidence, and is only ever seen in that context.
- **Block mode** is a mode, not a destination. Today promotes it when a block is active or imminent.
- **AI** has no sidebar item at all. It is summoned with ⌘K from anywhere and knows what is on screen.

### iOS adaptation

Five tabs map one-to-one to the five sidebar items. Modules & notes becomes a drill-down list. The command palette is reached by a persistent search field at the top of Today and by pull-down on any list. Every destructive or creating action available on Mac is available on iOS.

---

## 6. Screens

### 6.0 First run

The first two minutes decide whether this feels like a finished product or a project. An AI building this should not have to invent any of it.

**Launch one, before anything is configured, the app is already useful.** The programme calendar is bundled, so within a second of first launch there are 9 terms, 26 modules, 156 events and 30 dated submissions in the list. No empty state, no "get started" wizard, no sample data to delete.

Sequence:

1. **A single screen, not a carousel.** "StudyBot — your programme is already loaded." Below it, three lines of real numbers pulled from the import: 30 submissions, first one 15 October 2026, induction in 8 days. One button: **Continue**.
2. **Straight to Today.** Fully working: assignments, notes, revision, evidence, the lot. Everything local.
3. **A single dismissible row at the top of Settings** — "Connect StudyBot to your server to sync with your other Mac." Not a modal, not a blocking step. The app is honest that it works without it.

**Server pairing, when the user chooses to:** Settings → Sync → Pair this Mac → a six-word code field → paired, named, syncing. The second Mac repeats it. If the server is unreachable, the error names the likely cause rather than saying "failed".

**Integrations are all opt-in and independent**, each a row in Settings with its own connect button: ELE2, university mail, OneNote, GitHub. None is required. None blocks another. The app must be fully usable with every one of them off, because on day one every one of them is off.

**What must never happen on first run:** a login wall, a request for an API key before anything works, an empty screen with an illustration, a tour, or a request for notification permission before there is anything to notify about. Ask for notification permission the first time the user enables a notification type, not at launch.

### 6.1 Today

The default view on launch. Answers three questions in order, without scrolling on a laptop screen.

```
┌──────────────────────────────────────────────────────────┐
│  Monday 14 September                                     │
│                                                          │
│  Block 1 starts in 8 days           22–24 Sept  →        │
│  ─────────────────────────────────────────────────       │
│                                                          │
│  Next deadline                                           │
│  ◐  Software Engineering — Requirements report           │
│     due in 12 days · 2,500 words · drafting              │
│                                                          │
│  Today's plan                            Suggested       │
│  ○  Draft section 2 of the requirements report   90m     │
│  ○  Review Tuesday's lecture notes               30m     │
│  ○  Log Thursday's sprint work as evidence       10m     │
│                          Accept plan    Dismiss          │
│                                                          │
│  Off-the-job                                             │
│  4.5 of 6 hours this week          ▓▓▓▓▓▓▓░░             │
│  Log hours →                                             │
└──────────────────────────────────────────────────────────┘
```

Below the fold, a **term strip**: a single horizontal line for the current term showing on-campus blocks, Monday sessions as small ticks, submissions as dots, and today as a marker. It is the only place the three-year calendar is visible, and it is deliberately small — one glance, no interaction beyond tapping a marker to jump to it.

Rules:
- The block banner appears only within 14 days of an on-campus block, or during one. Tapping it opens Block mode.
- A **crunch warning** replaces the banner when the next 21-day window ahead contains three or more submissions and is within eight weeks: "Five submissions between 1 and 20 July. Start the AI module report now."
- **Next deadline** shows exactly one assignment: the soonest incomplete one. Overdue items turn the row red and the label becomes "overdue by".
- **Today's plan** is a proposal, never an imposition. It is generated locally from due dates, remaining subtasks and estimated effort, not by the AI — it must work offline and instantly. Three items maximum. "Accept plan" converts them to today's checklist and, if calendar write is enabled, offers to book them into free slots. "Dismiss" hides the plan until tomorrow and never asks why.
- **Off-the-job** shows the week's hours against target, with a muted amber state when behind and no colour at all when on track. No red. Being behind on hours mid-week is normal.

### 6.2 Assignments

The centrepiece. Linear's issue list, adapted.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Assignments            All modules ▾   Status ▾        + New        │
├──────────────────────────────────────────────────────────────────────┤
│  Drafting                                                      2     │
│  ◐  Requirements report            SE      ▮▮▮   26 Sep    68% ░░    │
│  ◐  Database normalisation task    DB      ▮▮    14 Oct    20% ░░    │
│                                                                      │
│  Todo                                                          3     │
│  ○  Network protocols essay        CSN     ▮▮▮▮  30 Oct           │
│  ○  Security case study            CYB     ▮     12 Nov           │
│                                                                      │
│  Graded                                                        1     │
│  ✓  Programming portfolio 1        PF            submitted   74     │
└──────────────────────────────────────────────────────────────────────┘
```

- **Default scope is the current term.** The calendar seeds 30 submissions across three years; showing all of them on day one would be 29 italic placeholders and one real assignment, which reads as broken. A scope control in the header offers Current term (default), Current year, and All. The choice persists in `Settings`.
- When scoped, a muted line at the foot of the list reads "18 more submissions in later terms — show all", so nothing is hidden without being acknowledged.
- Grouped by status, collapsible, count on the right of each header.
- Row height 36pt on macOS, 44pt minimum on iOS.
- Columns: status icon, title, module chip, priority bars, due date, progress or grade.
- Grade appears as a number, coloured by band: distinction green, merit indigo, pass grey, fail red. Bands are configurable (§12).
- Clicking a row opens the detail view. On macOS this is a third column; on iOS a push.
- Keyboard: `c` new assignment, `↑↓` navigate, `⏎` open, `s` status menu, `p` priority menu, `d` due date, `⌫` delete with confirm.

#### Assignment detail

Sections, in order: title and module, status and priority and due date, the brief, the rubric, subtasks, draft, attachments, grade and feedback, linked evidence.

**Editing is a mode, not a free-for-all.** The panel is read-only by default. A primary **Edit** button sits top-right in the panel header; pressing it makes the whole panel editable at once.

- **Read mode** — everything is display text. Chips show status, due date and source. No input borders, no affordances, nothing that looks clickable but isn't.
- **Edit mode** — chips become controls (status menu, priority menu, date picker), the title becomes a text field, and the brief and rubric gain visible input borders. The header swaps to **Cancel** (secondary) and **Save changes** (primary).
- **Save is explicit.** Nothing is written until Save. Cancel discards everything and returns to read mode; if anything was changed, it confirms first — "Discard changes to this assignment?" — because losing a pasted rubric to a stray Escape would be maddening.
- **Keyboard:** `⌘E` enters edit mode, `⌘S` saves, `⎋` cancels. In edit mode `⎋` does not close the panel; it exits edit mode first, and a second `⎋` closes.
- **Scope of what's editable:** title, module, status, priority, due date, word limit, weighting, brief, rubric, subtasks, grade and feedback. **Not editable:** the ELE2 source link, the originating programme event, imported attachments' contents, and anything in the AI-use record.
- The draft is the exception and stays directly editable outside edit mode — it's a writing surface, and requiring a mode switch to type a sentence would be absurd.
- Save bumps `updatedAt`, marks the record dirty and lets the sync engine take it from there. Editing works fully offline; the panel never waits on the network.

**Primary action below the fields is Check against rubric.** Outline and Draft a section stay secondary. It's the one that gets used most and the one that matters for grades, so it carries the weight. It stays disabled, with its explanation, until a rubric exists.

- **Brief** — drop a PDF, the importer extracts text, the AI offers to pull out deliverables, word count, weighting and deadline into structured fields for the user to confirm. Nothing is written without confirmation.
- **Rubric** — a plain text field the user pastes the real marking criteria into. This is what the checker marks against. Until it's filled, the checker button explains that it needs the rubric first rather than falling back to generic advice.
- **Draft** — three sources, because where you write changes per assignment (§6.2a). Whichever is current, `draftText` holds the text and every AI capability works identically against it. Word count against limit, live.
- **Grade and feedback** — entered after the fact. Feeds the distinction tracker and, later, the pattern analysis across assignments.

#### Who owns a field

Once ELE2 ingestion is live (§8.1), some fields have two sources: you, and the university. Your edit wins — with a visible disagreement rather than a silent one.

- `Assignment.fieldOverrides: Set<String>` records every field you have edited by hand.
- An ELE2 change to a field **you have never touched** applies directly. That's just the brief arriving.
- An ELE2 change to a field **you have overridden** does not overwrite it. Your value stays, and two things happen: a proposal appears in the queue ("ELE2 has 12 October for this, you have 15 October"), and the field itself carries a small marker in the detail panel — "ELE2 says 12 Oct" — with a one-tap "use theirs".
- The marker persists until you either accept theirs or edit the field again. It is never dismissed by simply ignoring it, because a disagreement about a deadline is exactly the thing you want nagging you.
- Clearing an override — via "use theirs" — removes the field from `fieldOverrides` and lets ELE2 own it again.

This is deliberately more visible than a normal proposal. Every other disagreement can wait; a date one is the difference between submitting and not.

### 6.2a Where drafts come from

You write in Word, sometimes OneNote, sometimes here. The app must not have an opinion about which, and must never become a place your work is trapped.

**Three sources, one field.** `draftSource` records where the text came from; `draftText` always holds the current text. Every AI capability — `checkDraft`, `outline`, `draftSection` — operates on `draftText` and neither knows nor cares about the origin.

| Source | How it works |
|---|---|
| `inApp` | The built-in editor. Serif, 17pt, measure capped, word count against limit. |
| `importedFile` | A `.docx`, `.pages` export, `.pdf` or `.md` on disk. Held as a security-scoped bookmark so it survives relaunch. |
| `oneNote` | A specific OneNote page, pulled through Graph (§8.5). |

**Import is a watch, not a one-off.** For `importedFile`, the app watches the bookmark with an `NSFilePresenter`. When the file changes on disk, it re-extracts, writes a new `DraftSnapshot` and shows one quiet line: "Draft updated from Requirements.docx, 2 minutes ago." No dialog, no interruption. This is what makes writing in Word painless — save in Word, the check in StudyBot is already against the current text.

**One-way, always.** StudyBot never writes back to Word, Pages or OneNote. Round-tripping formatted documents loses formatting, and losing formatting in a submission is unacceptable. The app is a reader of your drafts and a critic of them, never a co-author of the file.

**Switching source is allowed and non-destructive.** Start in the app, later attach a Word file: the in-app text is kept as a snapshot rather than discarded.

**`DraftSnapshot`** — `text`, `capturedAt`, `wordCount`, `source`, `checkedByAI: Bool`. Kept for every import and every AI check, so "what did the checker actually see" always has an answer. Last 30 retained.

**Extraction quality matters more than it sounds.** A `.docx` with footnotes, tables and a reference list must extract in reading order, with footnotes at the end rather than interleaved mid-sentence. Test against a real assignment-shaped document, not a paragraph of lorem ipsum.

### 6.3 Modules & notes

Sidebar expands to modules, each module expands to its lectures in date order. A lecture opens into the note workspace.

#### Note workspace

Two panes on macOS, tabs on iOS.

```
┌────────────────────────────┬─────────────────────────────┐
│  Live notes                │  Structured                 │
│                            │                             │
│  - normalisation, 3NF      │  ## Normalisation           │
│  - transitive dependency?? │                             │
│  - ASK: does 3NF matter    │  Third normal form removes  │
│    for the assignment      │  transitive dependencies…   │
│                            │                             │
│  ─────────────────────     │  ### Key definitions        │
│  Transcript        Import  │  …                          │
│  [paste or drop .vtt]      │  ### Open questions         │
│                            │  - Does 3NF matter for…     │
├────────────────────────────┴─────────────────────────────┤
│  Structure these notes        Make flashcards            │
└──────────────────────────────────────────────────────────┘
```

- **Live notes** is a fast, quiet editor. Notion's typography, not a code window: sans-serif at 15pt, line height 1.7, 28pt of horizontal padding, measure capped around 66 characters. Generous enough to read back weeks later, plain enough to type into without thinking.
  - No formatting toolbar, no slash menu, no autocomplete, nothing that steals a keystroke mid-session.
  - Light structure renders as you type, without changing what you typed: a leading `- ` renders as a bullet glyph in `textTertiary` with the text following in `textPrimary`; blank lines breathe; a line beginning `ASK:` takes an `accentSoft` background with `accent` text and a 2pt accent rule down its left edge.
  - **Implementation:** a transparent `UITextView`/`NSTextView` over a styled mirror layer, or attributed-string styling applied in place. The caret must land exactly where it looks like it should, so styling may change colour, background and left decoration but never font size, weight or character count. Heading sizes are deliberately not supported in the live pane for this reason — that's what the structured pane is for.
  - Placeholder on an empty pane: "Type. Sort it out later."
- Typing `ASK:` at the start of a line captures that line into `openQuestions` and shows it in a questions list. This is the single most valuable thing in an on-campus block: a list of things to ask before you leave the room.
- **Transcript** accepts pasted text, `.txt`, `.md`, `.vtt` and `.srt`. VTT and SRT are stripped of timestamps and speaker-turn duplication on import.
- **Structure these notes** sends live notes plus transcript to the AI and writes markdown into `structuredNotes`. Live notes are untouched.
- **Make flashcards** generates a deck from the structured notes.

**Audio:** the app does not transcribe audio itself in v1. Teams produces transcripts; macOS and iOS dictation produce text. Live audio transcription via `SFSpeechRecognizer` is a v3 candidate, and lecture recording may not be permitted by the university — confirm before building it.

### 6.4 Revision

Two modes over the same decks.

- **Study** — one card at a time, tap or space to flip, then "Got it" / "Again". Leitner scheduling. The queue shows only what's due today, and finishing the queue ends the session rather than offering more.
- **Quiz** — AI-generated multiple choice from a lecture or module, five questions by default, answered inline with an explanation revealed after each. Attempts are stored so repeated weak areas surface.

A **Weak areas** strip at the top of Revision lists the three topics with the most lapses and links straight to those cards.

### 6.5 Portfolio

Three segments: **KSBs**, **Evidence**, **Off-the-job**.

#### KSBs

A coverage grid. Each KSB is a row with its code, its text, a coverage indicator and the count of linked evidence. Filterable to "no evidence yet", which is the view that matters in year three.

Coverage is derived, not entered: none (no evidence), partial (one or two items), strong (three or more, or one the user has explicitly marked as strong).

#### Evidence

A reverse-chronological list. Creating an item takes four fields: title, date, what you did, which KSBs. Everything else is optional. A capture that takes thirty seconds gets used; one that takes five minutes does not.

Evidence can be created from anywhere: from a GitHub commit, from an assignment, from a lecture, or from scratch via ⌘K. The `isWorkConfidential` flag defaults to **true** for anything sourced from work.

#### Off-the-job

A table of entries with a running total, weekly pacing against target, and an export. The export screen lets the user map fields to columns and pick a date format, because Exeter's required template is unknown until induction.

Target hours are configurable, defaulting to 6 hours per week. Confirm the actual requirement with the provider — the rules around off-the-job minimums have changed more than once, and the provider's interpretation is what counts.

### 6.6 Block mode

Activated from Today, or automatically when the current date falls inside an on-campus block.

A column per day — two or three depending on the block, so the layout must not assume three. Each column holds that day's sessions, drawn from the programme calendar. Within it:

- A running **questions list** aggregated from every `ASK:` line across all three days, always visible. This is the thing you check before the last session ends.
- A **capture bar** fixed at the bottom: one field, one keystroke to file a thought as a note, a question, or an evidence item.
- An end-of-block **wrap-up** prompt on day three: structure all notes, generate decks, and list what to do in the first fortnight after.

The mode is deliberately narrow. During a block, the user should not be looking at the KSB grid.

**Monday session mode** is the same idea at one-day scale, offered on the morning of any online lecture or workshop: the session, a note pane, the capture bar, and nothing else. Given there are 87 of these and only 8 on-campus blocks, this is the mode that gets used most.

### 6.6a The menu bar item

The app's second surface. Present whenever StudyBot is running, and the reason you rarely need to open the window.

**The icon** is the app mark, monochrome, template-rendered so it follows light and dark menu bars. **When the off-the-job timer is running it shows elapsed time beside the mark** — `1:04` — because a timer you can't see is a timer you forget to stop.

**Click opens a popover, roughly 280pt wide:**

```
┌──────────────────────────────────────┐
│  Programming coursework 1            │
│  due in 11 working days · 15 Oct     │
│  ──────────────────────────────────  │
│  Tonight  18:00                      │
│  Discrete Maths — online workshop    │
│  ──────────────────────────────────  │
│  ▶  Start off-the-job timer          │
│  ──────────────────────────────────  │
│  [ Quick note…                     ] │
└──────────────────────────────────────┘
```

- **Next deadline** with working days remaining, not calendar days. Overdue turns the line red.
- **Today's session**, only on days that have one. Clicking opens its note.
- **Timer**, start and stop. Category is chosen when you stop, never before (§8.4).
- **Quick note** — a single field. Type, press return, it's filed as an unsorted capture and the popover closes. It does not ask which module, which session, or what kind of thing it is; sorting can happen later, and asking would defeat the point.

Escape closes without saving. The popover never grows beyond these four things — once a menu bar item needs scrolling it has become a window, and a worse one than the app already has.

### 6.7 Command palette (⌘K)

Summoned from anywhere. Context-aware: it knows the current screen and selected object, and shows that context as a chip above the input so the user can see what the AI can see.

```
┌────────────────────────────────────────────────────┐
│  ⌘K   [ Requirements report · Software Eng ]       │
│  ›  explain transitive dependency                  │
├────────────────────────────────────────────────────┤
│  Ask AI                                            │
│  ›  Explain "transitive dependency"                │
│                                                    │
│  Actions                                           │
│  ›  Check this draft against the rubric            │
│  ›  Outline this assignment                        │
│  ›  Log off-the-job hours                          │
│  ›  New evidence                                   │
│                                                    │
│  Go to                                             │
│  ›  Database Systems                               │
│  ›  Session: Sets and relations, 23 Sep                 │
└────────────────────────────────────────────────────┘
```

- Typing filters across four groups: **Search**, AI, Actions, Go to. Search comes first because it's the commonest intent.
- **Search is full text**, not just titles: session notes, structured notes, drafts, assignment briefs, rubrics, evidence summaries and reflections. Results show the matching line with the term highlighted, the module chip and the date, so you can tell two similar hits apart without opening either.
- Filters are typed inline: `module:DM`, `before:2027-01`, `type:evidence`. Anything unrecognised is treated as search text rather than erroring.
- Implementation: a SQLite **FTS5** index in its own file, separate from the SwiftData store so a rebuild can never endanger real data. Updated incrementally on save with a 2-second debounce, and fully rebuildable from the models at any time — treat it as a cache, never as a source of truth.
- Plain text with no match becomes an AI question, carrying the current context.
- Results stream into a panel below the palette; long answers can be pinned open beside the work.
- On iOS the palette is a sheet with the same grammar.

### 6.8 Settings

Not glamorous, and the place an unspecified app becomes obviously unfinished. Seven sections, in this order.

| Section | Contents |
|---|---|
| **Programme** | Modules with rename and colour, term dates, "Update programme calendar" file picker, year-3 specialism choice |
| **Sync** | Paired devices with names and last-seen, pair a new Mac, revoke a device, last sync time, sync errors in plain language |
| **Integrations** | ELE2, university mail, OneNote, GitHub — each with connect/disconnect, last successful poll, next attempt, and last error. "Run now" on each. |
| **AI** | Spend this month against the cap, the cap itself, cache hit rate, and the **AI-use record** (§7.5) filterable by assignment, exportable |
| **Notifications** | The six types from §11, each a toggle; morning plan time; a note when a type has been auto-suppressed |
| **Off-the-job** | Weekly target hours, category list, **export column mapping**, export button |
| **Data** | Export everything, restore from an export, last automatic backup, storage used, and — separately and with a confirmation — delete everything |

**Grade bands** live under Programme, since they're a property of the course rather than a preference.

**Every row that can fail shows its failure in place.** A broken integration is visible here, in words, with the action that fixes it — not as a silent absence of data elsewhere in the app.

---

## 7. The AI layer

### 7.1 Provider

OpenAI, reached **only through the server's `/v1/ai/run` proxy** (§3.7). The key lives on the VPS and never touches a device. Spend cap, response cache, rate limit and accounting are all enforced server-side because that is the only place they can be.

The client knows nothing about providers. It sends a capability name and a payload and receives streamed text. Swapping model or vendor is one file on the server and no client change.

Settings shows spend this month against the cap, from `GET /v1/ai/budget`. At the cap the server refuses and says so.

### 7.2 Capabilities

Each is a distinct `AICapability` with its own prompt, its own context assembly, and its own row in the AI-use record.

| Capability | Input | Output | Where |
|---|---|---|---|
| `structureNotes` | Live notes + transcript | Markdown: summary, key concepts, definitions, worked examples, exam-relevant points, open questions | Note workspace |
| `makeFlashcards` | Structured notes | 10–20 cards as JSON | Note workspace, Revision |
| `makeQuiz` | Structured notes or deck | 5 MCQs with explanations, as JSON | Revision |
| `explain` | A term or question + current context | Short explanation, plain language, worked example if useful | ⌘K |
| `outline` | Brief + rubric + word limit | A structured outline with section word allocations mapped to rubric criteria | Assignment detail |
| `draftSection` | Outline + one section + user's notes | Prose for one section only | Draft editor |
| `checkDraft` | Draft + rubric | Criterion-by-criterion assessment with specific, quotable gaps | Assignment detail |
| `suggestKSBs` | Evidence summary | Candidate KSB codes with reasoning, for the user to confirm | Evidence editor |

### 7.3 Prompt design rules

- Every prompt states the course, the module and the assessment level. Level 6 undergraduate work aiming at distinction, not a general-audience explanation.
- `checkDraft` marks **only** against the pasted rubric. If no rubric exists, the button is disabled with an explanation — generic feedback dressed up as marking is worse than no feedback.
- `checkDraft` returns, per criterion: the criterion, the current level, the specific gap, and the smallest change that would move it up a band. It quotes the user's own sentences when identifying a problem. It does not rewrite them.
- `draftSection` produces one section at a time and always returns to the user with a note about what to change to make it sound like them. The output is marked in the editor as AI-drafted until the user edits it, at which point the mark clears.
- `suggestKSBs` never auto-assigns. It proposes; the user confirms.
- JSON-returning capabilities specify the schema in the prompt and parse defensively, with a visible retry on malformed output.

### 7.3a Prompt templates

Left to an implementer these get written ad hoc and drift. They are part of the product, not glue code: they live in `StudyBotKit/AI/Prompts/` as versioned string resources, and changing one is a deliberate act with a changelog entry.

**Every prompt opens with the same context block**, assembled from real data, never hardcoded:

```
You are helping a Level 6 Digital & Technology Solutions degree apprentice
at the University of Exeter, working full time at a technology company.
Module: {module.code} {module.name}
This is undergraduate work assessed at degree level. The user is aiming for
a distinction. Write for someone competent who is short of time.
Use British English. Be concise; do not pad.
```

**`checkDraft`** — the highest-stakes prompt in the app.

```
Mark this draft against the rubric below. Do not invent criteria that are
not in the rubric. For each criterion, return:
 - the criterion, quoted from the rubric
 - the band it currently reaches, using the user's own band names
 - the specific gap, quoting the user's own sentences where relevant
 - the smallest change that would move it up one band
Do not rewrite the user's prose. Do not produce a revised version.
If the draft is too incomplete to assess a criterion, say so for that
criterion rather than guessing.
Return JSON: [{criterion, band, gap, smallestChange}]
```

**`structureNotes`** — output markdown with these sections and no others: Summary (3 bullets), Key concepts, Definitions, Worked examples, Exam-relevant points, Open questions. Keep the user's own terminology. Do not add material that isn't in the notes or transcript — if something is unclear, list it under Open questions rather than filling the gap.

**`makeFlashcards`** — 10–20 cards, JSON `[{front, back, sourceLine}]`. One idea per card. Fronts are questions, not topics. Backs are one or two sentences. No cards that can be answered yes or no.

**`draftSection`** — one section only, using the user's notes as source material. End with a short note on what to change to make it sound like them. Never produce more than the section asked for.

**`suggestKSBs`** — propose codes from the imported KSB list only, never invented ones. Return `[{code, confidence, reasoning}]`. If nothing fits above low confidence, return an empty array rather than reaching.

**Shared rules across every prompt:** no preamble ("Here is…"), no closing offer ("Let me know if…"), no emoji, no headings the template didn't ask for. JSON-returning prompts state the schema and the server parses defensively with one visible retry on malformed output.

### 7.4 Confidentiality rule

Any object with `isWorkConfidential == true` is excluded from every AI call, unconditionally. This is enforced in the context-assembly layer, not in the UI — a confidential item must be unable to reach a prompt even through a code path nobody remembered to check.

- Evidence sourced from work defaults to confidential.
- Attempting an AI action on a confidential item shows: "This is marked as work-confidential, so it isn't sent to the AI. You can still write, log and link it."
- Add a unit test that asserts confidential content never appears in an assembled prompt. Treat a failure as a build-breaking bug.

### 7.5 AI-use record

Every run writes an `AIRun`. Settings contains an AI use screen listing, per assignment: what was asked, which capability, when, and whether the output was used. Exportable as a plain document.

This exists because Exeter will have an AI policy, the policy will require declaration, and reconstructing months of AI use from memory is both unpleasant and inaccurate. Read the policy at induction and adjust the defaults in §7.3 to match it.

---

## 8. Automation and ingestion

The target: the only thing typed into this app is notes. Everything else arrives.

### 8.0 Where automation runs

Resolved by §3: there is a server, always on, and ingestion polls from it. ELE2 gets checked whether or not the Mac is open, which is the whole reason the server exists.

Polling intervals and back-off are in §3.8. Results become proposals (§8.7), never direct writes.

Webhooks are deliberately **not** used in v1 or v2. Microsoft Graph change notifications would need a public callback, subscription renewal every few days, and replay handling — real complexity for latency nobody needs. A deadline announced on ELE2 does not need to reach you in ninety seconds; it needs to reach you without you going to look. Fifteen minutes to an hour is fine. If polling ever proves too slow, the ingestion layer's trigger is swappable and webhooks become an addition rather than a rewrite.

### 8.1 ELE2 — the highest-value source

ELE2 is Moodle. Three routes, in order of preference:

**1. Moodle web services (best).** Moodle exposes a REST API with `mod_assign_get_assignments`, which returns assignment IDs, names, full descriptions, due dates, max grades and attached files. This is exactly the payload needed and it makes the assignment list fully automatic. It requires a token, obtained via `/login/token.php` with the user's credentials **if** the site has the mobile web service enabled. Most universities do, because the Moodle mobile app depends on it. Try this first; ask Exeter IT if it's blocked.

**2. The private calendar feed (reliable fallback).** Every Moodle user can self-serve an authenticated iCal URL from the calendar page — no admin involvement. It carries assignment events with their real titles and due dates, though not descriptions or attachments. Poll it hourly. This route is near-certain to work.

**3. Manual import.** Drop an exported ICS or a downloaded brief. Always available, and how v1 works.

Never scrape the HTML behind a login. It breaks on every theme update and is likely to breach the acceptable-use policy.

**What ingestion does with an assignment:** matches on the Moodle assignment ID, updates the existing calendar-created stub in place rather than duplicating it, fills in title, description, due date and weighting, downloads attachments and extracts their text, then flags the record as needing one tap of confirmation.

### 8.2 University email

Microsoft Graph on the Exeter tenant. Scopes across all Graph features: `Mail.Read`, `Notes.Read`, `Calendars.Read`, `Files.Read.All`, `offline_access`. Request them together at one consent prompt rather than piecemeal. Poll the inbox for messages from university domains and known senders.

An AI pass over each new message classifies it: deadline change, new resource, administrative, or ignorable. Anything that looks like a change to an existing assignment produces a proposal — "Coursework 1 moved to 22 October, from an email on Tuesday" — with the source message linked. It never edits a date silently.

Two hard rules: only university-domain mail is read, never Cambridge Kinetics mail; and an email that triggers a proposal is summarised locally where possible, with the full body sent to the AI only when classification is genuinely ambiguous.

### 8.3 Resources and reading

From the Moodle API, course modules of type `resource`, `url` and `folder` give the reading material attached to each week. Download, extract text, attach to the module and the session it belongs to.

Each imported resource gets a one-line AI summary and an estimated reading time, so the study planner can schedule it rather than the user guessing.

### 8.4 Off-the-job hours without typing

This is the most tedious logging in the whole apprenticeship, so it gets the most automation.

**A timer.** One click from the macOS menu bar, a Lock Screen Live Activity and Control Centre control on iOS. Start, stop, and pick a category afterwards — never before, because choosing a category is a decision and decisions stop people starting timers.

**Calendar-derived suggestions.** Every Monday online session in the programme calendar is a known quantity of off-the-job time. At the end of each session day, the app proposes the entry pre-filled, needing one tap. Same for on-campus days, which are full days by definition.

**Work-calendar inference.** With Graph calendar read, meetings whose titles match learned patterns — mentoring, one-to-one, architecture review, shadowing — produce a proposal with the duration already correct.

**GitHub-derived.** Commits and merged PRs on a day produce a proposal for project work, with the commit messages as the description draft.

All four produce **proposals, not entries.** They collect in one place (§8.7) and are confirmed in a batch. A week of hours should take under a minute to file.

### 8.4a Grades from ELE2

Grades and tutor feedback are pulled from the Moodle gradebook and **applied directly, not proposed.** This is a deliberate exception to "confirm, never compose" (§2.6), and the reasoning matters: a grade in the gradebook is authoritative upstream fact, not an inference. Asking you to confirm the university's own number would be busywork that teaches you to tap Confirm without reading.

- Pulled with the assignment, on the same hourly poll.
- A new grade fires one notification: "Programming coursework 1 — 74. Distinction." It also updates the module's weighted progress and the mark-needed arithmetic (§12).
- Tutor feedback text comes with it and lands in `Assignment.feedback`, where the AI can later look across several assignments for repeated criticism.
- A grade that *changes* after being recorded — remark, moderation — does go to the proposal queue, because a changing grade is the kind of thing you want to notice rather than have quietly overwritten.

### 8.5 OneNote

Reachable through the same Microsoft login as university mail. Scope: `Notes.Read`.

- Poll notebooks and sections every 30 minutes; pull page content as HTML and convert to text.
- **Map to modules by section name,** matched against module names and codes. An unmatched section goes to an "Unfiled" group rather than being guessed at.
- Imported pages become read-only **mirrors**, clearly marked as living in OneNote. They can be attached to a `Session`, used as an assignment's `draftSource`, or fed to `structureNotes` — but not edited in StudyBot.
- **Never writes back.** Same rule as drafts (§6.2a): one-way, always.
- Sync is by page `lastModifiedDateTime`. A changed page updates its mirror in place and keeps the previous version as a `NoteRevision`.
- If a page is deleted in OneNote, the mirror is marked orphaned rather than deleted, because a note you took in a lecture shouldn't vanish because you tidied a notebook.

### 8.6 Reminders

Local notifications are the default, on both devices, needing no server. They cover deadlines, the morning plan, and off-the-job pacing (§11).

Email reminders are straightforward now the server exists: a transactional sender (Postmark, Resend, SES) called from a scheduled job. Keep them rare and digest-shaped — one Sunday evening email with the week ahead, open proposals and hours owed. A notification you can act on beats an email you archive, so email is never the only channel for anything.

Until the Apple Developer membership is taken there is no push, so on the Mac these are local notifications scheduled by the app plus the Sunday email. That combination covers everything §11 requires without push.

### 8.7 The proposal queue

Everything automation produces lands in one place: a **Needs a moment** section at the bottom of Today, hidden entirely when empty.

```
Needs a moment                                    4
─────────────────────────────────────────────────────
 New   Coursework 2 brief imported from ELE2     Open
 Move  Coursework 1 due date → 22 Oct   (email)  Confirm
 Log   Monday session, 3h off-the-job            Confirm
 Log   4 commits on studybot-api, 2h             Confirm
                              Confirm all        Dismiss
```

Rules: nothing enters the app's real data without passing through here. Every row names its source. "Confirm all" exists because four taps is three too many. Dismissing a proposal teaches the classifier not to make that one again. And a proposal never expires — an unconfirmed deadline change is still visible in six weeks, because a silently dropped date is worse than a stale queue.

### 8.8 Credentials and failure

All tokens in the Keychain. Each source has a status row in Settings: last successful sync, next attempt, and a plain-language error when broken — "Exeter mail sign-in expired. Sign in again." Never a silent failure, and never a spinner that hides one.

Every integration is optional and independently switchable. The app must be fully usable with all of them off, because on day one they will all be off.

### 8.9 Other sources

**GitHub.** Fine-grained read-only token. Repos, commits, merged PRs. One action: turn a commit or PR into evidence, pre-filled, flagged confidential if the repo is private.

**OneDrive and SharePoint.** Browse, download, attach, extract text. Work tenants often refuse third-party Graph access — if consent is denied, everything else must still work.

### 8.10 Importers

| Format | Approach |
|---|---|
| PDF | PDFKit text extraction; Vision OCR fallback when a page yields no text |
| DOCX | Unzip, parse `document.xml` |
| PPTX | Unzip, parse slide XML, one section per slide |
| Pages / Keynote | Ask the user to export; do not attempt the proprietary format |
| VTT / SRT | Strip timestamps and cue numbers, merge consecutive same-speaker lines |
| TXT / MD | Direct |

### 8.11 Scheduled routines

Five routines run on their own. Each is individually switchable, each logs every run to a `routine_runs` table so "why did this appear" always has an answer, and none of them spends from the AI budget without a tap.

**The cost rule, which governs all five:** a routine may gather, arrange, schedule and propose for free. It may not call the AI unprompted. Where a routine's output needs the AI, it assembles everything and leaves a one-tap action — "Structure Monday's notes · ~£0.01" — with the estimated cost shown before you commit. This is what stops a budget being consumed by a machine acting on your behalf while you sleep.

#### Sunday review — 18:00

One notification and one email. Contents, in order:

- What's due in the next 14 days, with working days remaining (not calendar days).
- What slipped: sessions with no notes, assignments with no movement since last week, hours below target.
- Anything sitting unresolved in the proposal queue.
- One line on the term ahead if a crunch window is approaching.

Written flatly. No encouragement, no scores, no streak. "Three sessions this month have no notes" is the whole sentence; it does not need a verdict attached.

**This is the one exception to the quiet Sunday rule** (§9 Signature details). Sunday stays silent apart from this single digest — which is precisely why it lands: it is the only thing that arrives that day.

#### Monday session prep — 07:00, only on session days

- Creates the `Session` record for that evening's lecture or workshop, with module, date and time already set.
- Pulls any resources ELE2 has attached to that week and attaches them.
- Opens with the note template ready, so the app is a blank page waiting rather than three clicks of setup while the session starts without you.
- Skips reading weeks, closures and bank holidays automatically — it reads the programme calendar, so it already knows.
- If the same session already has a note (you prepped it yourself), it does nothing rather than creating a duplicate.

#### Post-session wrap-up — 21:00 on session days

Splits along the cost rule:

- **Applied as normal proposals, no AI:** the off-the-job hours entry for the session, pre-filled with duration and category.
- **Prepared, waiting for one tap:** structure the notes, generate flashcards. The queue row reads "Wrap up Monday's session — structure notes, make cards · ~£0.02". Tapping runs both and shows the result.
- If no notes were typed, the AI half is not offered at all — there is nothing to structure, and offering it would be noise. The hours proposal still appears, because you still attended.

#### Work-back plan — when a brief lands

When an assignment first gets a real brief and rubric, the routine works backwards from the due date and **creates real dated subtasks** on the assignment.

- Scheduled into **working days only** — bank holidays, university closures and on-campus block days are excluded, which is usually a sharper number than the calendar suggests.
- Default shape, scaled to the word count and weighting: read brief and rubric → outline → draft each major section → complete first draft → check against rubric → revise → **submit two working days early**. That buffer is not optional; it is the difference between a technical problem being an inconvenience and a disaster.
- If there are not enough working days to fit the shape, it says so plainly on the assignment rather than silently compressing everything into the final weekend: "11 working days available, this shape needs 16. Start now or cut the revision pass."
- Subtasks are ordinary subtasks afterwards — reorder, delete, re-date them freely. The routine never re-plans an assignment it has already planned unless you ask it to.

#### End of term

- Archives the term: completed assignments collapse, its modules move to a Past section.
- Produces a one-page summary — grades, hours logged, sessions attended, evidence captured.
- **Flags KSB gaps**, which is the real point. Three years is long enough to reach the Gateway with four KSBs never evidenced, and a term boundary is the natural moment to notice.
- Consolidates the term's flashcards into a single review deck so earlier material keeps resurfacing rather than being finished with.

#### Routine design rules

- Every routine is idempotent. Running twice must produce nothing new.
- A routine that fails is silent to the user and logged for the developer — a failed digest is not worth a notification.
- A missed run (machine asleep, server down) fires on next opportunity if still relevant, and is skipped entirely if not. Monday prep at Thursday lunchtime helps nobody.
- Every routine can be turned off individually in Settings, and the list shows when each last ran.

### 8.12 What automation cannot do

Stated plainly so expectations are calibrated. It cannot attend sessions, take notes, know what a tutor emphasised out loud, or judge whether your draft is good — the checker marks against a rubric and is useful, but it isn't a marker. It cannot make evidence out of work you didn't reflect on. And it cannot get you a distinction. It can remove every reason you'd miss one that isn't about the work itself, which is a smaller claim and a true one.

---

## 9. Design system

Light mode only in v1. The reference points, and what to take from each:

- **Linear** — density and information hierarchy in lists. Rows carry a lot without feeling crowded: small type, tight vertical rhythm, hairline separators, status communicated by icon rather than colour blocks. Keyboard shortcuts for everything, always discoverable. Take the list craft.
- **Notion** — calm. Generous whitespace around content, restrained typography, structure that emerges from spacing rather than borders and boxes. Take the reading experience for notes and long text.
- **iOS** — touch ergonomics and depth. Comfortable tap targets, sheets that respond to the drag, soft shadows used sparingly to show layers, spring animation that answers a gesture. Take the motion and the feel.

The blend: Linear's lists sitting inside Notion's whitespace, moving the way iOS moves.

### Principles before values

The values in this section are not a starting point to riff on. They are the design. Where taste and this section disagree, this section wins.

Six rules that decide most questions without needing to ask:

1. **Nothing moves that the user didn't move.** No hover lifts, no scale on press, no drifting, floating, pulsing or breathing. State changes are colour, material and opacity. Geometry is fixed. This is the single clearest line between a native Mac app and a web page wearing one as a costume.
2. **Structure comes from hairlines and whitespace.** Not from boxes inside boxes, not from cards with shadows, not from background tints marking out regions. If two things need separating, a 1px rule or 24pt of space does it.
3. **Colour carries meaning or it doesn't appear.** Module identity, status, overdue, the accent on a primary action. Nothing is coloured to look nice. The interface is greyscale plus one accent plus a small set of status colours, and that's the whole palette.
4. **Depth belongs to controls.** Only pressable things get gradients and shadows. Everything else is flat. When depth is scarce it reads as affordance; when it's everywhere it reads as decoration.
5. **Every element does one job.** A label that also explains, a button that also informs, an icon that also decorates — each is a sign the thing hasn't been designed yet. Cut until each element has exactly one reason to exist.
6. **Remove one thing.** Before any screen is called finished, take out the element you'd defend least. It is almost never missed.

**What this is guarding against.** Interfaces assembled quickly tend to converge on the same tells: everything in a rounded card with the same soft grey shadow; gradient washes used as decoration; a hover lift and a scale-on-press on every clickable thing; icons beside every label; tracked-out capitalised eyebrow text above headings; and motion on appearance for content that was simply already there. None of these are forbidden because they're ugly in isolation. They're forbidden because they appear regardless of subject, which means they're defaults rather than decisions, and a room full of defaults is what "designed by nobody" looks like.

**The standard to hold it to:** this should look like it shipped from a company that cares, on a Mac, in 2026. Restrained, dense with information, quiet, and obviously made by someone who decided each thing on purpose.

### Colour

| Token | Hex | Use |
|---|---|---|
| `canvas` | `#FBFBFA` | App background |
| `surface` | `#FFFFFF` | Cards, panels, rows on hover |
| `border` | `#E8E8E6` | Hairlines, separators, input borders |
| `borderStrong` | `#D4D4D1` | Focused input, dividers between major regions |
| `textPrimary` | `#1D1D1F` | Titles, body |
| `textSecondary` | `#6E6E73` | Metadata, labels, secondary rows |
| `textTertiary` | `#A1A1A6` | Placeholders, disabled, timestamps |
| `accent` | `#5E6AD2` | Primary actions, selection, focus ring |
| `accentSoft` | `#EEF0FB` | Selected row background, accent chip fill |

Status and semantic colours, all muted to sit on a near-white canvas without shouting:

| Token | Hex | Use |
|---|---|---|
| `statusBacklog` | `#A1A1A6` | |
| `statusTodo` | `#6E6E73` | |
| `statusDrafting` | `#D9A441` | |
| `statusReview` | `#5E6AD2` | |
| `statusDone` | `#4A9E6B` | |
| `danger` | `#C4483D` | Overdue, destructive actions |

Module colours come from a fixed palette of eight, all similarly desaturated so no module visually dominates.

Rules: colour never carries meaning alone — every status has an icon and a label. Overdue is the only place red appears in normal use.

### Typography

- **SF Pro** for interface. Native on both platforms, correct on iOS, and avoids bundling a webfont.
- **New York** for the reading view of structured notes and long-form draft text. Apple's serif, available system-wide, and it makes a 2,500-word draft read like a document rather than a UI.
- **SF Mono** for code blocks, the command palette input, and numeric data that should align in columns (hours, KSB codes). **Never for prose.** Live notes are sans-serif — monospace reads as a terminal and makes handwriting-speed capture feel like programming.

Every size below is a base value at the default text size, not an absolute. §16 requires Dynamic Type up to the largest accessibility sizes, and a fixed point size cannot satisfy that — this was a contradiction between §9 and §16 and this paragraph resolves it in §16's favour.

`SBType` exposes each role through a scaling function driven by the current Dynamic Type category (`@ScaledMetric` or equivalent). Anything that must stay in proportion to text scales with it: row heights, the 20pt sidebar icon frame, chip padding, button padding, the measure caps, and the gap between an icon and its label.

What does not scale: hairline borders stay 1px, module dots stay 6pt, the term strip's marks stay fixed, and the sidebar's collapsed rail stays 56pt. These are graphic elements rather than text, and growing them makes the interface coarse rather than readable.

At the largest accessibility sizes, dense rows are allowed to become two lines rather than truncating. A row that clips is a failure; a row that grows is not.

Scale, in points:

| Role | Size | Weight | Tracking |
|---|---|---|---|
| Display | 28 | Semibold | −0.02em |
| Title | 20 | Semibold | −0.01em |
| Section | 15 | Medium | 0 |
| Body | 13 (macOS) / 15 (iOS) | Regular | 0 |
| Row | 13 | Regular / Medium when unread | 0 |
| Meta | 12 | Regular | 0 |
| Micro | 11 | Medium | 0.01em |

Long-form text sets at 17pt New York, line height 1.55, measure capped at 68 characters. Never let a draft run the full width of a 16-inch display.

Live notes set at 15pt SF Pro, line height 1.7, measure capped at 66 characters. The two panes of the note workspace are deliberately different faces — sans for the thing you're typing now, serif for the thing you'll read back later. That contrast is the whole idea, and it stops working if either side drifts toward the other.

No all-caps labels. No tracked-out eyebrow text above headings.

### Spacing, shape, depth

- 4pt base unit. Steps: 4, 8, 12, 16, 24, 32, 48.
- Padding: 16 inside rows, 24 around content regions, 32 at the outer edge of a detail view on macOS.
- Radius: 6 on controls and chips, 10 on cards and popovers, 14 on sheets, full on pills.
- Shadow used only for genuine layers — popovers, sheets, the command palette. `y 4, blur 16, black 6%`. Rows and cards use borders, not shadows.

### Motion

- Selection and hover: instant, no transition.
- Sheets, palette, detail panels: spring, response 0.32, damping 0.85.
- The palette opens with a 4pt rise and an opacity fade over 140ms. Nothing else animates on appearance.
- Honour Reduce Motion by replacing every spring with a 100ms crossfade.

### Component styling — exact values

These are approved from the prototype (`studybot-prototype.jsx`) and are not open for reinterpretation. Where this section and a designer's instinct disagree, this section wins. Read the prototype source alongside it.

**Buttons.** Two variants only, secondary and primary. No tertiary, no ghost, no destructive variant — a destructive action is a secondary button that opens a confirm.

Buttons are the one place in the interface that gets dimension. Everything else — cards, rows, panels — is flat and separated by hairlines. Depth is reserved for things you can press, which is what makes it read as affordance rather than decoration.

| | Secondary | Primary |
|---|---|---|
| Background | `linear-gradient(180deg, #FFFFFF, #FAFAF9)` | `linear-gradient(180deg, #6E79DC, #5E6AD2 55%, #5561C9)` |
| Text | `textPrimary`, 13pt, weight 500 | white, 13pt, weight 510 |
| Border | 1px `#DEDEDB` | 1px `#4F5ABD` — a shade darker than the fill, for definition against light backgrounds |
| Inner highlight | none | `inset 0 1px 0 rgba(255,255,255,0.20)` — the top-edge catch light that makes it feel raised |
| Shadow | `0 1px 1.5px rgba(0,0,0,0.05)` | `0 1px 2px rgba(30,35,90,0.18), 0 2px 6px rgba(94,106,210,0.22)` — tinted with the accent, not grey |
| Radius | 7 | 7 |
| Padding | 6×13, icon-free (small: 4×11, 12pt) | 6×14 with a 13pt leading icon and 6pt gap (small: 4×11) |
| Hover | background to `#F6F6F5`. Nothing else. | gradient brightens ~3%. Nothing else. |
| Press | fills `#F0F0EE`, shadow collapses to `inset 0 1px 2px rgba(0,0,0,0.07)` | gradient darkens to `#4F5ABD → #4A55B8`, shadow collapses to `inset 0 1px 2px rgba(20,24,70,0.30)` |
| Focus (keyboard) | `0 0 0 3px rgba(94,106,210,0.28)` ring outside the border, both variants | |
| Disabled | flat `canvas`, `textTertiary`, no gradient, no shadow, no highlight | same treatment — a disabled primary loses all depth rather than staying blue and dimmed |
| Transition | `background 120ms ease, box-shadow 120ms ease, transform 80ms ease` | same |

**Nothing moves.** No lift on hover, no scale on press, no translation anywhere. A macOS push button in Finder or Mail stays exactly where it is and changes colour and material only — the shadow collapsing inward on press is what communicates depression, not the button physically moving. Buttons that lift under the cursor are a web idiom, and on a native Mac app they read immediately as not-quite-right even to people who couldn't say why.

**Never add a gradient anywhere else.** Not to headers, not to cards, not as a background wash. Gradients here exist to model a light source on a physical control; used decoratively they are the single clearest tell of a generated interface.

**Icons on buttons: primary only.** A primary button carries a leading SF Symbol at 13pt, `.medium`, 6pt before the label. Secondary buttons stay text-only. This is what makes primary actions read as primary at a glance without needing colour alone to do the work, and keeping icons off secondary buttons stops a row of three buttons turning into a toolbar.

| Action | Symbol |
|---|---|
| Edit | `pencil` |
| Save changes | `checkmark` |
| Accept plan | `checkmark` |
| New evidence | `plus` |
| Log hours | `clock` |
| Got it (revision) | `checkmark` |
| Export | `square.and.arrow.up` |
| Any AI action | `sparkles` |

**`sparkles` means "this costs tokens".** Every button that calls the AI carries it and nothing else does — Check against rubric, Structure these notes, Make flashcards, Make a quiz, Draft a section, Outline. It's a consistent signal that an action will spend from the budget, which matters once there's a monthly cap (§3.7). Never use `sparkles` decoratively.

Label text is sentence case and names the action.

**List rows.** 38pt tall on macOS, 44 on iOS. Horizontal padding 20. A 1px `border` bottom rule, never a gap or a card. Hover fills `rowHover`, instantly, with no transition — transitions on hover feel laggy at list speed. Selected fills `accentSoft`.

**Section headers.** `canvas` background, 12pt weight 600, count in `textTertiary` to its right, 1px rules top and bottom, 7×20 padding. They separate; they do not decorate.

**Edit mode, everywhere.** Any detail panel that holds structured fields — assignment, evidence, an off-the-job entry — uses the same pattern: read-only by default, a primary Edit button top-right, Cancel and Save changes replacing it while editing, `⌘E`/`⌘S`/`⎋`, and a discard confirmation when anything has changed. Free-text writing surfaces (drafts, live notes) are always directly editable and never gated behind a mode. Do not invent a second editing idiom for any one screen.

**Cards and panels.** 1px `border`, radius 10, `surface` background, **no shadow and no gradient** — the opposite of buttons, deliberately. Shadow is reserved for things that genuinely float: the command palette (`0 12px 40px rgba(0,0,0,0.16)`), sheets, and the flashcard (`0 4px 16px rgba(0,0,0,0.05)`). If it doesn't float, it doesn't get a shadow.

**Chips.** Radius 6 for metadata chips with a 1px border; radius 999 for tags. Module chips are a 6px dot plus the short code in the module's colour, 11pt weight 500. KSB codes are monospace 10.5pt weight 600 in `accent` on `accentSoft`.

**Inputs and textareas.** `canvas` background, 1px `border`, radius 6, padding 9×11. On focus the border becomes `accent` and nothing else changes — no glow, no ring, no lift.

**Segmented control.** iOS pattern: `canvas` track with 1px border, radius 8, 2px inset; the selected segment is `surface` with a 1px subtle shadow and slides between positions.

**Status icons.** Drawn, not from a font. 14px circle, 1.5px stroke: dashed for backlog, solid outline for todo, half-filled arc for drafting, three-quarter arc for review, tick for submitted and graded.

**The two rules that carry the look:** structure comes from 1px rules and whitespace, never from boxes inside boxes. And colour appears only where it carries meaning — module identity, status, overdue. Everything else is greyscale.

### Motion

Motion is rare, and every instance answers something the person did. If a builder adds an animation not on this list, it is wrong.

| Where | What | Timing |
|---|---|---|
| Sidebar selection | Background and colour only — never a symbol variant or weight change | 120ms ease |
| Command palette | Opacity 0→1, scale 0.97→1, y +6→0 | 180ms, spring, damping 0.86 |
| Detail panel | Slides in from the right edge | 260ms spring, damping 0.88 |
| Flashcard flip | 3D `rotateY` 180°, content swaps at 90° | 420ms, ease-in-out |
| Progress bars | Width animates from 0 on first appearance only | 500ms ease-out, 60ms stagger |
| Segmented control | Selected pill slides to the new position | 220ms spring |
| Section collapse | Height and opacity | 200ms ease |
| Button press | Gradient darkens, shadow inverts to inset. No transform. | 80ms |
| Today, on first open of a session | The four blocks fade and rise 8px, staggered 50ms | 320ms ease-out |

That last one is the single orchestrated moment. It happens once per launch and nowhere else. No other view animates on appearance, no card fades in on scroll, no number counts up, and nothing pulses, bounces or glows.

Reduce Motion replaces every entry above with a 100ms opacity crossfade, and disables the flip entirely in favour of an instant swap.

### The sidebar

Finder's sidebar is the reference: translucent, quiet, icon-led.

**Material.** `NSVisualEffectView` with `.sidebar` material and `.behindWindow` blending — the genuine macOS vibrancy, not a tinted overlay approximating it. In SwiftUI, `NavigationSplitView` gives this by default; do not override it with a solid background. The window uses `titlebarAppearsTransparent` and a full-size content view so the sidebar runs under the title bar exactly as Finder's does. The content pane beside it stays opaque `surface`, which is what makes the translucency legible as a distinct region rather than a wash across the whole window.

**Icons: SF Symbols, outline variants only.** Not an icon font — SF Symbols match macOS weight, baseline and optical sizing natively, and their default variants are already hollow.

| Item | Symbol |
|---|---|
| Today | `sun.max` |
| Assignments | `checklist` |
| Modules & notes | `book` |
| Revision | `rectangle.on.rectangle` |
| Portfolio | `checkmark.seal` |

Rendered at 15pt, `.medium` weight, monochrome, in a fixed 20pt-wide frame so every label starts on the same x. Module dots keep their colour; nothing else in the sidebar is coloured except the selected row.

**Selection stays hollow.** Many Apple apps swap to `.fill` on selection; this one doesn't. The selected row changes colour and background only. Switching weight or variant on selection makes the list feel like it's twitching as you move through it, which is the opposite of what a sidebar is for.

**No keyboard hints in the sidebar.** The ⌘1–⌘5 shortcuts still work, but printing them beside every row is visual noise for something you learn in a day and then never read again. Discoverability lives where it belongs: in the View menu next to each item, and in the ⌘K palette, which shows the shortcut beside any action that has one.

**Collapsible.** The sidebar collapses to a 56pt icon-only rail, toggled by a control in the sidebar's own header and by `⌥⌘S` — the same shortcut Finder uses. Collapsed, the rail shows the five icons centred, with the name appearing as a tooltip after the standard delay. The module tree is hidden entirely when collapsed rather than crammed in; expanding restores whatever was expanded before. The state persists across launches and per device, since one Mac may be a 13-inch laptop and the other a large display.

Width animates 228pt → 56pt over 220ms with the same spring as the segmented control. Labels crossfade out over the first 80ms so text never squashes against the edge mid-animation.

**The app mark.** The "S in a rounded square" placeholder in the prototype is exactly the kind of thing that makes an app look homemade. Replace it with a real mark, and derive it from the product rather than the initial: **the term strip** (§9 Signature details) is StudyBot's one distinctive visual — a hairline with tall marks for campus blocks, short ticks for sessions and a hollow ring for a submission. A mark built from that reads as a bookmark, a timeline and a progress indicator at once, and it is specific to this app in a way a letterform never is.

- Construction: indigo `accent` on white, drawn on the macOS icon grid with the standard superellipse and corner radius. Hairline weights scale with size rather than staying fixed.
- Ship `.icns` at all required sizes from 16pt to 1024pt, and verify the 16pt version legibly — at that size the marks must simplify to two or three strokes rather than becoming mush.
- In the sidebar header, show the mark at 18pt beside "StudyBot" at 13pt semibold. When collapsed, the mark alone remains.
- **Do not use an emoji, a stock glyph, or a letter in a coloured square.**

**Density.** 28pt rows, 6pt vertical gap between groups, 8pt horizontal inset. Term headings within Modules are 10.5pt `textTertiary`, sentence case, with no rule beneath them — the spacing is the separation.

**Module names truncate with a tail ellipsis** and carry a tooltip with the full name and code. "Discrete Mathematics for C…" is fine; a wrapped two-line sidebar row is not.

### Empty states and errors

Two things an unspecified app gets wrong, and both are visible on day one.

**Empty states direct; they don't decorate.** No illustrations, no "Nothing here yet!". One line saying what goes here and one action that puts something there.

| Where | Copy |
|---|---|
| No assignments this term | "No submissions this term. Show all 30." |
| No notes on a session | "Type. Sort it out later." |
| No evidence | "No evidence yet. Log something from this week's work." |
| Revision queue clear | "Queue clear. Next cards are due tomorrow." |
| No proposals | Section hidden entirely. An empty queue is good news, not a panel. |
| No rubric | "No rubric yet. Press Edit and paste the marking criteria." |
| Search, no results | "Nothing matches. Try fewer words." |

**Errors say what happened and what fixes it.** Never "Something went wrong", never a raw error code, never an apology.

| Situation | Copy |
|---|---|
| Server unreachable | Nothing. Offline is not an error. A status line in Settings only. |
| Push failing over an hour | "Changes haven't synced for an hour. They're safe on this Mac." |
| ELE2 sign-in expired | "Exeter sign-in expired. Reconnect in Settings → Integrations." |
| AI budget reached | "You've reached this month's AI limit of £8. Raise it in Settings → AI." |
| Client too far behind | "This Mac is running an old version of StudyBot. Update it to sync again." |
| Malformed AI response | "That came back unreadable. Try again?" with a retry button. |
| Encrypted PDF | "This PDF is password-protected. Open it and export an unlocked copy." |

**The rule:** if the user can't act on it, don't interrupt them with it — log it and put a status somewhere they can look.

### Signature details

Small, cheap, specific. These are what make the app feel built for one person rather than assembled from a component library, and they should be treated as requirements rather than nice-to-haves.

**Already specified:**

- **The term strip** on Today — the whole term as one horizontal line: campus blocks as tall accent marks, Monday sessions as small grey ticks, submissions as hollow amber rings, today as a single vertical rule. No labels, no grid, no interaction beyond tapping a marker. It answers "where am I in this term" in about a third of a second.
- **`ASK:` capture** — typing that prefix at the start of a line in live notes moves it into a running questions list, aggregated across a whole block.
- **Working-days-until** rather than raw days, excluding bank holidays, closures and campus days. "Nine working days" is the honest number; "twenty-three days" is not.
- **Unnamed submissions shown in italic grey** — the 30 calendar-imported stubs read as placeholders until a real brief fills them in, without needing a badge to say so.
- **Proposals never expire** in the Needs a moment queue.

**The rule for adding more:** a signature detail must be specific to this course or this person, cost under a day, and replace something the user would otherwise have to think about. It must not be decorative. If it can't be described in one sentence that names what it saves, it's decoration.

**Worth building, in rough order of value:**

- **Deadline density shading** on the term strip: the line thickens slightly where submissions cluster, so July 2027 looks heavy from ten months away without anything being spelled out.
- **A session gap mark** — Mondays with no notes attached render as hollow ticks rather than solid. Three hollow ticks in a row is visible before it becomes a problem.
- **One-tap "log this session"** appearing on Today only on a Monday session day, and only after the session's end time has passed.
- **Grade-needed arithmetic** shown inline on the module row: "68 needed on the remaining two for a distinction". The number, not a progress bar.
- **Time-of-day awareness** in the morning plan: a 90-minute drafting task is never proposed for a weekday evening after a full day at work unless nothing else fits, and the app says so when it does.
- **A quiet Sunday** — the only thing that arrives on a Sunday is the 18:00 review digest (§8.11). Nothing else notifies, regardless of what's due. The digest lands *because* the day is otherwise silent; fill Sunday with nudges and it becomes one more thing to dismiss.

### Component inventory

`StatusIcon` (six states, drawn as SF Symbols-style circles: dashed, empty, half, three-quarter, filled, check) · `PriorityBars` (0–4 ascending bars) · `ModuleChip` · `DueDateLabel` (relative under 14 days, absolute beyond, red when overdue) · `ListRow` · `SectionHeader` (title, count, collapse) · `ProgressBar` · `GradeBadge` · `EmptyState` (one line of direction plus one action) · `CommandPalette` · `AIPanel` (streaming text, copy, "use this", token cost) · `TagField` (KSB picker) · `Stepper` · `Sheet`.

### Writing in the UI

Sentence case everywhere. Buttons name what happens: "Structure these notes", not "Submit". The same action keeps its name from button to confirmation. Empty states direct rather than apologise: "No evidence yet. Log something from this week's work." Errors say what failed and what to do: "Couldn't reach OpenAI. Check your key in Settings."

---

## 10. Keyboard shortcuts (macOS)

| Key | Action |
|---|---|
| `⌘K` | Command palette |
| `⌘1`–`⌘5` | Jump to sidebar sections |
| `c` | New item in the current context |
| `↑` `↓` | Move selection |
| `⏎` | Open selected |
| `⎋` | Close panel, dismiss palette |
| `s` `p` `d` | Status, priority, due date on the selected assignment |
| `⌘E` | Edit the open detail panel |
| `⌘S` | Save changes |
| `e` | New evidence from the selected item |
| `l` | Log off-the-job hours |
| `⌘F` | Search within view |
| `⌘⏎` | Run the primary AI action in the current context |

Every shortcut appears in its menu item and in the palette. Nothing is hidden.

---

## 11. Notifications

Local notifications on the Mac, plus one email from the server (§8.6). Each type is independently toggleable and all are off until turned on.

| Type | When | Cap |
|---|---|---|
| Deadline reminders | 7 days, 2 days, and the morning of | Once each, never repeated |
| Morning plan | A chosen time, weekdays | One a day |
| Off-the-job pacing | Thursdays only, only when below target | Once a week |
| Grade returned | When a mark arrives from ELE2 (§8.4a) | Once per grade |
| Session starting | 30 minutes before a session, only on session days | Once |
| Sunday review | 18:00 Sundays — notification and email | Once a week |

**The ceiling: at most one notification a day, plus the Sunday digest.** If two would fire, the more urgent wins and the other is folded into tomorrow's morning plan. An app that can produce six notifications in a day will be muted within a fortnight, and then it produces none.

**Never on a Sunday** except the 18:00 review. **Never between 21:00 and 07:00.** Never twice for the same fact.

If three consecutive morning plans go unopened, stop sending them and say so once in Settings rather than continuing to fire into the void.

---

## 12. Grades and distinction tracking

Assignments carry a real mark once returned, pulled from the ELE2 gradebook automatically (§8.4a) and entered by hand only when ingestion isn't available. Bands are configurable in Settings, defaulting to the common UK undergraduate pattern: distinction/first at 70, merit/2:1 at 60, pass/2:2 at 50, threshold at 40. Confirm Exeter's actual bands and classification rules at induction and correct the defaults.

Module view shows weighted progress: marks received, weight remaining, and the mark needed on remaining assessments to reach the target. That last number is the one that matters. It should be prominent, and it should be honest — when a target has become unreachable, say so plainly rather than hiding it.

No predicted grades from AI in v1. A confident number generated from a draft is more likely to mislead than help. Revisit once there are several real marks and real feedback to calibrate against.

---

## 13. Delivery plan

### v1 — before 22 September 2026

Everything needed to survive induction and the first on-campus block. Ship without polish if the deadline forces it.

- SwiftData models, the shared `StudyBotCore` package, and the design system primitives
- The Vapor server, SQLite, Litestream backups, pairing auth and the sync engine
- **Programme calendar import from the bundled ICS**, creating terms, modules, events and the 30 backlog assignments on first launch
- Design system primitives
- Assignments list and detail, without the AI checker
- Note workspace: live notes, `ASK:` capture, transcript paste and import
- `structureNotes` and `makeFlashcards`
- Revision: Leitner study mode
- Evidence capture with manual KSB linking
- Block Week mode
- ⌘K palette with navigation and `explain`

Out of scope for v1: Graph, GitHub, notifications, study planner, the draft checker, quizzes, export.

**Fallback:** if the native app is not ready by 22 September, the clickable prototype is the day-one tool. Ensure it can export its data as JSON in the shape of the models above, so nothing captured in the first block is lost when the real app arrives.

### v2 — October to December 2026

The long gap, and the point where the app stops needing you to feed it.

- **ELE2 ingestion** — Moodle web services if available, private calendar feed if not
- **The Needs a moment proposal queue**
- **Off-the-job timer** — menu bar on macOS, Live Activity on iOS
- **Calendar-derived hour proposals** for Monday sessions and campus days
- `outline`, `draftSection`, `checkDraft` with rubric support
- AI-use record and its export
- PDF brief import and field extraction
- Draft sources: `.docx` import with file watching, and draft snapshots
- Full-text search in ⌘K, FTS5 index
- GitHub release update checker and the schema-version guard
- Off-the-job log and configurable export
- Local notifications and the morning plan
- The menu bar item, with the timer and quick capture
- Scheduled routines: Sunday review, Monday prep, post-session wrap-up, work-back plans
- Quizzes and weak-area tracking
- Grade entry and distinction tracking

### v3 — 2027

- University email ingestion with change proposals
- OneNote mirroring
- Grade and feedback ingestion from the ELE2 gradebook
- Resource and reading pull from ELE2
- Microsoft Graph calendar and files, and work-calendar hour inference
- GitHub evidence and hour proposals
- The iPhone app, push notifications and the Apple Developer membership
- Webhooks — only if polling has proved too slow
- KSB coverage grid and portfolio export
- Study session booking into the calendar
- Cross-assignment feedback pattern analysis
- Live transcription, if the university permits recording

---

## 14. Open questions

Resolved by the programme calendar and structure diagram: the module list, all term and block dates, the teaching rhythm, and every submission deadline for three years.

Still open, and answerable in the first week:

1. **What each of the 30 submissions actually is.** The calendar gives dates and modules, not titles, formats or weightings. Expect ELE2 to fill these in per module.
2. **Exeter's off-the-job log format.** Required fields, column order, date format, submission cadence. The configurable export stands in until then.
3. **The KSB list.** Exact codes and wording from the apprenticeship standard as Exeter issues it. The model is ready; the data is not. Do not invent it.
4. **Off-the-job hours requirement,** and whether on-campus days and Monday sessions count in full.
5. **Exeter's AI policy.** What's permitted on submitted work and what must be declared. §7.3 defaults may need tightening.
6. **Grading bands, credit weightings and classification rules.**
7. **Year 3 specialism choice** — which of the five, and when it must be declared.
8. **Whether sessions may be recorded**, which determines if live transcription is ever buildable, and whether ELE2 publishes Teams transcripts automatically.
9. **Whether the work tenant permits third-party Graph access.** If not, v3's calendar and file work needs rethinking.
10. **Whether ELE2 has Moodle web services enabled** (`/login/token.php` with the `moodle_mobile_app` service). This single answer decides whether assignment ingestion is fully automatic or calendar-feed only, and it is worth asking IT in week one. Either way, confirm you can self-serve the private calendar export URL from the ELE2 calendar page — that is the fallback and it should always work.
11. **Whether the Exeter tenant permits third-party Graph access** for mail and OneNote. One consent prompt covers both; if it's refused, §8.2 and §8.5 are dead and everything else still works.
12. **Which Moodle grade endpoint ELE2 exposes** — `mod_assign_get_grades` or the gradereport API. Decides how §8.4a is implemented.
13. **Where year-3 term 3 begins.** The calendar can't say, because the Synoptic Project spans terms 2 and 3 so the module set never changes. The derived default is 18 April 2029; confirm it.
14. **How your OneNote notebooks are organised** — section names are what modules get matched against, so a consistent naming scheme makes §8.5 work and an inconsistent one makes it noise.

---

## 15. Non-goals

Stated so nobody builds them by accident.

- No collaboration, sharing or multi-user anything.
- No gamification: no streaks, points, badges or congratulation.
- No AI that writes a complete submission end to end.
- No Shortcuts, AppleScript or URL-scheme automation surface. Self-contained.
- No multi-user server. One user, one dataset, device tokens rather than accounts.
- No CloudKit, now or later (§3.1).
- No subscription, no App Store requirement for the Mac build.
- No Android, no web app.
- No general to-do management. Tasks exist only as subtasks of assignments.

---

## 16. Production readiness

This app holds three years of irreplaceable coursework and the evidence for an end-point assessment. Losing it is not a bug, it's a career problem. The bar is higher than a side project.

### Data durability

- **Migrations.** Every SwiftData schema change ships a versioned migration plan with a test that loads a store from the previous version. Never a destructive migration, never a "delete and reinstall" instruction.
- **Server backup.** Litestream continuous replication plus nightly snapshots, per §3.11.
- **Client backup.** A weekly automatic export to a JSON bundle plus attachments, written to a folder the user can see. Retained twelve weeks, rolling. This is deliberately independent of the server: sync is not backup, because a deletion replicates perfectly to everything.
- **Manual export on demand**, same format, from Settings. The user owns their data and can leave with it.
- **Import** of that bundle into a fresh install, tested end to end, because an export nobody has ever restored is not a backup.

### Reliability

Running out of disk is a first-class failure, not an edge case. SwiftData writes fail when the volume is full, and the moment this is most likely to happen is while typing fast during a lecture — the one thing the app exists to protect.

- Every store write checks its result. A failed write must surface immediately and visibly: a persistent banner on the note being edited, not a toast, not a log line. "This note could not be saved. Your disk is full." The text stays on screen and in memory; the user must never be able to close a window over unsaved work believing it was saved.
- On launch and hourly, check free space on the store's volume. Below 2 GB, warn once in Today. Below 500 MB, warn persistently.
- `NoteRevision` snapshots are skipped rather than allowed to fail, so revision writes never consume the last of the disk that a note write needs.
- A test forces a write failure and asserts the banner appears and the text is retained.

- Every network call has a timeout, a retry with backoff, and a user-visible failure state that says what broke and what to do.
- The app is fully functional offline. Notes, assignments, hours, evidence and revision all work with no connection. Only AI and ingestion degrade, and they degrade to a clear message, not a spinner.
- **AI provider outage** must not block anything. Queue the request, tell the user it will run when the service returns, and let them carry on.
- Ingestion is idempotent everywhere. Running it twice must never duplicate an assignment, an hour entry or a resource.

### Cost control

- Per-run and cumulative token spend visible in Settings, with a monthly cap the user sets. At 80% of cap, warn. At cap, stop and say so rather than silently failing.
- Long inputs are truncated with the user told what was cut. A 40-page PDF should not quietly cost £2.

### Security and privacy

- All tokens in the Keychain with appropriate accessibility attributes. Nothing sensitive in `UserDefaults`, ever.
- **No content in logs.** Log that a call happened, its capability and its token count. Never the prompt, never the response, never note text.
- Crash reporting is opt-in and must carry no user content.
- The work-confidentiality rule (§7.4) has a passing unit test as a release gate.
- A written privacy note in Settings, in plain language: what leaves the device, to whom, and what never does.
- **Deletion means deletion** — removing an assignment removes its attachments, AI runs and proposals, on every device.

### Accessibility

- Full VoiceOver support including the term strip, which needs a spoken summary rather than a per-mark reading: "Term 1, week 4 of 13. Next submission in 31 days."
- Dynamic Type up to the largest accessibility sizes with no clipping and no horizontal scrolling.
- Reduce Motion honoured per §9.
- Colour is never the only carrier of meaning; every status has an icon and a label.
- Full keyboard navigation on macOS with visible focus rings.

### Release

- TestFlight for both platforms before either is relied on. The first real use is 22 September 2026 and that is not the day to discover a sync bug.
- Developer ID signing and notarisation for the Mac build, whether or not it goes to the App Store.
- Version the JSON export format from day one so a future importer knows what it's reading.
- A visible "what changed" note on update, because a silent change to how hours are counted is indistinguishable from a bug.

### After July 2029

The course ends. The data shouldn't become unreadable the day the app stops being maintained.

- The JSON export format is **documented in the repo**, versioned, and plain enough to read without StudyBot — notes as markdown, attachments as files in a folder, a manifest tying them together. It should be possible to open your three years of work in a text editor in 2035.
- At the end of the final term the app offers a **complete archive**: every note, draft, piece of evidence, grade and hour, plus a readable summary document. One file, one folder of attachments.
- The server can then be shut down. The Mac app must remain fully functional read-only with sync disabled, rather than degrading into a login screen for a service that no longer exists.
- Nothing in the design may make this awkward. Specifically: no format that requires the server to interpret, and no attachment stored only by hash with no readable filename in the export.

### Definition of done

A feature is not done when it works. It's done when it works offline, fails legibly, survives a migration, is reachable by keyboard and VoiceOver, has no user content in its logs, and has a test for the case that would lose data.

---

## 17. Acceptance criteria for v1

The build is done when all of these are true.

1. An assignment can be created, given a module, status, priority and due date, and it appears correctly grouped in the list.
2. A session note can be typed live in sans-serif at a comfortable reading size, a `- ` line renders as a bullet without shifting the caret, an `ASK:` line highlights in place and appears in the questions list within the same keystroke, and both survive an app relaunch.
3. A `.vtt` transcript imports with timestamps stripped.
4. `structureNotes` returns markdown and writes it to the structured pane without altering live notes.
5. A deck generated from those notes can be studied, and a card answered incorrectly returns to box 1 and reappears the next day.
6. An evidence item can be created in under thirty seconds from the command palette.
7. An item marked work-confidential cannot reach an AI prompt — proven by a passing unit test, not by inspection.
8. Data written on one Mac appears on the other within a minute of both being online, with no manual sync, no push button and no primary-device concept.
9. Block Week mode shows three days side by side with an aggregated questions list.
10. Every shortcut in §10 works, and every one of them is discoverable from a menu or the palette.
11. The app is usable with VoiceOver, respects Reduce Motion, and works at Larger Text sizes without clipping.
12. Everything except AI works with the network off, and the AI failure message says what happened.
13. A full export can be produced, wiped, and restored into a fresh install with nothing lost.
14. The Assignments list opens scoped to the current term, and the count of hidden later submissions is visible.
15. ⌘K finds a phrase that exists only in the body of a session note, and shows the matching line.
16. A `.docx` attached as a draft re-extracts within seconds of being saved in Word, without a dialog.
17. A work-back plan places no milestone on a bank holiday, a closure or an on-campus day, and keeps two working days of buffer before the due date.
18. No routine spends from the AI budget without an explicit tap, and the estimated cost is shown before it does.
19. The menu bar timer shows elapsed time and survives the main window being closed.
20. The assignment panel is read-only until Edit is pressed, Cancel with changes asks before discarding, and Save writes exactly once.
21. A hand-edited due date survives an ELE2 poll that disagrees with it, and the disagreement is visible on the field.
