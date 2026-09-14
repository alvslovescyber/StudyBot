/// Why a `NoteRevision` was captured (spec §4).
public enum RevisionReason: String, Codable, CaseIterable, Hashable, Sendable {
    case idleSnapshot
    case preSync
    case conflictLoser
}
