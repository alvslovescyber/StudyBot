import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("ICSProgrammeCalendarReader — §3.12 row 1, parsing")
struct ICSProgrammeCalendarReaderTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func readRealFile() throws -> ICSProgrammeCalendarReader.Reading {
        try ICSProgrammeCalendarReader.read(try BundledProgrammeCalendar.data(), importedAt: now)
    }

    @Test("the real calendar produces 156 events and no issues")
    func realFileCount() throws {
        let reading = try readRealFile()
        #expect(reading.issues.isEmpty, "\(reading.issues)")
        #expect(reading.events.count == 156)
        #expect(Set(reading.events.map(\.sourceUID)).count == 156)
        #expect(Set(reading.events.map(\.id)).count == 156)
    }

    @Test("per-kind counts match the §4A table")
    func kindCounts() throws {
        let events = try readRealFile().events
        var counts: [EventKind: Int] = [:]
        for event in events { counts[event.kind, default: 0] += 1 }
        #expect(counts[.online] == 87)
        #expect(counts[.assignment] == 30)
        #expect(counts[.bankHoliday] == 21)
        #expect(counts[.onCampus] == 8)
        #expect(counts[.readingWeek] == 5)
        #expect(counts[.closure] == 2)
        #expect(counts[.induction] == 1)
        #expect(counts[.gateway] == 1)
        #expect(counts[.epa] == 1)
    }

    @Test("all-day DTEND is exclusive: Block 1 runs 23–24 September, not 23–25")
    func exclusiveEnd() throws {
        let events = try readRealFile().events
        let block1 = try #require(
            events.first { $0.sourceUID == "dtsl6-2026-on-campus-2026-09-23@programme.calendar" })
        #expect(LocalDay(block1.startDate) == LocalDay(year: 2026, month: 9, day: 23))
        #expect(LocalDay(block1.endDate) == LocalDay(year: 2026, month: 9, day: 24))
        #expect(block1.isMultiDay)

        let induction = try #require(events.first { $0.kind == .induction })
        #expect(LocalDay(induction.startDate) == LocalDay(year: 2026, month: 9, day: 22))
        #expect(LocalDay(induction.endDate) == LocalDay(year: 2026, month: 9, day: 22))
        #expect(!induction.isMultiDay)

        let epa = try #require(events.first { $0.kind == .epa })
        #expect(LocalDay(epa.startDate) == LocalDay(year: 2029, month: 7, day: 16))
        #expect(LocalDay(epa.endDate) == LocalDay(year: 2029, month: 7, day: 27))
    }

    @Test("every event's dates and kind match programme-calendar.json")
    func matchesParsedTwin() throws {
        let events = try readRealFile().events
        let fixture = try ProgrammeCalendarFixture.load()
        #expect(fixture.count == 156)

        let ours = Set(
            events.map { Triple(start: LocalDay($0.startDate), end: LocalDay($0.endDate), kind: $0.kind) })
        let theirs = Set(
            try fixture.map { Triple(start: $0.start, end: $0.end, kind: try #require($0.eventKind)) })
        #expect(ours == theirs)
        #expect(ours.count == 156)
    }

    @Test("titles lose the 'DTS L6: ' prefix and keep the university's wording")
    func titles() throws {
        let events = try readRealFile().events
        let titles = Set(events.map(\.title))
        #expect(
            titles == [
                "Induction",
                "On-campus (face-to-face) lectures/workshops/exams",
                "Online lectures",
                "Online workshops",
                "Assignment submission - MANDATORY (via ELE2)",
                "Reading Week",
                "University closure - no teaching",
                "Bank Holiday",
                "Gateway",
                "Planned End Point Assessment (EPA) window",
            ])
    }

    @Test("module codes are extracted by pattern, including the year-3 specialism list")
    func moduleCodes() throws {
        let events = try readRealFile().events
        let induction = try #require(events.first { $0.kind == .induction })
        #expect(induction.moduleCodes == ["COM1018DA", "COM1014DA", "COM1017DA"])

        let block7 = try #require(
            events.first { $0.sourceUID == "dtsl6-2026-on-campus-2028-09-18@programme.calendar" })
        #expect(
            block7.moduleCodes == [
                "COM3105DA", "COM3107DA", "COM3109DA", "COM3111DA", "COM3113DA", "COM3103DA",
            ])

        let block8 = try #require(
            events.first { $0.sourceUID == "dtsl6-2026-on-campus-2029-01-08@programme.calendar" })
        #expect(block8.moduleCodes.contains("COM3104DA"))
        #expect(block8.moduleCodes.count == 7)

        for event in events where event.kind == .bankHoliday || event.kind == .closure {
            #expect(event.moduleCodes.isEmpty)
        }
        #expect(events.filter { $0.kind == .assignment && $0.moduleCodes.isEmpty }.count == 10)

        // 7 year-1 + 7 year-2 + 10 specialism options + PD3 + Synoptic Project.
        let allCodes = Set(events.flatMap(\.moduleCodes))
        #expect(allCodes.count == 26)
    }

    @Test("the year-1 deadlines are the ten dates in §4A")
    func yearOneDeadlines() throws {
        let events = try readRealFile().events
        let deadlines =
            events
            .filter {
                $0.kind == .assignment && LocalDay($0.startDate) < LocalDay(year: 2027, month: 9, day: 1)
            }
            .map { LocalDay($0.startDate).isoString }
        #expect(
            deadlines == [
                "2026-10-15", "2026-12-03", "2026-12-17", "2027-03-18", "2027-04-01",
                "2027-07-01", "2027-07-08", "2027-07-13", "2027-07-15", "2027-07-20",
            ])
    }

    @Test("a hand-built event with no DTEND is one day; a DATE-TIME start still yields a day")
    func fragments() throws {
        let reading = try ICSProgrammeCalendarReader.read(
            Data(
                """
                BEGIN:VCALENDAR
                BEGIN:VEVENT
                UID:a
                DTSTART;VALUE=DATE:20261015
                SUMMARY:DTS L6: Assignment submission - MANDATORY (via ELE2)
                CATEGORIES:DTS L6 Assignment
                END:VEVENT
                BEGIN:VEVENT
                UID:b
                DTSTART:20261225T000000Z
                DTEND:20261226T000000Z
                SUMMARY:Bank Holiday
                END:VEVENT
                END:VCALENDAR
                """.utf8), importedAt: now)
        #expect(reading.issues.isEmpty)
        let a = try #require(reading.events.first { $0.sourceUID == "a" })
        #expect(LocalDay(a.startDate) == LocalDay(a.endDate))
        #expect(a.kind == .assignment)
        #expect(a.title == "Assignment submission - MANDATORY (via ELE2)")
        let b = try #require(reading.events.first { $0.sourceUID == "b" })
        #expect(b.kind == .bankHoliday, "kind falls back to the SUMMARY when CATEGORIES is absent")
        #expect(LocalDay(b.startDate) == LocalDay(year: 2026, month: 12, day: 25))
        #expect(LocalDay(b.endDate) == LocalDay(year: 2026, month: 12, day: 25))
    }

    @Test("a broken event is reported as an issue and the rest still import")
    func issuesDoNotAbort() throws {
        let reading = try ICSProgrammeCalendarReader.read(
            Data(
                """
                BEGIN:VCALENDAR
                BEGIN:VEVENT
                DTSTART;VALUE=DATE:20261015
                CATEGORIES:DTS L6 Assignment
                END:VEVENT
                BEGIN:VEVENT
                UID:no-start
                CATEGORIES:DTS L6 Assignment
                END:VEVENT
                BEGIN:VEVENT
                UID:bad-date
                DTSTART;VALUE=DATE:20261301
                CATEGORIES:DTS L6 Assignment
                END:VEVENT
                BEGIN:VEVENT
                UID:backwards
                DTSTART;VALUE=DATE:20261015
                DTEND;VALUE=DATE:20261010
                CATEGORIES:DTS L6 Assignment
                END:VEVENT
                BEGIN:VEVENT
                UID:mystery
                DTSTART;VALUE=DATE:20261015
                CATEGORIES:Something else
                SUMMARY:Picnic
                END:VEVENT
                BEGIN:VEVENT
                UID:fine
                DTSTART;VALUE=DATE:20261015
                DTEND;VALUE=DATE:20261016
                CATEGORIES:DTS L6 Online
                END:VEVENT
                END:VCALENDAR
                """.utf8), importedAt: now)
        #expect(reading.events.map(\.sourceUID) == ["fine"])
        #expect(
            reading.issues.map(\.reason) == [
                .missingUID,
                .missingStart,
                .unparseableDate("20261301"),
                .endBeforeStart,
                .unknownKind(categories: "Something else", summary: "Picnic"),
            ])
    }
}

private struct Triple: Hashable {
    let start: LocalDay
    let end: LocalDay
    let kind: EventKind
}
