import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// §6.1: three items at most, generated locally, and honest about real data.
@Suite("TodayPlanner — three items, from what is actually there")
struct TodayPlannerTests {
    private static let t0 = SyncClient.t0

    private func input(
        today: LocalDay, assignments: [Assignment] = [], sessions: [Session] = [], evidenceThisWeek: Int = 1,
        hoursThisWeek: Double = 6, isInTerm: Bool = true
    ) throws -> TodayPlanner.Input {
        TodayPlanner.Input(
            today: today, assignments: assignments, sessions: sessions,
            workingDays: WorkingDays(events: try RealCalendar.events()), evidenceThisWeek: evidenceThisWeek,
            hoursThisWeek: hoursThisWeek, targetHoursPerWeek: 6, isInTerm: isInTerm)
    }

    private func stub(due: LocalDay, title: String) -> Assignment {
        Assignment(
            sync: .new(at: Self.t0), title: title, status: .backlog, dueDate: due.date,
            programmeEventID: UUID())
    }

    @Test("before induction, with the real stubs, the plan is one line about the first brief")
    func realStubs() throws {
        let events = try RealCalendar.events()
        let calendar = TermCalendar(events: events, derivedAt: RealCalendar.importedAt)
        let reading = try ICSProgrammeCalendarReader.read(
            try BundledProgrammeCalendar.data(), importedAt: RealCalendar.importedAt)
        let modules = ModuleSeeder.modules(from: reading, terms: calendar, now: Self.t0)
        let stubs = AssignmentStubs.stubs(for: events, modules: modules, now: Self.t0)
        // Wednesday 16 September 2026, before induction: no hours to log yet, so only deadlines speak.
        let plan = TodayPlanner.plan(
            try input(
                today: RealCalendar.day(2026, 9, 16), assignments: stubs, evidenceThisWeek: 0, hoursThisWeek: 0,
                isInTerm: false))
        #expect(plan.count == 1)
        #expect(plan.first?.title.hasPrefix("Check ELE2 for the brief: ") == true)
        #expect(plan.first?.minutes == 10)
        #expect(plan.first?.id.hasPrefix("brief.") == true)
    }

    @Test("a stub due further than six weeks out is not worth a line yet")
    func farStub() throws {
        let plan = TodayPlanner.plan(
            try input(
                today: RealCalendar.day(2026, 9, 16),
                assignments: [stub(due: RealCalendar.day(2027, 1, 14), title: "January")]))
        #expect(plan.isEmpty)
    }

    @Test("a real assignment proposes its next undone subtask, else the step its status implies")
    func deadlines() throws {
        let today = RealCalendar.day(2026, 10, 6)
        var withSubtasks = Assignment(
            sync: .new(at: Self.t0), title: "Requirements report", status: .drafting,
            dueDate: RealCalendar.day(2026, 10, 15).date, briefText: "brief")
        withSubtasks.subtasks = [
            Subtask(title: "Draft section 2", order: 1), Subtask(title: "Read the brief", isDone: true, order: 0),
        ]
        let drafting = Assignment(
            sync: .new(at: Self.t0), title: "Maths worksheet", status: .drafting,
            dueDate: RealCalendar.day(2026, 10, 20).date, briefText: "brief")
        let backlog = Assignment(
            sync: .new(at: Self.t0), title: "Networks essay", status: .todo,
            dueDate: RealCalendar.day(2026, 10, 30).date, briefText: "brief")
        let far = Assignment(
            sync: .new(at: Self.t0), title: "Next term", status: .todo, dueDate: RealCalendar.day(2027, 3, 1).date,
            briefText: "brief")
        let plan = TodayPlanner.plan(
            try input(today: today, assignments: [far, backlog, drafting, withSubtasks]))
        #expect(plan.map(\.title) == [
            "Draft section 2: Requirements report", "Draft Maths worksheet", "Break Networks essay into steps",
        ])
        #expect(plan.map(\.minutes) == [60, 90, 30])
        #expect(plan.count == TodayPlanner.maximumItems, "the far one is cut by the horizon and the cap")
    }

    @Test("last week's unstructured notes ask to be reviewed; structured and old ones do not")
    func reviews() throws {
        let today = RealCalendar.day(2026, 10, 6)
        func session(daysAgo: Int, notes: String, structured: String? = nil) -> Session {
            Session(
                sync: .new(at: Self.t0), title: "Session \(daysAgo)", date: today.adding(days: -daysAgo).date,
                liveNotes: notes, structuredNotes: structured)
        }
        let plan = TodayPlanner.plan(
            try input(
                today: today,
                sessions: [
                    session(daysAgo: 8, notes: "old"), session(daysAgo: 1, notes: "fresh"),
                    session(daysAgo: 2, notes: "done", structured: "## Done"), session(daysAgo: 3, notes: ""),
                    session(daysAgo: 0, notes: "today's, still going"),
                ]))
        #expect(plan.map(\.title) == ["Review notes: Session 1"])
        #expect(plan.first?.minutes == 30)
    }

    @Test("late in the week the two logs that get skipped are proposed, and never on a Monday")
    func weekItems() throws {
        let thursday = RealCalendar.day(2026, 10, 8)
        let plan = TodayPlanner.plan(try input(today: thursday, evidenceThisWeek: 0, hoursThisWeek: 1))
        #expect(plan.map(\.id) == ["evidence.week", "hours.week"])
        let monday = RealCalendar.day(2026, 10, 5)
        #expect(TodayPlanner.plan(try input(today: monday, evidenceThisWeek: 0, hoursThisWeek: 0)).isEmpty)
        let wednesday = RealCalendar.day(2026, 10, 7)
        #expect(
            TodayPlanner.plan(try input(today: wednesday, evidenceThisWeek: 0, hoursThisWeek: 0)).map(\.id) == [
                "hours.week"
            ], "evidence waits for Thursday; hours from Wednesday")
    }

    @Test("durations read as people say them")
    func durations() {
        #expect(PlanItem(id: "a", title: "", minutes: 10).duration == "10m")
        #expect(PlanItem(id: "a", title: "", minutes: 60).duration == "1h")
        #expect(PlanItem(id: "a", title: "", minutes: 90).duration == "1h 30m")
    }
}
