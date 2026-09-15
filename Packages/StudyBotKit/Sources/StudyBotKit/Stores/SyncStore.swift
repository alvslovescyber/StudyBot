import Foundation
import Observation
import StudyBotCore

/// The sync domain store (§3.3 `SyncStore`): what Settings → Sync and Today read, and the
/// scheduler §3.4 describes. Triggers: launch, every five minutes while running, and ten
/// seconds after a local write settles. Owns the `SyncEngine`, which does the work.
///
/// Nothing here is an alert. Offline is a status line; a run of failures longer than an hour
/// is one quiet line on Today (§9).
@MainActor
@Observable
public final class SyncStore {
    public private(set) var state = SyncState()
    public private(set) var lastOutcome: SyncEngine.Outcome?
    public private(set) var isSyncing = false
    public private(set) var isPairing = false
    /// The last pairing failure, in plain language, or nil.
    public private(set) var pairingError: String?

    private let database: Database
    private let credentials: any SyncCredentialStore
    private let pairingClient: any PairingClient
    private let makeTransport: @Sendable (URL) -> any SyncTransport
    private let deviceID: String
    private let now: @Sendable () -> Date
    private let writeSettleDelay: Duration
    private let periodicInterval: Duration

    private var engine: SyncEngine?
    private var settleTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?

    public init(
        database: Database, credentials: any SyncCredentialStore, deviceID: String,
        pairingClient: any PairingClient = HTTPPairingClient(),
        makeTransport: @escaping @Sendable (URL) -> any SyncTransport = { HTTPSyncTransport(baseURL: $0) },
        now: @escaping @Sendable () -> Date = { Date() },
        writeSettleDelay: Duration = .seconds(10), periodicInterval: Duration = .seconds(300)
    ) {
        self.database = database
        self.credentials = credentials
        self.deviceID = deviceID
        self.pairingClient = pairingClient
        self.makeTransport = makeTransport
        self.now = now
        self.writeSettleDelay = writeSettleDelay
        self.periodicInterval = periodicInterval
    }

    // MARK: Lifecycle

    /// Reads the saved state and, if paired, builds the engine.
    public func load() async {
        state = (try? await database.syncState()) ?? SyncState()
        if let url = state.serverURL {
            engine = SyncEngine(
                database: database, transport: makeTransport(url), credentials: credentials,
                deviceID: deviceID,
                now: now)
        } else {
            engine = nil
        }
    }

    /// Launch trigger plus the five-minute timer.
    public func start() async {
        await load()
        _ = await syncNow()
        periodicTask?.cancel()
        periodicTask = Task { [weak self, periodicInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: periodicInterval)
                guard !Task.isCancelled else { return }
                _ = await self?.syncNow()
            }
        }
    }

    public func stop() {
        periodicTask?.cancel()
        settleTask?.cancel()
    }

    /// A local write happened. Sync once it has settled for `writeSettleDelay`.
    public func noteLocalWrite() {
        settleTask?.cancel()
        settleTask = Task { [weak self, writeSettleDelay] in
            try? await Task.sleep(for: writeSettleDelay)
            guard !Task.isCancelled else { return }
            _ = await self?.syncNow()
        }
    }

    /// Runs the engine now. Nil when not paired.
    @discardableResult
    public func syncNow() async -> SyncEngine.Outcome? {
        guard let engine else { return nil }
        isSyncing = true
        let outcome = await engine.sync()
        isSyncing = false
        lastOutcome = outcome
        state = (try? await database.syncState()) ?? state
        return outcome
    }

    // MARK: Pairing (§3.6, §6.0)

    /// Exchanges a six-word code for a token, keeps the token in the credential store and the
    /// server address in `SyncState`, then syncs. Returns false with `pairingError` set on failure.
    public func pair(serverAddress: String, code: String, deviceName: String) async -> Bool {
        isPairing = true
        pairingError = nil
        defer { isPairing = false }
        do {
            let url = try HTTPPairingClient.baseURL(from: serverAddress)
            let response = try await pairingClient.pair(
                PairRequest(code: code, deviceName: deviceName), at: url)
            try credentials.save(token: response.token)
            var state = (try? await database.syncState()) ?? SyncState()
            state.serverURL = url
            state.deviceName = response.deviceName
            state.blockedRequiredVersion = nil
            state.lastError = nil
            state.failingSince = nil
            try await database.saveSyncState(state)
            await load()
            await syncNow()
            return true
        } catch let error as PairingError {
            pairingError = error.message
        } catch {
            pairingError = "Couldn't finish pairing: \(error.localizedDescription)"
        }
        return false
    }

    /// Forgets the server and the token. Local data is untouched; nothing is deleted anywhere.
    public func unpair() async {
        try? credentials.clear()
        var state = (try? await database.syncState()) ?? SyncState()
        state.serverURL = nil
        state.deviceName = nil
        state.blockedRequiredVersion = nil
        state.lastError = nil
        state.failingSince = nil
        try? await database.saveSyncState(state)
        engine = nil
        lastOutcome = nil
        self.state = state
    }

    // MARK: What the screens show

    public var isPaired: Bool { state.isPaired }

    /// One line for Settings → Sync.
    public var statusLine: String {
        guard state.isPaired else { return "Not connected. This Mac works fully on its own." }
        if isSyncing { return "Syncing…" }
        if let required = state.blockedRequiredVersion {
            return "\(SyncRefusal.userMessage) (needs schema \(required))"
        }
        if let error = state.lastError {
            return error
        }
        if let last = state.lastSuccessAt {
            return
                "Last synced \(RelativeDate.string(for: last, relativeTo: now())) at \(RelativeDate.time(last))."
        }
        return "Paired. Not synced yet."
    }

    /// The one line Today may show (§3.4, §9): only after an hour of failures, or when blocked.
    public var todayNotice: String? {
        guard state.isPaired else { return nil }
        if state.blockedRequiredVersion != nil { return SyncRefusal.userMessage }
        if state.hasBeenFailingForAnHour(at: now()) {
            return "Changes haven't synced for an hour. They're safe on this Mac."
        }
        return nil
    }
}
