import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// The store behind Settings → Sync: pairing, the write-settle trigger, and the two lines
/// the screens show.
@MainActor
@Suite("SyncStore — pairing, scheduling and status")
struct SyncStoreTests {
    private nonisolated static let t0 = SyncClient.t0

    /// A pairing endpoint that accepts one code.
    struct FakePairing: PairingClient {
        let accepted: String
        func pair(_ request: PairRequest, at baseURL: URL) async throws -> PairResponse {
            guard request.code == accepted else {
                throw PairingError.refused(
                    "That pairing code is not valid. Run studybotctl pair for a new one.")
            }
            return PairResponse(
                token: "tok-\(request.deviceName)", deviceRecordID: UUID(), deviceName: request.deviceName)
        }
    }

    private struct Harness {
        let store: SyncStore
        let database: Database
        let credentials: InMemoryCredentialStore
    }

    private func makeStore(server: InMemorySyncServer, clock: TestClock) async throws -> Harness {
        let database = try Database.inMemory()
        let credentials = InMemoryCredentialStore()
        let store = SyncStore(
            database: database, credentials: credentials, deviceID: "air",
            pairingClient: FakePairing(accepted: "apple brook candle dune ember frost"),
            makeTransport: { _ in server }, now: { clock.now }, writeSettleDelay: .milliseconds(60),
            periodicInterval: .seconds(3_600))
        return Harness(store: store, database: database, credentials: credentials)
    }

    @Test("unpaired: no engine, honest status, nothing on Today")
    func unpaired() async throws {
        let clock = TestClock(Self.t0)
        let store = try await makeStore(server: InMemorySyncServer(), clock: clock).store
        await store.load()
        #expect(!store.isPaired)
        #expect(await store.syncNow() == nil)
        #expect(store.statusLine == "Not connected. This Mac works fully on its own.")
        #expect(store.todayNotice == nil)
    }

    @Test("pairing keeps the token and the address, then syncs; a wrong code says so and changes nothing")
    func pairing() async throws {
        let clock = TestClock(Self.t0)
        let server = InMemorySyncServer()
        let harness = try await makeStore(server: server, clock: clock)
        let (store, database, credentials) = (harness.store, harness.database, harness.credentials)
        await store.load()

        #expect(
            await store.pair(serverAddress: "studybot.example.com", code: "wrong words", deviceName: "Air")
                == false)
        #expect(store.pairingError?.contains("not valid") == true)
        #expect(try credentials.token() == nil)
        #expect(!store.isPaired)

        #expect(
            await store.pair(
                serverAddress: "studybot.example.com/", code: "apple brook candle dune ember frost",
                deviceName: "Air"))
        #expect(store.pairingError == nil)
        #expect(try credentials.token() == "tok-Air")
        let state = try await database.syncState()
        #expect(state.serverURL == URL(string: "https://studybot.example.com"))
        #expect(state.deviceName == "Air")
        #expect(store.lastOutcome == .synced(pushed: 0, pulled: 0))
        #expect(store.statusLine.hasPrefix("Last synced today at"))

        await store.unpair()
        #expect(!store.isPaired)
        #expect(try credentials.token() == nil)
    }

    @Test("a local write triggers one sync after it settles, not one per keystroke")
    func writeSettles() async throws {
        let clock = TestClock(Self.t0)
        let server = InMemorySyncServer()
        let harness = try await makeStore(server: server, clock: clock)
        let (store, database) = (harness.store, harness.database)
        _ = await store.pair(
            serverAddress: "http://localhost:8080", code: "apple brook candle dune ember frost",
            deviceName: "Air")
        let pushesAfterPairing = await server.pushCount

        try await database.save(Assignment(sync: .new(at: Self.t0, deviceID: "air"), title: "typed"))
        for _ in 0..<5 {
            store.noteLocalWrite()
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await server.pushCount == pushesAfterPairing, "nothing yet: the writes have not settled")
        #expect(
            await eventually { await server.pushCount == pushesAfterPairing + 1 },
            "one sync once the writes settled")
        #expect(try await database.dirtyWireRecords().isEmpty)
    }

    @Test("the Today line appears only after an hour of failures, or when blocked")
    func todayNotice() async throws {
        let clock = TestClock(Self.t0)
        let database = try Database.inMemory()
        let store = SyncStore(
            database: database, credentials: InMemoryCredentialStore(token: "tok"), deviceID: "air",
            makeTransport: { _ in DeadTransport() }, now: { clock.now })
        var state = SyncState()
        state.serverURL = URL(string: "https://studybot.example.com")
        try await database.saveSyncState(state)
        await store.load()

        #expect(await store.syncNow() == .offline)
        #expect(store.todayNotice == nil, "offline is not an error")
        #expect(store.statusLine.contains("unreachable"))

        clock.now = Self.t0.addingTimeInterval(3_700)
        #expect(store.todayNotice == "Changes haven't synced for an hour. They're safe on this Mac.")

        state.blockedRequiredVersion = 9
        try await database.saveSyncState(state)
        await store.load()
        #expect(store.todayNotice == SyncRefusal.userMessage)
    }
}
