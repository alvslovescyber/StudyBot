/// Assignment priority (spec §4). Order is ascending urgency; `PriorityBars` draws
/// 0–4 bars from `barCount`.
public enum Priority: String, Codable, CaseIterable, Hashable, Sendable, Comparable {
    case none
    case low
    case medium
    case high
    case urgent

    /// Number of bars shown in the list row: 0 for none, 4 for urgent.
    public var barCount: Int {
        switch self {
        case .none: 0
        case .low: 1
        case .medium: 2
        case .high: 3
        case .urgent: 4
        }
    }

    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.barCount < rhs.barCount
    }
}
