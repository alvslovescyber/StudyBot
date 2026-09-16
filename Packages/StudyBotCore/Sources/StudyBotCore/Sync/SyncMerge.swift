import Foundation

/// The server's decision for one pushed record (spec §3.4, §3.5). Pure: the same inputs give
/// the same outcome on the Vapor server, on the in-memory server the tests use, and on a Mac
/// deciding whether a pulled change beats an edit it has not pushed yet.
///
/// The rules, in order:
/// 1. A record the server has never seen is accepted.
/// 2. A write based on the server's current version is a plain sequential edit: accepted.
/// 3. The same writer at the same instant is the same write arriving again (a push whose
///    response was lost): already applied, acknowledged with the existing version. So is a
///    write whose content is identical to what the server holds: two Macs importing the same
///    calendar produce the same 66 records, and that is agreement, not a conflict.
/// 4. Otherwise two devices edited concurrently. `LastWriteWins` decides: later `updatedAt`,
///    then lower `deviceID`. The loser is archived either way, so neither direction of loss
///    is silent.
public enum SyncMerge {
    public enum Outcome: Hashable, Sendable {
        /// Store the incoming record as the new version. `replacing` names the server version
        /// this write overrides without having been based on it; the server archives it and
        /// reports `archivedAs` on the acceptance. Nil for a new record or a sequential edit.
        case accept(replacing: ServerRecordState?)
        /// The server's version is later. Keep it, archive the incoming record, report a conflict.
        case reject
        /// This exact write is already on the server. Acknowledge it; change nothing.
        case alreadyApplied
    }

    /// Decides what to do with `incoming`, pushed by `deviceID`, given what the server holds.
    /// A record that names its own writer (`incoming.deviceID`) is judged by that writer: a Mac
    /// re-offering records it did not write, after a server restore, must not look like a new
    /// edit from itself.
    public static func decide(
        incoming: SyncRecord, from deviceID: String, against existing: ServerRecordState?
    ) -> Outcome {
        guard let existing else { return .accept(replacing: nil) }
        if incoming.baseVersion == existing.version {
            return .accept(replacing: nil)
        }
        let writer = incoming.deviceID ?? deviceID
        if incoming.updatedAt == existing.updatedAt && writer == existing.deviceID {
            return .alreadyApplied
        }
        if sameContent(incoming, existing) {
            return .alreadyApplied
        }
        let incomingMeta = comparable(incoming, deviceID: writer)
        switch LastWriteWins.winner(incomingMeta, existing.comparable) {
        case .first: return .accept(replacing: existing)
        case .second: return .reject
        }
    }

    /// Whether a push would leave the server holding exactly what it already holds. Explicit
    /// nulls on the wire mean "cleared", so they are dropped before comparing.
    static func sameContent(_ incoming: SyncRecord, _ existing: ServerRecordState) -> Bool {
        guard incoming.deletedAt == existing.deletedAt else { return false }
        let pushed = incoming.fields.filter { !$0.value.isNull }
        return pushed == existing.fields
    }

    /// Client side: a pulled change has arrived for a record with a local edit not yet
    /// pushed. True when the local edit would win the same comparison the server will run
    /// when it is pushed, so the client keeps it; false when the server's version wins and
    /// the local version should be archived and replaced.
    public static func localEditWins(local: SyncMetadata, over change: SyncRecord) -> Bool {
        let server = comparable(change, deviceID: change.deviceID ?? "")
        return LastWriteWins.winner(local, server) == .first
    }

    /// Metadata for comparing a wire record. `version` is the server version when the record
    /// came from the server and `baseVersion` when it is being pushed, which is the version the
    /// pushing client last saw.
    static func comparable(_ record: SyncRecord, deviceID: String) -> SyncMetadata {
        SyncMetadata(
            id: record.id, createdAt: record.updatedAt, updatedAt: record.updatedAt,
            version: record.version ?? record.baseVersion, baseVersion: record.baseVersion,
            seq: record.seq ?? 0, deletedAt: record.deletedAt, dirty: false, deviceID: deviceID)
    }
}

extension SyncMerge {
    /// The writer a server should record for an accepted push: the record's own if it names one.
    public static func writer(of incoming: SyncRecord, pushedBy deviceID: String) -> String {
        incoming.deviceID ?? deviceID
    }
}
