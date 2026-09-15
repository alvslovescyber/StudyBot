import Foundation
import StudyBotCore

/// The client's sync bookkeeping (spec §3.4): the cursor, where the server is, and how the
/// last runs went. One row, stored beside the records it describes, so a store restored from
/// a backup brings the matching cursor with it. The bearer token is not here; it lives in
/// the Keychain (§3.6).
public struct SyncState: Hashable, Sendable, Codable {
    public static let singletonID = StableID.uuid(namespace: StableID.Namespace.settings, name: "sync-state")

    /// The highest server `seq` applied locally. Zero before the first pull.
    public var cursor: Int
    /// The paired server. Nil until pairing.
    public var serverURL: URL?
    /// The name this Mac gave when pairing.
    public var deviceName: String?
    public var lastAttemptAt: Date?
    public var lastSuccessAt: Date?
    /// When the current run of failures began; nil while things are fine. Today shows one
    /// quiet line once this is more than an hour ago (§3.4, §9).
    public var failingSince: Date?
    /// Plain-language reason for the last failure, for Settings. Never user content.
    public var lastError: String?
    /// Set when the server refused this build's schema version (§3.10a). Syncing stops until
    /// the app is updated to at least this version.
    public var blockedRequiredVersion: Int?

    public init(
        cursor: Int = 0, serverURL: URL? = nil, deviceName: String? = nil, lastAttemptAt: Date? = nil,
        lastSuccessAt: Date? = nil, failingSince: Date? = nil, lastError: String? = nil,
        blockedRequiredVersion: Int? = nil
    ) {
        self.cursor = cursor
        self.serverURL = serverURL
        self.deviceName = deviceName
        self.lastAttemptAt = lastAttemptAt
        self.lastSuccessAt = lastSuccessAt
        self.failingSince = failingSince
        self.lastError = lastError
        self.blockedRequiredVersion = blockedRequiredVersion
    }

    /// Whether this Mac has a server to talk to.
    public var isPaired: Bool { serverURL != nil }

    /// §9 "Push failing over an hour": true once failures have run for more than an hour.
    public func hasBeenFailingForAnHour(at now: Date) -> Bool {
        guard let failingSince else { return false }
        return now.timeIntervalSince(failingSince) > 3_600
    }
}
