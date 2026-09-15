import Foundation

/// A fresh directory for an on-disk store, removed when the test is done with it.
struct TemporaryStore {
    let directory: URL
    /// The store file. SwiftData adds `-wal` and `-shm` beside it.
    let url: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("studybot-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("studybot.store")
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
