# StudyBot — milestone two

Paste below the line into Claude Code. **First** overwrite `studybot-build-spec.md` in the repo root with the revised copy and have it commit that, so the code and the spec agree before anything new is built.

---

Milestone one looks good. The spec in the repo root is now the revised copy — commit it first, then read the sections that changed before you start: §3.5 (`archivedAs` on accepted records), §4 (value types, `WallClockTime`, `cancelledAt`), §4A (term boundaries, block merging, submission titling, 26 modules).

## Before anything else

**Install Xcode.** Milestone two is SwiftData and it won't build without it. Stop and tell me if it isn't there.

## Milestone two: the local store

Persistence only. **Still no UI.** The store is what everything else sits on, and it's the piece that decides whether sync is straightforward or miserable in milestone four.

1. **The SwiftData layer in `StudyBotKit`.** `@Model` classes wrapping the `StudyBotCore` structs, converting at that boundary. Nothing outside `StudyBotKit` learns that SwiftData exists — if a `@Model` type appears in a signature in Core or leaks toward the UI packages, that's the bug.

2. **One `Database` actor** owning the `ModelContainer`, per §3.3. It is the only thing that touches SwiftData directly. Expect Swift 6 strict concurrency to make this slower than you'd like; take the time now rather than retrofitting it later.

3. **Unknown-field preservation has to survive storage, not just decoding.** §3.10a calls this the most likely way this two-Mac setup loses data. The `JSONValue` seam you built in Core needs somewhere to live in the persisted model — an unknown-fields blob on each syncable type — so a record written by a newer build, read by an older one, and written back again comes out unchanged. A Codable round-trip test is not enough; this needs a store round-trip test.

4. **`SyncMetadata` persists in full.** All eight fields, including `seq` and `baseVersion`, even though nothing reads them yet.

5. **A versioned migration plan from v1**, with the harness in place and a test that loads a store written by the previous schema version. There's only one version today, so the test is trivial — build it anyway. Adding it retrospectively once there's real data in there is how people end up doing destructive migrations.

6. **Wire the real store behind the importer's protocol.** The in-memory store stays for tests. Re-import against the real store must still be idempotent, still cancel removed UIDs without touching attached records, and still produce the 30 backlog assignments — now persisted, titled by date, with no module.

**Done when:** the importer runs against a real on-disk store and produces 156 events, 26 modules and 30 dated assignment stubs; a second run changes nothing; a record with unknown fields survives a write-read-write cycle unchanged; and the migration test passes.

## One piece of housekeeping

You've been producing a good running log of places the spec was wrong or underspecified. Put it in `docs/decisions.md` — one short entry each: what the spec said, what you did, why. Future sessions will otherwise relitigate the term-boundary rule and the value-type decision from scratch, and I'd rather they read the reasoning than rediscover it.

## After this

Milestone three is the design system primitives and the Assignments screen — the first thing either of us can actually look at. `studybot-prototype.jsx` in the repo root is the visual reference and §9 is authoritative for the values.

Don't start it in this milestone. A store that half-works under a screen that looks finished is harder to fix than a store with no screen at all.
