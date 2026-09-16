import Foundation

/// The weekly automatic export (§16 "Client backup"): due seven days after the last one,
/// twelve kept, oldest removed. Pure decisions over dates and folder names; `AppModel` runs it
/// on launch and hourly. A manual step after a tiring block gets skipped; this does not.
public enum ExportSchedule {
    public static let interval: TimeInterval = 7 * 86_400
    public static let retained = 12
    /// Automatic exports carry this suffix so manual ones are never pruned.
    public static let automaticSuffix = " (automatic)"

    public static func isDue(lastExportAt: Date?, now: Date) -> Bool {
        guard let lastExportAt else { return true }
        return now.timeIntervalSince(lastExportAt) >= interval
    }

    /// The automatic export folders in `parent`, oldest first.
    public static func automaticExports(in parent: URL) -> [URL] {
        let contents =
            (try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? []
        return contents.filter { $0.lastPathComponent.hasSuffix(automaticSuffix) }.sorted {
            $0.lastPathComponent < $1.lastPathComponent
        }
    }

    /// Removes automatic exports beyond the newest `retained`. Returns what was removed.
    @discardableResult
    public static func prune(in parent: URL, keep: Int = retained) -> [URL] {
        let all = automaticExports(in: parent)
        guard all.count > keep else { return [] }
        let stale = Array(all.prefix(all.count - keep))
        for url in stale {
            try? FileManager.default.removeItem(at: url)
        }
        return stale
    }
}
