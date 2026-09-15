import Foundation
import StudyBotCore
import StudyBotKit

/// One simulated Mac: its own store, engine and token, talking to a shared transport.
struct SyncClient {
    let name: String
    let database: Database
    let engine: SyncEngine
    let credentials: InMemoryCredentialStore

    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    init(
        _ name: String, transport: any SyncTransport, token: String = "tok",
        schemaVersion: Int = SyncSchema.current,
        now: @escaping @Sendable () -> Date = { SyncClient.t0 }
    ) async throws {
        self.name = name
        database = try Database.inMemory()
        credentials = InMemoryCredentialStore(token: token)
        var state = SyncState()
        state.serverURL = URL(string: "memory://server")
        state.deviceName = name
        try await database.saveSyncState(state)
        engine = SyncEngine(
            database: database, transport: transport, credentials: credentials, deviceID: name,
            schemaVersion: schemaVersion, now: now)
    }

    /// A new assignment written locally at `at`, dirty, as the Assignments screen would create it.
    @discardableResult
    func create(_ title: String, id: UUID = UUID(), at offset: TimeInterval = 0) async throws -> Assignment {
        let assignment = Assignment(
            sync: .new(id: id, at: Self.t0.addingTimeInterval(offset), deviceID: name), title: title,
            status: .backlog)
        try await database.save(assignment)
        return assignment
    }

    /// Edits a stored assignment's title at `at`, the way the detail panel's Save does.
    func edit(_ id: UUID, title: String, at offset: TimeInterval) async throws {
        var record = try await require(id)
        record.title = title
        record.sync.markEdited(at: Self.t0.addingTimeInterval(offset), by: name)
        try await database.save(record)
    }

    func delete(_ id: UUID, at offset: TimeInterval) async throws {
        var record = try await require(id)
        record.sync.markDeleted(at: Self.t0.addingTimeInterval(offset), by: name)
        try await database.save(record)
    }

    func require(_ id: UUID) async throws -> Assignment {
        guard let stored = try await database.fetch(Assignment.self, id: id) else {
            throw Failure.missing(name, id)
        }
        return stored.value
    }

    func title(_ id: UUID) async throws -> String { try await require(id).title }

    func stored(_ id: UUID) async throws -> StoredRecord<Assignment>? {
        try await database.fetch(Assignment.self, id: id)
    }

    func dirtyCount() async throws -> Int { try await database.dirtyWireRecords().count }

    func cursor() async throws -> Int { try await database.syncState().cursor }

    enum Failure: Error { case missing(String, UUID) }
}

/// A transport that forwards to the server and then pretends the network died before the
/// response arrived: the server has committed, the client never hears. Once, on the first push.
actor InterruptingTransport: SyncTransport {
    private let server: InMemorySyncServer
    private var interruptNextPush = true

    init(_ server: InMemorySyncServer) { self.server = server }

    func push(_ request: SyncPushRequest, token: String) async throws -> SyncPushResponse {
        let response = try await server.push(request, token: token)
        if interruptNextPush {
            interruptNextPush = false
            throw SyncTransportError.unreachable("connection lost after the server committed")
        }
        return response
    }

    func pull(since: Int, limit: Int, schemaVersion: Int, token: String) async throws -> SyncPullResponse {
        try await server.pull(since: since, limit: limit, schemaVersion: schemaVersion, token: token)
    }
}

/// A transport that counts how many calls are in flight at once.
actor CountingTransport: SyncTransport {
    private let server: InMemorySyncServer
    private var inFlight = 0
    private(set) var maxInFlight = 0
    private(set) var calls = 0

    init(_ server: InMemorySyncServer) { self.server = server }

    private func enter() {
        inFlight += 1
        calls += 1
        maxInFlight = max(maxInFlight, inFlight)
    }

    private func leave() { inFlight -= 1 }

    func push(_ request: SyncPushRequest, token: String) async throws -> SyncPushResponse {
        enter()
        defer { leave() }
        try await Task.sleep(for: .milliseconds(5))
        return try await server.push(request, token: token)
    }

    func pull(since: Int, limit: Int, schemaVersion: Int, token: String) async throws -> SyncPullResponse {
        enter()
        defer { leave() }
        try await Task.sleep(for: .milliseconds(5))
        return try await server.pull(since: since, limit: limit, schemaVersion: schemaVersion, token: token)
    }
}

/// A server that is switched off.
struct DeadTransport: SyncTransport {
    func push(_ request: SyncPushRequest, token: String) async throws -> SyncPushResponse {
        throw SyncTransportError.unreachable("no route to host")
    }

    func pull(since: Int, limit: Int, schemaVersion: Int, token: String) async throws -> SyncPullResponse {
        throw SyncTransportError.unreachable("no route to host")
    }
}

/// A clock the test can move.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) { current = start }

    var now: Date {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}
