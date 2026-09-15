import StudyBotKit
import SwiftUI

/// A due date as words (spec §9 component inventory): relative under 14 days, absolute
/// beyond, red when overdue. All wording comes from `RelativeDate`, the one place dates
/// become words; this view only colours it.
public struct DueDateLabel: View {
    private let dueDate: Date?
    private let now: Date

    public init(_ dueDate: Date?, now: Date) {
        self.dueDate = dueDate
        self.now = now
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(
                isOverdue ? SBColor.danger : dueDate == nil ? SBColor.textTertiary : SBColor.textSecondary
            )
            .monospacedDigit()
            .lineLimit(1)
    }

    private var isOverdue: Bool {
        guard let dueDate else { return false }
        return UKCalendarDays.isPast(dueDate, relativeTo: now)
    }

    private var text: String {
        guard let dueDate else { return "" }
        if isOverdue {
            return RelativeDate.deadline(dueDate, relativeTo: now)
        }
        return RelativeDate.string(for: dueDate, relativeTo: now)
    }
}
