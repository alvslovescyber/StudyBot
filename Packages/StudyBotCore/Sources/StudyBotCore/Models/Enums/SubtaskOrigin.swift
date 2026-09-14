/// Who created a subtask (spec §4 `Subtask.createdBy`): the user by hand, or the
/// work-back plan routine (§8.11).
public enum SubtaskOrigin: String, Codable, CaseIterable, Hashable, Sendable {
    case user
    case workBackPlan
}
