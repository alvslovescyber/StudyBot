import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// §3.12 rows "Sync engine", "Two-client convergence", "Schema-version guard" and the sync half
/// of "Backup/restore", against two simulated Macs and an in-memory server that runs the same
/// `SyncMerge` rule as the Vapor server.
@Suite("SyncEngine — data safety with two clients", .serialized)
struct SyncEngineTests {
    private let t0 = SyncClient.t0

    /// Two clients that both hold `id` after a first exchange.
    private func pairedClients(server: InMemorySyncServer, sharing id: UUID) async throws -> (
        SyncClient, SyncClient
    ) {
        let macA = try await SyncClient("a-air", transport: server)
        let macB = try await SyncClient("b-mini", transport: server)
        try await macA.create("Requirements report", id: id)
        #expect(await macA.engine.sync() == .synced(pushed: 1, pulled: 1))
        #expect(await macB.engine.sync() == .synced(pushed: 0, pulled: 1))
        #expect(try await macB.title(id) == "Requirements report")
        return (macA, macB)
    }

    @Test("two clients edit different records offline and both converge")
    func differentRecordsConverge() async throws {
        let server = InMemorySyncServer()
        let macA = try await SyncClient("a-air", transport: server)
        let macB = try await SyncClient("b-mini", transport: server)
        let x = try await macA.create("Written on A", at: 10)
        let y = try await macB.create("Written on B", at: 20)

        _ = await macA.engine.sync()
        _ = await macB.engine.sync()
        _ = await macA.engine.sync()

        #expect(try await macA.title(y.id) == "Written on B")
        #expect(try await macB.title(x.id) == "Written on A")
        #expect(try await macA.dirtyCount() == 0)
        #expect(try await macB.dirtyCount() == 0)
        #expect(await server.allRecords.count == 2)
        #expect(await server.archivedRecords.isEmpty)
        let aVersion = try await macA.require(x.id).sync
        #expect(aVersion.version == 1 && aVersion.baseVersion == 1 && aVersion.seq == 1)
    }

    @Test("both edit the same record: the later write wins and the loser is retrievable on both sides")
    func sameRecordConflict() async throws {
        let server = InMemorySyncServer()
        let id = UUID()
        let (macA, macB) = try await pairedClients(server: server, sharing: id)

        // Offline on both. A edits first, B edits later.
        try await macA.edit(id, title: "A's wording", at: 100)
        try await macB.edit(id, title: "B's wording", at: 200)

        // B reaches the server first, then A. A's push loses.
        #expect(await macB.engine.sync() == .synced(pushed: 1, pulled: 1))
        _ = await macA.engine.sync()

        #expect(try await macA.title(id) == "B's wording")
        #expect(try await macB.title(id) == "B's wording")
        #expect(try await macA.dirtyCount() == 0)

        // A's losing version is kept whole on A and on the server, and the two agree.
        let losers = try await macA.database.conflictLosers(for: id)
        #expect(losers.count == 1)
        let loser = try #require(losers.first)
        #expect(loser.record.fields["title"] == "A's wording")
        #expect(loser.record.updatedAt == t0.addingTimeInterval(100))
        let archiveID = try #require(loser.serverArchiveID)
        let archived = try #require(await server.archived(archiveID))
        #expect(archived.record.fields["title"] == "A's wording")
        #expect(archived.record.deviceID == "a-air")
    }

    @Test(
        "when the later write arrives first, the earlier one is archived server-side and named on the acceptance"
    )
    func laterArrivesFirst() async throws {
        let server = InMemorySyncServer()
        let id = UUID()
        let (macA, macB) = try await pairedClients(server: server, sharing: id)
        try await macA.edit(id, title: "A's wording", at: 100)
        try await macB.edit(id, title: "B's wording", at: 200)

        // A reaches the server first: accepted. B's later edit then overrides it.
        _ = await macA.engine.sync()
        _ = await macB.engine.sync()
        _ = await macA.engine.sync()

        #expect(try await macA.title(id) == "B's wording")
        #expect(try await macB.title(id) == "B's wording")
        let archived = await server.archivedRecords
        #expect(archived.count == 1)
        #expect(archived.first?.record.fields["title"] == "A's wording")
    }

