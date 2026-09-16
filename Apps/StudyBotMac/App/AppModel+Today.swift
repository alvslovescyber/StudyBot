import Foundation
import StudyBotCore
import StudyBotKit
import StudyBotUI

/// What Today (§6.1) reads from the model: the block banner, the next deadline, the term strip
/// and glance, the plan, and the hours field.
extension AppModel {
    // MARK: Today (§6.1)

    struct BlockBanner: Equatable {
        let title: String
        let dates: String
    }

    /// The block banner, within 14 days of an on-campus block or during one.
    var blockBanner: BlockBanner? {
        guard let calendar = termCalendar else { return nil }
        let today = LocalDay(now())
        guard let block = calendar.currentOrNextBlock(from: today),
            let days = calendar.daysToNextBlock(from: today),
            days <= 14
        else { return nil }
        let name = "Block \(block.number)"
        let title: String
        switch days {
        case 0: title = "\(name) is on now"
        case 1: title = "\(name) starts tomorrow"
        default: title = "\(name) starts in \(days) days"
        }
        return BlockBanner(
            title: title, dates: RelativeDate.dayRange(block.start.date, block.end.date, relativeTo: now()))
    }

    /// Exactly one assignment: the soonest incomplete one, or the most recently overdue.
    var nextAssignment: Assignment? {
        let today = LocalDay(now())
        let incomplete = assignments?.assignments.filter(\.isIncomplete) ?? []
        return
            incomplete
            .filter { $0.dueDate.map { LocalDay($0) >= today } ?? false }
            .min { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            ?? incomplete.filter { $0.dueDate != nil }.max {
                ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast)
            }
    }

    func isOverdue(_ assignment: Assignment) -> Bool {
        guard let due = assignment.dueDate else { return false }
        return UKCalendar.days(from: now(), to: due) < 0
    }

    /// The deadline card's second line (§6.1): the honest number of working days, then what
    /// the assignment is still missing. Overdue stays "overdue by".
    func deadlineDetail(for assignment: Assignment, module: Module?) -> String {
        var parts: [String] = []
        if let code = module?.code {
            parts.append(code)
        }
        if let due = assignment.dueDate {
            if UKCalendar.days(from: now(), to: due) < 0 {
                parts.append(RelativeDate.deadline(due, relativeTo: now()))
            } else {
                let working = WorkingDays(events: events).count(from: now(), until: due)
                parts.append(RelativeDate.workingDays(working))
            }
        }
        if assignment.isCalendarStub {
            parts.append(module == nil ? "module and brief arrive from ELE2" : "brief arrives from ELE2")
        } else {
            if let limit = assignment.wordLimit {
                parts.append(RelativeDate.wordCount(limit))
            }
            parts.append(StatusIcon.label(for: assignment.status).lowercased())
        }
        return parts.joined(separator: " · ")
    }

    /// The term strip's data, with the module colours for single-module sessions.
    var termStrip: TermStrip? {
        guard let calendar = termCalendar else { return nil }
        let dueDates = assignments?.assignments.compactMap(\.dueDate) ?? []
        let colours = Dictionary(
            (assignments?.modules ?? []).map { ($0.code, $0.colour) }, uniquingKeysWith: { first, _ in first })
        return TermStrip(
            calendar: calendar, events: events, submissionDates: dueDates, today: LocalDay(now()),
            moduleColours: colours)
    }

    /// The four numbers for the current (or next) term.
    var termGlance: TermGlance? {
        guard let calendar = termCalendar else { return nil }
        let today = LocalDay(now())
        guard let term = calendar.term(containing: today) ?? calendar.nextTerm(after: today) else { return nil }
        return TermGlance(
            term: term, today: today, weekOfTerm: calendar.weekOfTerm(today), slots: sessionSlots,
            sessions: notes?.allSessions ?? [], evidence: evidence?.items ?? [], hours: hours?.entries ?? [],
            targetPerWeek: hours?.targetPerWeek ?? 6)
    }

    /// Rebuilds today's proposal from the store. Cheap, so it runs whenever Today appears or
    /// something it depends on changes; an accepted or dismissed plan ignores it.
    func refreshPlan() {
        guard let plan else { return }
        let today = LocalDay(now())
        let monday = today.adding(days: -(today.isoWeekday - 1))
        let evidenceThisWeek = (evidence?.items ?? []).filter { LocalDay($0.date) >= monday && LocalDay($0.date) <= today }
            .count
        let input = TodayPlanner.Input(
            today: today, assignments: assignments?.assignments ?? [], sessions: notes?.allSessions ?? [],
            workingDays: WorkingDays(events: events), evidenceThisWeek: evidenceThisWeek,
            hoursThisWeek: hours?.week(containing: today).total ?? 0, targetHoursPerWeek: hours?.targetPerWeek ?? 6,
            isInTerm: termCalendar?.term(containing: today) != nil)
        plan.refresh(with: TodayPlanner.plan(input))
    }

    func showHoursField() {
        guard phase == .ready else { return }
        paletteShown = false
        hoursFieldShown = true
    }

    /// Logs one line for today. The bar has already grown by the time this returns; on
    /// failure the store shrinks it back and says why beneath it.
    func logHours(_ line: String) async {
        await hours?.log(line)
        refreshPlan()
    }
}
