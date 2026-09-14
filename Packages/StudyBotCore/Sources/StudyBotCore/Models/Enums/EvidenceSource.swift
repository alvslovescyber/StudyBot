/// Where a piece of KSB evidence came from (spec §4).
public enum EvidenceSource: String, Codable, CaseIterable, Hashable, Sendable {
    case workProject
    case assignment
    case lecture
    case reflection
    case codeCommit

    /// Evidence sourced from work defaults to confidential (§6.5, §7.4).
    public var defaultsToConfidential: Bool {
        switch self {
        case .workProject, .codeCommit: true
        case .assignment, .lecture, .reflection: false
        }
    }
}
