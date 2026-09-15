import Foundation

/// Body of a `409` from `/v1/sync` (spec §3.10a): the client is more than one schema version
/// behind. It stops syncing, keeps working offline, and shows §9's copy. Nothing is dropped.
public struct SyncRefusal: Codable, Hashable, Sendable {
    /// The oldest schema version the server still accepts.
    public var requiredVersion: Int
    /// The server's own schema version.
    public var serverVersion: Int

    public init(requiredVersion: Int, serverVersion: Int) {
        self.requiredVersion = requiredVersion
        self.serverVersion = serverVersion
    }

    /// §9 "Client too far behind".
    public static let userMessage = "This Mac is running an old version of StudyBot. Update it to sync again."
}
