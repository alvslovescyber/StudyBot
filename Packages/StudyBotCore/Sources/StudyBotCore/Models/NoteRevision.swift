import Foundation

/// A captured version of a session's notes (spec §4). Local-only, never synced: independent
/// insurance against both the sync engine and the app. Last 20 per session on a 30-second
/// idle debounce, plus one before any sync overwrite. Conflict losers are kept 30 days.
public struct NoteRevision: Identifiable, Codable, Hashable, Sendable {
    /// How many idle snapshots are kept per session.
    public static let retainedPerSession = 20
    /// How long conflict losers are kept.
    public static let conflictLoserRetentionDays = 30

    public var id: UUID
    public var sessionID: UUID
    public var body: String
    public var capturedAt: Date
    public var reason: RevisionReason

    public init(id: UUID = UUID(), sessionID: UUID, body: String, capturedAt: Date, reason: RevisionReason) {
        self.id = id
        self.sessionID = sessionID
        self.body = body
        self.capturedAt = capturedAt
        self.reason = reason
    }
}
