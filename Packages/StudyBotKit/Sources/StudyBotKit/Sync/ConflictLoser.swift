import Foundation
import StudyBotCore

/// A local version that lost a last-write-wins race (spec §3.4 "the losing version is …
/// kept locally"). Kept whole, with every field it had, so nothing that was on this Mac is
/// ever only recoverable from the server. Local-only, never synced; pruned after 30 days.
public struct ConflictLoser: Identifiable, Hashable, Sendable, Codable {
    /// How long losers are kept.
    public static let retentionDays = NoteRevision.conflictLoserRetentionDays

    public var id: UUID
    /// The losing version exactly as it stood here: type, fields, `updatedAt`, writer.
    public var record: SyncRecord
    public var archivedAt: Date
    /// The server version that replaced it.
    public var replacedByVersion: Int
    /// The server's own archive id for the same loss (`archivedAs`), when it reported one.
    public var serverArchiveID: String?

    public init(
        id: UUID = UUID(), record: SyncRecord, archivedAt: Date, replacedByVersion: Int,
        serverArchiveID: String? = nil
    ) {
        self.id = id
        self.record = record
        self.archivedAt = archivedAt
        self.replacedByVersion = replacedByVersion
        self.serverArchiveID = serverArchiveID
    }
}
