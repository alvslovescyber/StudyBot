import Foundation
import StudyBotCore
import Testing

@Suite("Models")
struct ModelTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: encoder.encode(value))
    }

    @Test("every syncable model has a distinct wire recordType")
    func recordTypesAreDistinct() {
        let types = [
            Module.recordType, Term.recordType, Assignment.recordType, Session.recordType,
            Deck.recordType, Card.recordType, QuizAttempt.recordType, KSB.recordType,
            Evidence.recordType, OTJEntry.recordType, Proposal.recordType, Settings.recordType,
            Attachment.recordType, AIRun.recordType,
        ]
        #expect(Set(types).count == types.count)
    }

    @Test("an assignment round-trips through Codable with its subtasks and overrides")
    func assignmentRoundTrip() throws {
        let assignment = Assignment(
            sync: .new(at: now),
            title: "Programming coursework 1",
            moduleID: Module.stableID(forCode: "COM1018DA"),
            status: .drafting,
            priority: .high,
            dueDate: now,
            wordLimit: 2500,
            weighting: 40,
            fieldOverrides: ["dueDate"],
            subtasks: [Subtask(title: "Read the brief", order: 0, createdBy: .workBackPlan)],
            programmeEventID: ProgrammeEvent.stableID(forSourceUID: "uid")
        )
        let decoded = try roundTrip(assignment)
        #expect(decoded == assignment)
        #expect(decoded.id == assignment.sync.id)
        #expect(decoded.isIncomplete)
    }

    @Test("a calendar stub is recognised until a brief, rubric or hand edit arrives")
    func calendarStub() {
        var stub = Assignment(
            sync: .new(at: now), title: "Programming", dueDate: now,
            programmeEventID: ProgrammeEvent.stableID(forSourceUID: "uid"))
        #expect(stub.isCalendarStub)
        stub.fieldOverrides.insert("title")
        #expect(!stub.isCalendarStub)
    }

    @Test("Module.shortCode gives initials or a four-letter stem, never empty")
    func moduleShortCode() {
        func module(_ name: String, code: String = "COM1018DA") -> Module {
            Module(sync: .new(at: now), name: name, code: code, colour: .indigo, year: 1, termNumber: 1)
        }
        #expect(module("Programming").shortCode == "PROG")
        #expect(module("Discrete Mathematics for Computer Science").shortCode == "DMCS")
        #expect(module("Object-Oriented Programming").shortCode == "OOP")
        #expect(module("Professional Development 1").shortCode == "PD")
        #expect(module("Computers and the Internet").shortCode == "CI")
        #expect(module("COM3105DA", code: "COM3105DA").shortCode == "COM3", "a bare code stub stays short")
        #expect(module("", code: "COM3105DA").shortCode == "3105DA")
    }

    @Test("Module.year(fromCode:) reads the year digit and rejects malformed codes")
    func moduleYearFromCode() {
        #expect(Module.year(fromCode: "COM1018DA") == 1)
        #expect(Module.year(fromCode: "COM2022DA") == 2)
        #expect(Module.year(fromCode: "COM3104DA") == 3)
        #expect(Module.year(fromCode: "COM4104DA") == nil)
        #expect(Module.year(fromCode: "XYZ1018DA") == nil)
        #expect(Module.year(fromCode: "COM") == nil)
    }

    @Test("module and term ids are stable and derived from code or year/number")
    func stableModelIDs() {
        #expect(Module.stableID(forCode: "COM1018DA") == Module.stableID(forCode: "COM1018DA"))
        #expect(Module.stableID(forCode: "COM1018DA") != Module.stableID(forCode: "COM1014DA"))
        #expect(Term.stableID(year: 1, number: 2) == Term.stableID(year: 1, number: 2))
        #expect(Term.stableID(year: 1, number: 2) != Term.stableID(year: 2, number: 1))
        let event = ProgrammeEvent(
            startDate: now, endDate: now, kind: .online, title: "Online lectures",
            moduleCodes: [], sourceUID: "abc@programme.calendar", lastImportedAt: now)
        #expect(event.id == ProgrammeEvent.stableID(forSourceUID: "abc@programme.calendar"))
    }

    @Test("grade bands default to 70/60/50/40 and band(for:) picks the highest reached")
    func gradeBands() {
        #expect(GradeBand.defaults.map(\.minimum) == [70, 60, 50, 40])
        #expect(GradeBand.band(for: 74, in: GradeBand.defaults)?.label == "Distinction")
        #expect(GradeBand.band(for: 70, in: GradeBand.defaults)?.label == "Distinction")
        #expect(GradeBand.band(for: 69.9, in: GradeBand.defaults)?.label == "Merit")
        #expect(GradeBand.band(for: 55, in: GradeBand.defaults)?.label == "Pass")
        #expect(GradeBand.band(for: 45, in: GradeBand.defaults)?.label == "Threshold")
        #expect(GradeBand.band(for: 39, in: GradeBand.defaults) == nil)
    }

    @Test("KSB coverage honours the explicit strong mark only when evidence exists")
    func ksbCoverage() {
        let sync = SyncMetadata.new(at: now)
        let plain = KSB(sync: sync, code: "K3", category: .knowledge, text: "…")
        #expect(plain.coverage(evidenceCount: 0) == .none)
        #expect(plain.coverage(evidenceCount: 2) == .partial)
        #expect(plain.coverage(evidenceCount: 3) == .strong)
        let marked = KSB(sync: sync, code: "S1", category: .skill, text: "…", markedStrong: true)
        #expect(marked.coverage(evidenceCount: 1) == .strong)
        #expect(marked.coverage(evidenceCount: 0) == .none)
    }

    @Test("card boxes clamp to 1–5 and map to the Leitner intervals")
    func cardBoxes() {
        let deckID = UUID()
        #expect(Card.intervals == [1, 3, 7, 16, 35])
        #expect(
            Card(sync: .new(at: now), deckID: deckID, front: "f", back: "b", box: 0, dueDate: now).box == 1)
        #expect(
            Card(sync: .new(at: now), deckID: deckID, front: "f", back: "b", box: 9, dueDate: now).box == 5)
        #expect(
            Card(sync: .new(at: now), deckID: deckID, front: "f", back: "b", box: 4, dueDate: now)
                .intervalDays == 16)
    }

    @Test("work-sourced evidence is confidential by default and can be overridden")
    func evidenceConfidentiality() {
        let work = Evidence(
            sync: .new(at: now), title: "Sprint", date: now, summary: "…", source: .workProject)
        #expect(work.isWorkConfidential)
        let lecture = Evidence(sync: .new(at: now), title: "Sets", date: now, summary: "…", source: .lecture)
        #expect(!lecture.isWorkConfidential)
        let overridden = Evidence(
            sync: .new(at: now), title: "Public talk", date: now, summary: "…",
            source: .workProject, isWorkConfidential: false)
        #expect(!overridden.isWorkConfidential)
    }

    @Test("Settings defaults match §4 and share one fixed id on every device")
    func settingsDefaults() throws {
        let settings = Settings.defaults(at: now)
        #expect(settings.id == Settings.singletonID)
        #expect(settings.targetOTJHoursPerWeek == 6)
        #expect(settings.gradeBands == GradeBand.defaults)
        #expect(settings.monthlyAIBudgetPence == 800)
        #expect(settings.notificationPrefs == .allOff)
        #expect(settings.notificationPrefs.morningPlanTime == WallClockTime(hour: 7))
        #expect(settings.assignmentListScope == .currentTerm)
        #expect(try roundTrip(settings) == settings)
    }

    @Test("a proposal's uniqueness key is (source, sourceRef, kind)")
    func proposalKey() {
        let a = Proposal(
            sync: .new(at: now), kind: .dateChange, source: .ele2, sourceRef: "42",
            title: "Move", payload: Data())
        let b = Proposal(
            sync: .new(at: now), kind: .dateChange, source: .ele2, sourceRef: "42",
            title: "Different title, same upstream item", payload: Data([1]))
        let c = Proposal(
            sync: .new(at: now), kind: .newAssignment, source: .ele2, sourceRef: "42",
            title: "Move", payload: Data())
        #expect(a.key == b.key)
        #expect(a.key != c.key)
    }

    @Test("WallClockTime clamps and orders by minutes since midnight")
    func wallClockTime() {
        #expect(WallClockTime(hour: 25, minute: 70) == WallClockTime(hour: 23, minute: 59))
        #expect(WallClockTime(hour: -1) == WallClockTime(hour: 0))
        #expect(WallClockTime(hour: 7) < WallClockTime(hour: 18))
        #expect(WallClockTime(hour: 18).minutesSinceMidnight == 1080)
    }

    @Test("a programme event and a session round-trip through Codable")
    func eventAndSessionRoundTrip() throws {
        let event = ProgrammeEvent(
            startDate: now, endDate: now.addingTimeInterval(86_400), kind: .onCampus,
            title: "On-campus", moduleCodes: ["COM1018DA", "COM1014DA"],
            sourceUID: "uid@programme.calendar", lastImportedAt: now)
        #expect(try roundTrip(event) == event)
        #expect(event.isMultiDay)
        #expect(!event.isCancelled)

        let session = Session(
            sync: .new(at: now), title: "Sets and relations", programmeEventID: event.id,
            date: now, liveNotes: "- normalisation\nASK: does 3NF matter", openQuestions: ["does 3NF matter"])
        #expect(try roundTrip(session) == session)
        #expect(session.hasNotes)
        #expect(!Session(sync: .new(at: now), title: "Empty", date: now, liveNotes: "  \n").hasNotes)
    }
}
