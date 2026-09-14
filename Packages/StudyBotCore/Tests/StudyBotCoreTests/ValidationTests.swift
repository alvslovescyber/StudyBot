import Foundation
import StudyBotCore
import Testing

@Suite("Validation")
struct ValidationTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("a well-formed assignment is valid and a blank title is not")
    func assignment() {
        let good = Assignment(sync: .new(at: now), title: "Coursework 1", wordLimit: 2500, weighting: 40)
        #expect(good.isValid)

        let bad = Assignment(
            sync: .new(at: now), title: "   ", wordLimit: 0, weighting: 140, grade: -1, targetGrade: 101)
        let fields = Set(bad.validationIssues().map(\.field))
        #expect(fields == ["title", "wordLimit", "weighting", "grade", "targetGrade"])
    }

    @Test("validate() throws one error carrying every issue")
    func throwsAllIssues() {
        let bad = Assignment(sync: .new(at: now), title: "", targetGrade: 200)
        #expect(throws: ValidationError.self) { try bad.validate() }
        do {
            try bad.validate()
        } catch {
            #expect(error.issues.count == 2)
        }
    }

    @Test("a year-spanning module has no term; a termed module needs 1–3")
    func module() {
        let pd = Module(
            sync: .new(at: now), name: "Professional Development 1", code: "COM1017DA",
            colour: .indigo, year: 1, termNumber: nil, spansYear: true)
        #expect(pd.isValid)
        let contradictory = Module(
            sync: .new(at: now), name: "PD", code: "COM1017DA", colour: .indigo, year: 1, termNumber: 2,
            spansYear: true)
        #expect(contradictory.validationIssues().map(\.field) == ["termNumber"])
        let outOfRange = Module(
            sync: .new(at: now), name: "X", code: "COM9999DA", colour: .indigo, year: 4, termNumber: 5)
        #expect(Set(outOfRange.validationIssues().map(\.field)) == ["year", "termNumber"])
    }

    @Test("off-the-job hours must be positive and no more than a day")
    func otjHours() {
        func entry(_ hours: Double) -> OTJEntry {
            OTJEntry(sync: .new(at: now), date: now, hours: hours, category: .lecture, description: "")
        }
        #expect(entry(3).isValid)
        #expect(!entry(0).isValid)
        #expect(!entry(-1).isValid)
        #expect(!entry(25).isValid)
        #expect(entry(24).isValid)
    }

    @Test("settings defaults are valid and duplicate export positions are caught")
    func settings() {
        var settings = Settings.defaults(at: now)
        #expect(settings.isValid)
        settings.otjExportMapping = [
            ExportColumn(header: "A", field: .date, order: 0),
            ExportColumn(header: "B", field: .hours, order: 0),
        ]
        #expect(settings.validationIssues().map(\.field) == ["otjExportMapping"])
        settings = Settings.defaults(at: now)
        settings.targetOTJHoursPerWeek = 0
        settings.monthlyAIBudgetPence = -1
        #expect(
            Set(settings.validationIssues().map(\.field)) == [
                "targetOTJHoursPerWeek", "monthlyAIBudgetPence",
            ])
    }

    @Test("cards, KSBs and evidence need their text fields")
    func textFields() {
        #expect(!Card(sync: .new(at: now), deckID: UUID(), front: "", back: "b", dueDate: now).isValid)
        #expect(Card(sync: .new(at: now), deckID: UUID(), front: "f", back: "b", dueDate: now).isValid)
        #expect(!KSB(sync: .new(at: now), code: "", category: .skill, text: "t").isValid)
        #expect(!Evidence(sync: .new(at: now), title: "t", date: now, summary: " ", source: .lecture).isValid)
        #expect(
            Evidence(sync: .new(at: now), title: "t", date: now, summary: "did a thing", source: .lecture)
                .isValid)
    }

    @Test("a resolved proposal needs a resolution time; a pending one does not")
    func proposal() {
        let pending = Proposal(
            sync: .new(at: now), kind: .hoursEntry, source: .programmeCalendar, sourceRef: "s1",
            title: "Log Monday", payload: Data())
        #expect(pending.isValid)
        var confirmed = pending
        confirmed.state = .confirmed
        #expect(confirmed.validationIssues().map(\.field) == ["resolvedAt"])
        confirmed.resolvedAt = now
        #expect(confirmed.isValid)
    }
}
