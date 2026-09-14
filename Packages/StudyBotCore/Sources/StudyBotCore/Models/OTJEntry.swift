import Foundation

/// An off-the-job hours entry (spec §4). The export is configurable rather than the model,
/// because Exeter's required format is unknown until induction.
public struct OTJEntry: Syncable {
    public static let recordType = "otjEntry"

    public var sync: SyncMetadata
    /// Date-only, at Europe/London midnight.
    public var date: Date
    public var hours: Double
    public var category: OTJCategory
    public var description: String
    public var assignmentID: UUID?
    public var evidenceID: UUID?
    /// The session this entry logs attendance for, if any (§4 "What counts as attended").
    public var sessionID: UUID?
    public var isSubmittedToProvider: Bool

    public init(
        sync: SyncMetadata,
        date: Date,
        hours: Double,
        category: OTJCategory,
        description: String,
        assignmentID: UUID? = nil,
        evidenceID: UUID? = nil,
        sessionID: UUID? = nil,
        isSubmittedToProvider: Bool = false
    ) {
        self.sync = sync
        self.date = date
        self.hours = hours
        self.category = category
        self.description = description
        self.assignmentID = assignmentID
        self.evidenceID = evidenceID
        self.sessionID = sessionID
        self.isSubmittedToProvider = isSubmittedToProvider
    }
}
