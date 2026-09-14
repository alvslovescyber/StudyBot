import Foundation

/// A Knowledge, Skill or Behaviour from the apprenticeship standard (spec §4).
///
/// The list ships **empty**. Codes and wording are imported from the published standard
/// and whatever Exeter issues at induction; nothing here may be invented (§14, question 3).
/// Coverage is derived from linked evidence, not stored.
public struct KSB: Syncable {
    public static let recordType = "ksb"

    public var sync: SyncMetadata
    /// e.g. "K3", "S12", "B4"
    public var code: String
    public var category: KSBCategory
    /// The official wording.
    public var text: String
    /// The user explicitly marked coverage as strong regardless of evidence count (§6.5).
    public var markedStrong: Bool

    public init(
        sync: SyncMetadata, code: String, category: KSBCategory, text: String, markedStrong: Bool = false
    ) {
        self.sync = sync
        self.code = code
        self.category = category
        self.text = text
        self.markedStrong = markedStrong
    }

    /// Derived coverage for a count of linked evidence items (§6.5).
    public func coverage(evidenceCount: Int) -> CoverageLevel {
        if markedStrong && evidenceCount > 0 { return .strong }
        return CoverageLevel.forEvidenceCount(evidenceCount)
    }
}
