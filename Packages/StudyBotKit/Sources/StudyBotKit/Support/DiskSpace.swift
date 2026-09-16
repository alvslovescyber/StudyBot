import Foundation

/// Running out of disk is a first-class failure (§16 Reliability). This is the one place that
/// knows what "full" looks like: how much room is left on the store's volume, which errors
/// mean the disk is full, and the words the user sees.
public enum DiskSpace {
    public enum Level: Hashable, Sendable {
        case ok
        /// Under 2 GB: warn once in Today.
        case low
        /// Under 500 MB: warn persistently.
        case critical
    }

    public static let lowThreshold: Int64 = 2_000_000_000
    public static let criticalThreshold: Int64 = 500_000_000

    /// Free bytes on the volume holding `url`, as the system would let an app use them.
    public static func freeBytes(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    public static func level(freeBytes: Int64) -> Level {
        if freeBytes < criticalThreshold { return .critical }
        if freeBytes < lowThreshold { return .low }
        return .ok
    }

    /// Whether an error means the volume is full: Cocoa's out-of-space code, POSIX `ENOSPC`,
    /// or SQLite's "database or disk is full" surfacing through SwiftData.
    public static func isOutOfSpace(_ error: any Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == CocoaError.fileWriteOutOfSpace.rawValue {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC) { return true }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError, underlying !== nsError,
            isOutOfSpace(underlying)
        {
            return true
        }
        let text = "\(error) \(nsError.localizedDescription)".lowercased()
        return text.contains("disk is full") || text.contains("sqlite_full") || text.contains("no space left")
    }

    /// §16's wording. `subject` is what could not be saved: "This note", "This assignment".
    public static func saveFailureMessage(for error: any Error, subject: String) -> String {
        if isOutOfSpace(error) {
            return "\(subject) could not be saved. Your disk is full."
        }
        return "\(subject) could not be saved. \(error.localizedDescription)"
    }

    /// "1.8 GB", "420 MB".
    public static func describe(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: bytes)
    }
}
