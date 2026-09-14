import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// The real programme calendar, read once per test process. Every Kit suite that needs
/// "the 156 events" goes through here.
enum RealCalendar {
    static let importedAt = Date(timeIntervalSince1970: 1_790_000_000)

    static func events() throws -> [ProgrammeEvent] {
        let reading = try ICSProgrammeCalendarReader.read(
            try BundledProgrammeCalendar.data(), importedAt: importedAt)
        try #require(reading.issues.isEmpty)
        return reading.events
    }

    static func day(_ year: Int, _ month: Int, _ day: Int) -> LocalDay {
        LocalDay(year: year, month: month, day: day)
    }
}
