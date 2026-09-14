import Foundation
import Testing

/// Access to files under `Tests/StudyBotKitTests/Fixtures`.
enum TestFixtures {
    struct MissingFixture: Error {
        let name: String
    }

    static func url(_ name: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
        else {
            throw MissingFixture(name: name)
        }
        return url
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }

    /// `programme-calendar.json` — the parsed twin of the real ICS, for cross-checking the importer.
    static func programmeCalendarJSON() throws -> Data {
        try data("programme-calendar.json")
    }
}
