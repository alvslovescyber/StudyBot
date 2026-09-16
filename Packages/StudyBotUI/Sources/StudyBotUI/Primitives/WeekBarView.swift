import SwiftUI

/// The week bar (Today, "Make logging feel good"): seven small vertical bars, one per day,
/// height proportional to hours logged, the target as a line across. The line is a working
/// day's share of the weekly target (a fifth), since a daily bar can only be measured against
/// a daily figure. Logging an hour makes today's bar grow with a 500ms spring (§9). That
/// growth is the whole reward. No streaks, no badges, no colour beyond today's bar.
public struct WeekBarView: View {
    public struct Day: Identifiable, Hashable, Sendable {
        public let id: String
        /// "M", "T", …
        public let letter: String
        public let hours: Double
        public let isToday: Bool

        public init(id: String, letter: String, hours: Double, isToday: Bool) {
            self.id = id
            self.letter = letter
            self.hours = hours
            self.isToday = isToday
        }
    }

    private let days: [Day]
    private let weeklyTarget: Double
    @Environment(\.sbScale) private var scale

    public static let barHeight: CGFloat = 56
    /// Working days a weekly target is spread over.
    public static let workingDaysPerWeek = 5.0

    public init(days: [Day], weeklyTarget: Double) {
        self.days = days
        self.weeklyTarget = weeklyTarget
    }

    /// The line: one working day's share of the week's target.
    private var target: Double { weeklyTarget / Self.workingDaysPerWeek }

    /// The scale's top: twice the daily target, or the biggest day if it is over that.
    private var ceiling: Double {
        max(target * 2, days.map(\.hours).max() ?? 0, 1)
    }

    public var body: some View {
        VStack(spacing: scale(6)) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: scale(6)) {
                    ForEach(days) { day in
                        bar(day)
                    }
                }
                // The target: a hairline across, at the target's height.
                if target > 0 {
                    SBColor.borderStrong.frame(height: 1)
                        .padding(.bottom, Self.barHeight * CGFloat(target / ceiling) - 0.5)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: Self.barHeight)
            .sbAnimation(SBMotion.hoursBar, value: days)
            HStack(spacing: scale(6)) {
                ForEach(days) { day in
                    Text(day.letter)
                        .sbFont(10, weight: .medium)
                        .foregroundStyle(day.isToday ? SBColor.textPrimary : SBColor.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private func bar(_ day: Day) -> some View {
        let height = max(Self.barHeight * CGFloat(day.hours / ceiling), day.hours > 0 ? 3 : 2)
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(day.hours > 0 ? (day.isToday ? SBColor.accent : SBColor.textTertiary) : SBColor.border)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private var summary: String {
        let total = days.reduce(0) { $0 + $1.hours }
        return "\(Self.hours(total)) of \(Self.hours(weeklyTarget)) hours this week"
    }

    /// "4.5", "6".
    public static func hours(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
