import Foundation
import StudyBotKit
import Testing

@Suite("ExportSchedule — weekly, twelve kept")
struct ExportScheduleTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("due when never run, due after seven days, not before")
    func due() {
        #expect(ExportSchedule.isDue(lastExportAt: nil, now: t0))
        #expect(!ExportSchedule.isDue(lastExportAt: t0, now: t0.addingTimeInterval(6 * 86_400)))
        #expect(ExportSchedule.isDue(lastExportAt: t0, now: t0.addingTimeInterval(7 * 86_400)))
    }

    @Test("pruning keeps the newest twelve automatic exports and never touches a manual one")
    func prune() throws {
        let temp = try TemporaryStore()
        defer { temp.remove() }
        for index in 0..<14 {
            let name =
                "StudyBot export 2026-09-\(String(format: "%02d", index + 1)) 0900\(ExportSchedule.automaticSuffix)"
            try FileManager.default.createDirectory(
                at: temp.directory.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try FileManager.default.createDirectory(
            at: temp.directory.appendingPathComponent("StudyBot export 2026-09-01 0800"),
            withIntermediateDirectories: true)
        let removed = ExportSchedule.prune(in: temp.directory)
        #expect(
            removed.map(\.lastPathComponent) == [
                "StudyBot export 2026-09-01 0900 (automatic)", "StudyBot export 2026-09-02 0900 (automatic)",
            ])
        #expect(ExportSchedule.automaticExports(in: temp.directory).count == 12)
        #expect(
            FileManager.default.fileExists(
                atPath: temp.directory.appendingPathComponent("StudyBot export 2026-09-01 0800").path),
            "manual export kept")
    }
}
