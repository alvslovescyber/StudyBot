import Foundation
import StudyBotCore

/// A run of consecutive on-campus days (spec §4A "On-campus blocks"). Induction on
/// 22 September 2026 and the two days that follow it are one block from the user's point
/// of view ("Block 1 starts in 8 days · 22–24 Sept"), so adjacent campus events are merged.
public struct CampusBlock: Hashable, Sendable {
    /// 1-based, in date order. The induction-plus-first-block run is Block 1.
    public let number: Int
    public let start: LocalDay
    public let end: LocalDay
    /// The programme events that make up the block, in date order.
    public let eventIDs: [UUID]
    /// Whether the block begins with the induction day.
    public let includesInduction: Bool

    public init(number: Int, start: LocalDay, end: LocalDay, eventIDs: [UUID], includesInduction: Bool) {
        self.number = number
        self.start = start
        self.end = end
        self.eventIDs = eventIDs
        self.includesInduction = includesInduction
    }

    /// Number of campus days in the block.
    public var dayCount: Int { start.days(until: end) + 1 }

    /// Whether `day` falls inside the block.
    public func contains(_ day: LocalDay) -> Bool {
        day >= start && day <= end
    }

    /// Merges adjacent campus-day events (induction and on-campus) into numbered blocks.
    /// Cancelled events are ignored. Two events are adjacent when one starts the day after
    /// the other ends.
    public static func blocks(from events: [ProgrammeEvent]) -> [CampusBlock] {
        let campus =
            events
            .filter { !$0.isCancelled && $0.kind.isCampusDay }
            .sorted { $0.startDate < $1.startDate }

        var runs: [(start: LocalDay, end: LocalDay, ids: [UUID], induction: Bool)] = []
        for event in campus {
            let start = LocalDay(event.startDate)
            let end = LocalDay(event.endDate)
            if var last = runs.last, start <= last.end.adding(days: 1) {
                last.end = max(last.end, end)
                last.ids.append(event.id)
                last.induction = last.induction || event.kind == .induction
                runs[runs.count - 1] = last
            } else {
                runs.append((start, end, [event.id], event.kind == .induction))
            }
        }
        return runs.enumerated().map { index, run in
            CampusBlock(
                number: index + 1, start: run.start, end: run.end, eventIDs: run.ids,
                includesInduction: run.induction)
        }
    }
}
