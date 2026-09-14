/// How far the Assignments list looks ahead (spec §6.2). Defaults to the current term so
/// day one does not show 29 italic placeholders and one real assignment. Persisted in `Settings`.
public enum AssignmentListScope: String, Codable, CaseIterable, Hashable, Sendable {
    case currentTerm
    case currentYear
    case all
}
