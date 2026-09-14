import Foundation
import StudyBotCore
import Testing

/// One row of `programme-calendar.json`, the parsed twin of the real ICS. Its `end` is
/// inclusive, which is exactly what the importer must produce from the exclusive `DTEND`.
struct FixtureEvent: Decodable, Hashable {
    let start: LocalDay
    let end: LocalDay
    let kind: String
    let title: String
    let modules: [String]

    /// The `EventKind` the fixture's kind string denotes.
    var eventKind: EventKind? {
        switch kind {
        case "induction": .induction
        case "on-campus": .onCampus
        case "online": .online
        case "assignment": .assignment
        case "reading week": .readingWeek
        case "closure": .closure
        case "bank holiday": .bankHoliday
        case "gateway": .gateway
        case "epa": .epa
        default: nil
        }
    }
}

enum ProgrammeCalendarFixture {
    static func load() throws -> [FixtureEvent] {
        try JSONDecoder().decode([FixtureEvent].self, from: TestFixtures.programmeCalendarJSON())
    }
}
