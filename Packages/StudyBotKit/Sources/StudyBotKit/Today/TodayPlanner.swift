import Foundation
import StudyBotCore

/// One line of Today's plan (§6.1): what to do and roughly how long.
public struct PlanItem: Identifiable, Hashable, Codable, Sendable {
    /// Stable across regenerations, so a ticked item stays ticked when the plan is rebuilt.
    public let id: String
    public let title: String
    public let minutes: Int
    public var isDone: Bool

    public init(id: String, title: String, minutes: Int, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.isDone = isDone
    }

    /// "90m", "1h", "1h 30m".
    public var duration: String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(rest)m"
        }
    }
}

/// Today's plan (§6.1): generated locally from due dates, remaining subtasks and the notes of
/// the last week. Never by the AI, so it works offline and instantly. Three items at most, and
/// none when there is honestly nothing to propose: the three calendar stubs before induction
/// yield one line about the first brief, not an invented study schedule.
public enum TodayPlanner {
    public struct Input: Sendable {
        public var today: LocalDay
        public var assignments: [Assignment]
        public var sessions: [Session]
        public var workingDays: WorkingDays
        public var evidenceThisWeek: Int
        public var hoursThisWeek: Double
        public var targetHoursPerWeek: Double

        public init(
            today: LocalDay, assignments: [Assignment], sessions: [Session], workingDays: WorkingDays,
            evidenceThisWeek: Int, hoursThisWeek: Double, targetHoursPerWeek: Double
        ) {
            self.today = today
            self.assignments = assignments
            self.sessions = sessions
            self.workingDays = workingDays
            self.evidenceThisWeek = evidenceThisWeek
            self.hoursThisWeek = hoursThisWeek
            self.targetHoursPerWeek = targetHoursPerWeek
        }
    }

    public static let maximumItems = 3
    /// An assignment is worth a plan line once it is within this many working days.
    public static let deadlineHorizonWorkingDays = 21
    /// A calendar stub's brief is worth checking for once the deadline is within six weeks.
    public static let briefHorizonDays = 42

    public static func plan(_ input: Input) -> [PlanItem] {
        var items: [PlanItem] = []
        items += deadlineItems(input)
        items += reviewItems(input)
        items += weekItems(input)
        return Array(items.prefix(maximumItems))
    }

    // MARK: Sources

    /// Soonest deadline first: the next undone subtask, or the step the status implies.
    private static func deadlineItems(_ input: Input) -> [PlanItem] {
        let due = input.assignments
            .filter { $0.isIncomplete && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        return due.compactMap { assignment -> PlanItem? in
            guard let dueDate = assignment.dueDate else { return nil }
            let dueDay = LocalDay(dueDate)
            if assignment.isCalendarStub {
                guard input.today.days(until: dueDay) <= briefHorizonDays else { return nil }
                return PlanItem(
                    id: "brief.\(assignment.id)", title: "Check ELE2 for the brief: \(assignment.title)",
                    minutes: 10)
            }
            let overdue = dueDay < input.today
            let working = input.workingDays.count(from: input.today, until: dueDay)
            guard overdue || working <= deadlineHorizonWorkingDays else { return nil }
            if let next = assignment.subtasks.sorted(by: { $0.order < $1.order }).first(where: { !$0.isDone }) {
                return PlanItem(
                    id: "subtask.\(assignment.id).\(next.id)", title: "\(next.title): \(assignment.title)",
                    minutes: 60)
            }
            switch assignment.status {
            case .backlog, .todo:
                return PlanItem(id: "plan.\(assignment.id)", title: "Break \(assignment.title) into steps", minutes: 30)
            case .drafting:
                return PlanItem(id: "draft.\(assignment.id)", title: "Draft \(assignment.title)", minutes: 90)
            case .review:
                return PlanItem(
                    id: "review.\(assignment.id)", title: "Read \(assignment.title) through once more", minutes: 45)
            case .submitted, .graded:
                return nil
            }
        }
    }

    /// Notes from the last seven days that have not been structured yet, newest first.
    private static func reviewItems(_ input: Input) -> [PlanItem] {
        let weekAgo = input.today.adding(days: -7)
        return input.sessions
            .filter { session in
                let day = LocalDay(session.date)
                return session.hasNotes && session.structuredNotes == nil && day < input.today && day >= weekAgo
            }
            .sorted { $0.date > $1.date }
            .map { PlanItem(id: "notes.\($0.id)", title: "Review notes: \($0.title)", minutes: 30) }
    }

    /// Late in the week, the two logs that get skipped: evidence and hours.
    private static func weekItems(_ input: Input) -> [PlanItem] {
        var items: [PlanItem] = []
        let weekday = input.today.isoWeekday
        if weekday >= 4, input.evidenceThisWeek == 0 {
            items.append(PlanItem(id: "evidence.week", title: "Log this week's work as evidence", minutes: 10))
        }
        if weekday >= 3, input.hoursThisWeek < input.targetHoursPerWeek / 2 {
            items.append(PlanItem(id: "hours.week", title: "Log off-the-job hours", minutes: 5))
        }
        return items
    }
}
