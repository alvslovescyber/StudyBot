/// Derived KSB coverage (spec §4, §6.5): none (no evidence), partial (one or two items),
/// strong (three or more, or one the user explicitly marked as strong).
public enum CoverageLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case none
    case partial
    case strong

    /// The coverage level for a count of linked evidence items, before any explicit override.
    public static func forEvidenceCount(_ count: Int) -> CoverageLevel {
        switch count {
        case ..<1: .none
        case 1...2: .partial
        default: .strong
        }
    }
}
