import Foundation
import StudyBotKit
import Testing

/// The calendar files exist twice: once in the repo root (the spec's home for them)
/// and once inside the packages (so the app bundles one and the tests read the other).
/// These tests fail the build if either copy drifts from the root.
@Suite("Fixture integrity")
struct FixtureIntegrityTests {
    private static var repoRoot: URL {
        // Tests/StudyBotKitTests/FixtureIntegrityTests.swift → four levels up is Packages/StudyBotKit,
        // two more is the repo root.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // StudyBotKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // StudyBotKit
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    @Test("the bundled ICS is byte-identical to the one in the repo root")
    func bundledICSMatchesRoot() throws {
        let bundled = try BundledProgrammeCalendar.data()
        let root = try Data(
            contentsOf: Self.repoRoot.appendingPathComponent(BundledProgrammeCalendar.fileName))
        #expect(bundled == root)
        #expect(!bundled.isEmpty)
    }

    @Test("the JSON fixture is byte-identical to programme-calendar.json in the repo root")
    func jsonFixtureMatchesRoot() throws {
        let fixture = try TestFixtures.programmeCalendarJSON()
        let root = try Data(contentsOf: Self.repoRoot.appendingPathComponent("programme-calendar.json"))
        #expect(fixture == root)
    }
}
