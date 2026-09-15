import Foundation

/// A piece of portfolio evidence (spec §4, §6.5). Four fields to create; everything else
/// optional. `isWorkConfidential` blocks all AI processing (§7.4).
public struct Evidence: Syncable {
    public static let recordType = "evidence"

    public var sync: SyncMetadata
    public var title: String
    public var date: Date
    /// What the user did, in their own words.
    public var summary: String
    /// Many-to-many with KSBs, by id.
    public var ksbIDs: [UUID]
    public var source: EvidenceSource
    /// True blocks all AI processing. Defaults to true for anything sourced from work.
    public var isWorkConfidential: Bool
    /// Evidence can double as an off-the-job entry.
    public var otjEntryID: UUID?
    /// An assignment can also be KSB evidence.
    public var assignmentID: UUID?
    /// Evidence created from a lecture.
    public var sessionID: UUID?
    /// What went well, what you'd change.
    public var reflection: String?
    /// KSB codes typed before the official list exists (§14, question 3). Kept as text so a
    /// capture never waits on data Exeter has not issued; resolved into `ksbIDs` when the
    /// list is imported.
    public var pendingKSBCodes: [String]

    public init(
        sync: SyncMetadata,
        title: String,
        date: Date,
        summary: String,
        ksbIDs: [UUID] = [],
        source: EvidenceSource,
        isWorkConfidential: Bool? = nil,
        otjEntryID: UUID? = nil,
        assignmentID: UUID? = nil,
        sessionID: UUID? = nil,
        reflection: String? = nil,
        pendingKSBCodes: [String] = []
    ) {
        self.sync = sync
        self.title = title
        self.date = date
        self.summary = summary
        self.ksbIDs = ksbIDs
        self.source = source
        self.isWorkConfidential = isWorkConfidential ?? source.defaultsToConfidential
        self.otjEntryID = otjEntryID
        self.assignmentID = assignmentID
        self.sessionID = sessionID
        self.reflection = reflection
        self.pendingKSBCodes = pendingKSBCodes
    }
}
