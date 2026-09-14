/// Assignment workflow state (spec §4). The case order is the list order in the UI and
/// mirrors Linear's issue states: backlog → todo → drafting → review → submitted → graded.
public enum AssignmentStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case backlog
    case todo
    case drafting
    case review
    case submitted
    case graded

    /// Whether the assignment still needs work. Submitted and graded are complete.
    public var isIncomplete: Bool {
        switch self {
        case .backlog, .todo, .drafting, .review: true
        case .submitted, .graded: false
        }
    }
}
