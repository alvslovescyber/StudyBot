import Foundation

/// A step within an assignment (spec §4 Supporting types). Owned by the assignment and
/// stored inline, so it travels with it through sync.
public struct Subtask: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var isDone: Bool
    public var dueDate: Date?
    /// Position within the assignment's subtask list.
    public var order: Int
    public var createdBy: SubtaskOrigin

    public init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        order: Int,
        createdBy: SubtaskOrigin = .user
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.order = order
        self.createdBy = createdBy
    }
}
