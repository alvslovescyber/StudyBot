import Foundation
import StudyBotCore

/// The client's sync engine (spec §3.4): one serialised actor, never two runs in flight,
/// push dirty records then pull until caught up, apply every response through `Database` so
/// nothing lands half-way. Offline is a result, not an error: nothing here throws to a view.
public actor SyncEngine {
    /// How a run ended. Views show none of these except, eventually, a quiet line.
    public enum Outcome: Equatable, Sendable {
        /// Pushed and pulled; counts are records.
        case synced(pushed: Int, pulled: Int)
        /// No server or no token yet. Not a failure.
        case notPaired
        /// The server could not be reached. The changes are safe on this Mac.
        case offline
        /// The server refused this build's schema version. Stop until updated (§3.10a).
        case blocked(requiredVersion: Int)
        /// The token was refused. Pair again.
        case unauthorised
        /// Something else; `SyncState.lastError` says what in plain words.
        case failed
    }

    /// A safety limit on push/pull rounds in one run. Convergence takes two or three; the
    /// cap only matters if a server misbehaves.
    static let maximumRounds = 50

    private let database: Database
    private let transport: any SyncTransport
    private let credentials: any SyncCredentialStore
    private let deviceID: String
    private let schemaVersion: Int
    private let now: @Sendable () -> Date

    private var running: Task<Outcome, Never>?
    private var runAgain = false
    public private(set) var lastOutcome: Outcome?

    public init(
        database: Database, transport: any SyncTransport, credentials: any SyncCredentialStore,
        deviceID: String,
        schemaVersion: Int = SyncSchema.current, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.database = database
        self.transport = transport
        self.credentials = credentials
        self.deviceID = deviceID
        self.schemaVersion = schemaVersion
        self.now = now
    }

    /// Runs a sync. A call made while one is in flight waits for it and then runs once more,
    /// so a write that landed during a run is never left behind, and two runs never overlap.
    public func sync() async -> Outcome {
        if let running {
            runAgain = true
            return await running.value
        }
        let task = Task { await self.performRun() }
        running = task
        let outcome = await task.value
        running = nil
        lastOutcome = outcome
        if runAgain {
            runAgain = false
            return await sync()
        }
        return outcome
    }

    public var isRunning: Bool { running != nil }

    // MARK: One run

    private func performRun() async -> Outcome {
        var state: SyncState
        let token: String
        do {
            state = try await database.syncState()
            guard state.isPaired, let stored = try credentials.token() else { return .notPaired }
            token = stored
        } catch {
            return await record(.failed, error: "Couldn't read sync state: \(error.localizedDescription)")
        }
        if let required = state.blockedRequiredVersion {
            if schemaVersion < required { return .blocked(requiredVersion: required) }
            state.blockedRequiredVersion = nil
        }
        state.lastAttemptAt = now()
        try? await database.saveSyncState(state)

        do {
            let counts = try await exchange(token: token)
            return await record(.synced(pushed: counts.pushed, pulled: counts.pulled), error: nil)
        } catch SyncTransportError.schemaRefused(let refusal) {
            var state = (try? await database.syncState()) ?? SyncState()
            state.blockedRequiredVersion = refusal.requiredVersion
            state.lastError = SyncRefusal.userMessage
            try? await database.saveSyncState(state)
            return .blocked(requiredVersion: refusal.requiredVersion)
        } catch SyncTransportError.unauthorised {
            return await record(
                .unauthorised, error: "The server no longer recognises this Mac. Pair it again.")
        } catch SyncTransportError.unreachable(let detail) {
            return await record(.offline, error: "Server unreachable: \(detail)")
        } catch {
            return await record(.failed, error: "Sync failed: \(error.localizedDescription)")
        }
    }

    /// Push everything dirty, pull everything new, repeat until both are empty.
    private func exchange(token: String) async throws -> (pushed: Int, pulled: Int) {
        var pushed = 0
        var pulled = 0
        for _ in 0..<SyncEngine.maximumRounds {
            var regressed = false
            let dirty = try await database.dirtyWireRecords()
            for batch in dirty.chunks(of: SyncPullResponse.pageSize) where !regressed {
                let cursor = try await database.syncState().cursor
                let request = SyncPushRequest(
                    schemaVersion: schemaVersion, deviceID: deviceID, cursor: cursor, records: batch)
                let response = try await transport.push(request, token: token)
                let summary = try await database.applyPushResponse(response, pushed: batch, now: now())
                pushed += response.accepted.count
                pulled += summary.applied
                regressed = summary.cursorRegressed
            }
            if regressed { continue }
            var hasMore = true
            while hasMore && !regressed {
                let cursor = try await database.syncState().cursor
                let response = try await transport.pull(
                    since: cursor, limit: SyncPullResponse.pageSize, schemaVersion: schemaVersion,
                    token: token)
                let summary = try await database.applyPullResponse(response, now: now())
                pulled += summary.applied
                hasMore = response.hasMore
                regressed = summary.cursorRegressed
            }
            if regressed { continue }
            if try await database.dirtyWireRecords().isEmpty { break }
        }
        return (pushed, pulled)
    }

    /// Writes the outcome into `SyncState`: success clears the failure run, a failure starts
    /// or continues one. `lastError` is plain language and never user content (§3.10).
    private func record(_ outcome: Outcome, error: String?) async -> Outcome {
        guard var state = try? await database.syncState() else { return outcome }
        if let error {
            state.lastError = error
            state.failingSince = state.failingSince ?? now()
        } else {
            state.lastError = nil
            state.failingSince = nil
            state.lastSuccessAt = now()
        }
        try? await database.saveSyncState(state)
        return outcome
    }
}

extension Array {
    /// The array in consecutive slices of at most `size`.
    func chunks(of size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
