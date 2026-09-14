import Foundation

/// A record that travels through the sync engine (spec §3.4).
///
/// Conforming types embed a `SyncMetadata` and name their wire `recordType`, the string
/// that appears as `"type"` in the sync envelope (§3.5). `ProgrammeEvent` deliberately
/// does not conform: it is derived from the bundled ICS and never synced (§4).
public protocol Syncable: Identifiable, Codable, Hashable, Sendable where ID == UUID {
    /// The `"type"` discriminator used in the sync envelope, e.g. `"assignment"`.
    static var recordType: String { get }

    /// The eight shared sync fields.
    var sync: SyncMetadata { get set }
}

extension Syncable {
    /// The record's stable identity, taken from its sync metadata.
    public var id: UUID { sync.id }
}
