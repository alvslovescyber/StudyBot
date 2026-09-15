import Foundation
import StudyBotCore

/// How the engine reaches a server (spec §3.5). `HTTPSyncTransport` is the real one;
/// `InMemorySyncServer` stands in for tests and previews. The engine never knows which.
public protocol SyncTransport: Sendable {
    func push(_ request: SyncPushRequest, token: String) async throws -> SyncPushResponse
    func pull(since: Int, limit: Int, schemaVersion: Int, token: String) async throws -> SyncPullResponse
}

/// What can go wrong talking to the server, sorted by what the client should do about it.
public enum SyncTransportError: Error, Equatable, Sendable {
    /// `409`: this build is too far behind (§3.10a). Stop syncing until updated.
    case schemaRefused(SyncRefusal)
    /// `401`: the token is revoked or unknown. Pair again.
    case unauthorised
    /// The server could not be reached. Offline is not an error state (§3.4).
    case unreachable(String)
    /// The server answered with something unexpected.
    case server(status: Int, detail: String)
}

/// Where the bearer token lives (spec §3.6): the Keychain on a real Mac, memory in tests.
public protocol SyncCredentialStore: Sendable {
    func token() throws -> String?
    func save(token: String) throws
    func clear() throws
}

/// A credential store for tests and previews.
public final class InMemoryCredentialStore: SyncCredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?

    public init(token: String? = nil) {
        stored = token
    }

    public func token() throws -> String? {
        lock.withLock { stored }
    }

    public func save(token: String) throws {
        lock.withLock { stored = token }
    }

    public func clear() throws {
        lock.withLock { stored = nil }
    }
}
