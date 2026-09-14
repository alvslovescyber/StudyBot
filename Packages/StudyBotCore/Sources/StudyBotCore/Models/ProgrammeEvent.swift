import Foundation

/// Every dated thing the university has told you about (spec §4). Read-only: it comes from
/// the programme calendar and the user cannot edit it, only attach their own work to it.
///
/// Deliberately **not** `Syncable`: it is derived from the bundled ICS, identical on every
/// device, and each Mac imports it independently and arrives at the same result. The id
/// is derived from `sourceUID` so those results agree.
///
/// Dates are date-only. Both are stored at Europe/London midnight and compared by
/// calendar day, never by interval. `endDate` is **inclusive**: the ICS `DTEND` is exclusive
/// and the importer converts it, so a 23–25 September ICS event is 23–24 here.
public struct ProgrammeEvent: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// First day, at local midnight.
    public var startDate: Date
    /// Last day, inclusive, at local midnight.
    public var endDate: Date
    public var kind: EventKind
    public var title: String
    /// Module codes the event covers, e.g. `["COM1018DA", "COM1014DA"]`. Empty for bank
    /// holidays, closures and a few un-attributed submissions.
    public var moduleCodes: [String]
    /// The ICS `UID`, for idempotent re-import.
    public var sourceUID: String
    /// Set when a reissued calendar no longer contains this event (§4A). Cancelled rather
    /// than deleted so any notes attached to it survive.
    public var cancelledAt: Date?
    /// When the importer last saw this event in a calendar file.
    public var lastImportedAt: Date

    public init(
        id: UUID? = nil,
        startDate: Date,
        endDate: Date,
        kind: EventKind,
        title: String,
        moduleCodes: [String],
        sourceUID: String,
        cancelledAt: Date? = nil,
        lastImportedAt: Date
    ) {
        self.id = id ?? ProgrammeEvent.stableID(forSourceUID: sourceUID)
        self.startDate = startDate
        self.endDate = endDate
        self.kind = kind
        self.title = title
        self.moduleCodes = moduleCodes
        self.sourceUID = sourceUID
        self.cancelledAt = cancelledAt
        self.lastImportedAt = lastImportedAt
    }

    /// The deterministic id for an ICS UID, so every device derives the same record.
    public static func stableID(forSourceUID uid: String) -> UUID {
        StableID.uuid(namespace: StableID.Namespace.programmeEvent, name: uid)
    }

    /// Whether the event has been withdrawn by a reissued calendar.
    public var isCancelled: Bool { cancelledAt != nil }

    /// Whether the event spans more than one day.
    public var isMultiDay: Bool { startDate != endDate }
}
