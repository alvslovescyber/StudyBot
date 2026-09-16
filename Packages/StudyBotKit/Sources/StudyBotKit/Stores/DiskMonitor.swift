import Foundation
import Observation

/// Watches free space on the store's volume (§16 Reliability): on launch and hourly. Under
/// 2 GB Today warns once; under 500 MB the warning stays until there is room again.
@MainActor
@Observable
public final class DiskMonitor {
    public private(set) var freeBytes: Int64?
    public private(set) var level: DiskSpace.Level = .ok
    /// The user dismissed the once-only low warning.
    public private(set) var lowWarningDismissed = false

    private let storeURL: URL
    private let freeSpace: @Sendable (URL) -> Int64?
    private let interval: Duration
    private var timer: Task<Void, Never>?

    public init(
        storeURL: URL, freeSpace: @escaping @Sendable (URL) -> Int64? = DiskSpace.freeBytes(at:),
        interval: Duration = .seconds(3_600)
    ) {
        self.storeURL = storeURL
        self.freeSpace = freeSpace
        self.interval = interval
    }

    /// Reads free space now.
    public func check() {
        freeBytes = freeSpace(storeURL)
        let newLevel = freeBytes.map(DiskSpace.level(freeBytes:)) ?? .ok
        if newLevel == .ok { lowWarningDismissed = false }
        level = newLevel
    }

    /// Launch check plus the hourly one.
    public func start() {
        check()
        timer?.cancel()
        timer = Task { [weak self, interval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                self?.check()
            }
        }
    }

    public func stop() { timer?.cancel() }

    public func dismissLowWarning() { lowWarningDismissed = true }

    /// Whether notes may spend disk on a revision snapshot. Below critical they are skipped so
    /// a snapshot never takes the last of the room a note write needs (§16).
    public var snapshotsAllowed: Bool { level != .critical }

    /// The line Today shows, or nil.
    public var todayNotice: String? {
        guard let freeBytes else { return nil }
        switch level {
        case .ok: return nil
        case .low:
            return lowWarningDismissed
                ? nil
                : "Your disk has \(DiskSpace.describe(freeBytes)) free. StudyBot needs room to save notes."
        case .critical:
            return "Your disk has \(DiskSpace.describe(freeBytes)) free. Notes may not save. Free space now."
        }
    }

    /// Whether the notice can be dismissed (low) or stays (critical).
    public var noticeIsDismissible: Bool { level == .low }
}