    @Test("a same-millisecond tie resolves to the lower deviceID on both Macs, whichever syncs first")
    func sameMillisecondTie() async throws {
        for firstToSync in ["a-air", "b-mini"] {
            let server = InMemorySyncServer()
            let id = UUID()
            let (macA, macB) = try await pairedClients(server: server, sharing: id)
            try await macA.edit(id, title: "A at the same instant", at: 300.250)
            try await macB.edit(id, title: "B at the same instant", at: 300.250)

            let order = firstToSync == "a-air" ? [macA, macB, macA] : [macB, macA, macB]
            for client in order { _ = await client.engine.sync() }

            #expect(try await macA.title(id) == "A at the same instant", "first to sync: \(firstToSync)")
            #expect(try await macB.title(id) == "A at the same instant", "first to sync: \(firstToSync)")
            #expect(try await macA.dirtyCount() == 0)
            #expect(try await macB.dirtyCount() == 0)
            // B's version is retrievable: on the server always, and on B when B lost on push.
            let archived = await server.archivedRecords
            #expect(archived.count == 1)
            #expect(archived.first?.record.fields["title"] == "B at the same instant")
            if firstToSync == "a-air" {
                #expect(
                    try await macB.database.conflictLosers(for: id).first?.record.fields["title"]
                        == "B at the same instant")
            }
        }
    }

    @Test("interrupted mid-push leaves no partial state and the retry is not a second version")
    func interruptedMidPush() async throws {
        let server = InMemorySyncServer()
        let interrupting = InterruptingTransport(server)
        let macA = try await SyncClient("a-air", transport: interrupting)
        let record = try await macA.create("Programming coursework 1", at: 5)

        // The server commits, the response is lost.
        #expect(await macA.engine.sync() == .offline)
        #expect(try await macA.dirtyCount() == 1)
        #expect(try await macA.cursor() == 0)
        #expect(try await macA.require(record.id).sync.version == 0)
        #expect(await server.record(id: record.id)?.version == 1)

        // The retry is recognised as the same write.
        #expect(await macA.engine.sync() == .synced(pushed: 1, pulled: 1))
        #expect(try await macA.dirtyCount() == 0)
        #expect(await server.record(id: record.id)?.version == 1)
        #expect(await server.head == 1)
        #expect(await server.archivedRecords.isEmpty)
        #expect(try await macA.require(record.id).sync.version == 1)
        #expect(try await macA.database.syncState().failingSince == nil)
    }

    @Test("a replayed push is idempotent at the transport level")
    func replayedPush() async throws {
        let server = InMemorySyncServer()
        let record = SyncRecord(
            type: "assignment", id: UUID(), baseVersion: 0, updatedAt: t0, fields: ["title": "once"],
            deviceID: "a-air")
        let request = SyncPushRequest(deviceID: "a-air", cursor: 0, records: [record])
        let first = try await server.push(request, token: "tok")
        let second = try await server.push(request, token: "tok")
        #expect(first.accepted.map(\.version) == [1])
        #expect(second.accepted.map(\.version) == [1])
        #expect(second.conflicts.isEmpty)
        #expect(await server.head == 1)
        #expect(await server.archivedRecords.isEmpty)
    }

    @Test("the engine never runs twice concurrently and a call made mid-run is not lost")
    func neverConcurrent() async throws {
        let server = InMemorySyncServer()
        let counting = CountingTransport(server)
        let macA = try await SyncClient("a-air", transport: counting)
        try await macA.create("one")
        await withTaskGroup(of: SyncEngine.Outcome.self) { group in
            for _ in 0..<6 {
                group.addTask { await macA.engine.sync() }
            }
            for await _ in group {}
        }
        #expect(await counting.maxInFlight == 1)
        #expect(try await macA.dirtyCount() == 0)
        #expect(await macA.engine.isRunning == false)
    }

    @Test("offline is a result, not an error: nothing thrown, changes kept, a quiet line after an hour")
    func offlineIsQuiet() async throws {
        let clock = TestClock(t0)
        let macA = try await SyncClient("a-air", transport: DeadTransport(), now: { clock.now })
        try await macA.create("Written offline")

        #expect(await macA.engine.sync() == .offline)
        #expect(try await macA.dirtyCount() == 1)
        let state = try await macA.database.syncState()
        #expect(state.failingSince == t0)
        #expect(state.lastError?.contains("unreachable") == true)
        #expect(!state.hasBeenFailingForAnHour(at: t0.addingTimeInterval(1_800)))
        #expect(state.hasBeenFailingForAnHour(at: t0.addingTimeInterval(3_601)))

        clock.now = t0.addingTimeInterval(7_200)
        #expect(await macA.engine.sync() == .offline)
        #expect(try await macA.database.syncState().failingSince == t0, "the run of failures keeps its start")
    }

    @Test("an old client round-trips fields it does not understand instead of dropping them")
    func oldClientRoundTripsUnknownFields() async throws {
        let server = InMemorySyncServer()
        let id = UUID()
        let (macA, macB) = try await pairedClients(server: server, sharing: id)

        // B is the newer build: it writes a field this schema has never heard of.
        var newer = try #require(try await macB.stored(id))
        newer.unknownFields["mentorName"] = "Dr Patel"
        newer.value.sync.markEdited(at: t0.addingTimeInterval(50), by: "b-mini")
        try await macB.database.save(newer)
        _ = await macB.engine.sync()
        #expect(await server.record(id: id)?.fields["mentorName"] == "Dr Patel")

        // A, the stale build, pulls it, edits the title, pushes.
        _ = await macA.engine.sync()
        #expect(try await macA.stored(id)?.unknownFields["mentorName"] == "Dr Patel")
        try await macA.edit(id, title: "Edited on the stale Mac", at: 60)
        _ = await macA.engine.sync()

        // The field survived the stale Mac's write, on the server and back on B.
        #expect(await server.record(id: id)?.fields["mentorName"] == "Dr Patel")
        #expect(await server.record(id: id)?.fields["title"] == "Edited on the stale Mac")
        _ = await macB.engine.sync()
        #expect(try await macB.title(id) == "Edited on the stale Mac")
        #expect(try await macB.stored(id)?.unknownFields["mentorName"] == "Dr Patel")
    }

    @Test("a client one version behind syncs; two behind is refused with 409 and loses nothing")
    func schemaVersionGuard() async throws {
        let oneAhead = InMemorySyncServer(schemaVersion: SyncSchema.current + 1)
        let macOK = try await SyncClient("a-air", transport: oneAhead)
        try await macOK.create("fine")
        #expect(await macOK.engine.sync() == .synced(pushed: 1, pulled: 1))

        let twoAhead = InMemorySyncServer(schemaVersion: SyncSchema.current + 2)
        let macOld = try await SyncClient("b-mini", transport: twoAhead)
        try await macOld.create("kept locally")
        #expect(await macOld.engine.sync() == .blocked(requiredVersion: SyncSchema.current + 1))
        #expect(try await macOld.dirtyCount() == 1)
        let state = try await macOld.database.syncState()
        #expect(state.blockedRequiredVersion == SyncSchema.current + 1)
        #expect(state.lastError == SyncRefusal.userMessage)

        // It stops asking until it is updated: the second attempt never reaches the server.
        let pushesBefore = await twoAhead.pushCount
        #expect(await macOld.engine.sync() == .blocked(requiredVersion: SyncSchema.current + 1))
        #expect(await twoAhead.pushCount == pushesBefore)

        // Updated to the required version, it syncs and the block clears.
        let updated = SyncEngine(
            database: macOld.database, transport: twoAhead, credentials: macOld.credentials,
            deviceID: "b-mini",
            schemaVersion: SyncSchema.current + 1, now: { SyncClient.t0 })
        #expect(await updated.sync() == .synced(pushed: 1, pulled: 1))
        #expect(try await macOld.database.syncState().blockedRequiredVersion == nil)
    }

    @Test("a server restored from a backup is reconciled: nothing lost, the stale server versions archived")
    func restoreFromBackup() async throws {
        let server = InMemorySyncServer()
        let id = UUID()
        let (macA, macB) = try await pairedClients(server: server, sharing: id)
        let backup = await server.snapshot()

        // Life goes on after the backup: two edits on A, one on B, all synced.
        try await macA.edit(id, title: "Second draft", at: 100)
        _ = await macA.engine.sync()
        let other = try await macB.create("Only ever on B, after the backup", at: 150)
        _ = await macB.engine.sync()
        try await macA.edit(id, title: "Third draft", at: 200)
        _ = await macA.engine.sync()
        _ = await macB.engine.sync()
        #expect(try await macB.title(id) == "Third draft")
        #expect(try await macA.cursor() > backup.headSeq)

        // Disaster, then a Litestream restore to the backup.
        await server.restore(backup)
        #expect(await server.record(id: id)?.fields["title"] == "Requirements report")
        #expect(await server.record(id: other.id) == nil)

        // A reconciles: it notices the cursor went backwards and offers everything back.
        _ = await macA.engine.sync()
        #expect(await server.record(id: id)?.fields["title"] == "Third draft")
        #expect(try await macA.dirtyCount() == 0)
        // B reconciles too; the record B created after the backup comes back.
        _ = await macB.engine.sync()
        #expect(await server.record(id: other.id)?.fields["title"] == "Only ever on B, after the backup")
        _ = await macA.engine.sync()

        #expect(try await macA.title(id) == "Third draft")
        #expect(try await macB.title(id) == "Third draft")
        #expect(try await macA.title(other.id) == "Only ever on B, after the backup")
        #expect(try await macA.dirtyCount() == 0)
        #expect(try await macB.dirtyCount() == 0)
        // The version the restore brought back was archived when the newer one replaced it.
        #expect(await server.archivedRecords.contains { $0.record.fields["title"] == "Requirements report" })
    }

    @Test("a tombstone propagates and the row stays for the purge")
    func tombstonePropagates() async throws {
        let server = InMemorySyncServer()
        let id = UUID()
        let (macA, macB) = try await pairedClients(server: server, sharing: id)
        try await macA.delete(id, at: 100)
        _ = await macA.engine.sync()
        _ = await macB.engine.sync()
        let onB = try #require(try await macB.stored(id))
        #expect(onB.value.sync.isDeleted)
        #expect(try await macB.database.fetchAll(Assignment.self, includeDeleted: false).isEmpty)
        #expect(try await macB.database.fetchAll(Assignment.self, includeDeleted: true).count == 1)
        #expect(await server.record(id: id)?.deletedAt != nil)
    }

    @Test("the cursor paginates past 500 records")
    func paginatesPast500() async throws {
        let server = InMemorySyncServer()
        let macA = try await SyncClient("a-air", transport: server)
        let macB = try await SyncClient("b-mini", transport: server)
        let deckID = UUID()
        let cards = (0..<1_150).map { index in
            Card(
                sync: .new(at: t0.addingTimeInterval(Double(index)), deviceID: "a-air"), deckID: deckID,
                front: "Q\(index)", back: "A\(index)", source: nil, box: 1, dueDate: t0, lapses: 0)
        }
        try await macA.database.saveAll(cards)
        _ = await macA.engine.sync()
        #expect(await server.head == 1_150)

        let pullsBefore = await server.pullCount
        _ = await macB.engine.sync()
        #expect(try await macB.database.count(Card.self) == 1_150)
        #expect(await server.pullCount - pullsBefore >= 3)
        #expect(try await macB.cursor() == 1_150)
    }
}
