import Foundation
import Observation
import StudyBotCore

/// Off-the-job hours (§6.5, Today): the entries, this week's bar, and one-line logging. A
/// logged line lands in `entries` before the write completes, so the week bar grows at once;
/// if the write fails the entry comes back out and `lastError` says why.
@MainActor
@Observable
public final class HoursStore {
    public private(set) var entries: [OTJEntry] = []
    /// Default 6 (§6.5); the real requirement is confirmed at induction.
    public private(set) var targetPerWeek: Double = 6
    public private(set) var lastError: String?
    public var didWrite: (@MainActor () -> Void)?

    private let store: any RecordStore
    private let deviceID: String
    private let now: @Sendable () -> Date

    public init(store: any RecordStore, deviceID: String, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.deviceID = deviceID
        self.now = now
    }

    public func load() async {
        do {
            entries = try await store.fetchAll(OTJEntry.self, includeDeleted: false).map(\.value)
                .sorted { ($0.date, $0.sync.createdAt) > ($1.date, $1.sync.createdAt) }
            if let settings = try await store.fetchAll(Settings.self, includeDeleted: false).first?.value {
                targetPerWeek = settings.targetOTJHoursPerWeek
            }
            lastError = nil
        } catch {
            lastError = "Couldn't read the hours: \(error.localizedDescription)"
        }
    }

    // MARK: The week

    public struct DayHours: Identifiable, Hashable, Sendable {
        public let day: LocalDay
        public let hours: Double
        public var id: LocalDay { day }
    }

    /// Monday to Sunday of one week, with the target.
    public struct Week: Hashable, Sendable {
        public let days: [DayHours]
        public let target: Double
        public var total: Double { days.reduce(0) { $0 + $1.hours } }
        public var start: LocalDay { days.first?.day ?? LocalDay(year: 1970, month: 1, day: 1) }
    }

    public func week(containing day: LocalDay) -> Week {
        let monday = day.adding(days: -(day.isoWeekday - 1))
        let days = (0..<7).map { offset -> DayHours in
            let date = monday.adding(days: offset)
            return DayHours(day: date, hours: hours(on: date))
        }
        return Week(days: days, target: targetPerWeek)
    }

    public func hours(on day: LocalDay) -> Double {
        entries.filter { LocalDay($0.date) == day }.reduce(0) { $0 + $1.hours }
    }

    // MARK: Logging

    /// Logs one typed line for `day` (today by default). Returns nil with `lastError` set when
    /// the line has no duration or the write fails; in the failure case the entry, which was
    /// already showing, is removed again.
    @discardableResult
    public func log(_ line: String, on day: LocalDay? = nil) async -> OTJEntry? {
        guard let parsed = HoursLine.parse(line) else {
            lastError = HoursLine.hint
            return nil
        }
        let entry = OTJEntry(
            sync: .new(at: now(), deviceID: deviceID), date: (day ?? LocalDay(now())).date, hours: parsed.hours,
            category: parsed.category, description: parsed.description)
        do {
            try entry.validate()
        } catch let error as ValidationError {
            lastError = error.issues.map(\.message).joined(separator: ". ")
            return nil
        } catch {
            lastError = error.localizedDescription
            return nil
        }
        // Optimistic: the bar grows now, before the write.
        entries.insert(entry, at: 0)
        lastError = nil
        do {
            try await store.saveAll([entry])
            didWrite?()
            return entry
        } catch {
            entries.removeAll { $0.id == entry.id }
            lastError = DiskSpace.saveFailureMessage(for: error, subject: "The hours")
            return nil
        }
    }

    public func delete(_ id: UUID) async {
        guard var entry = entries.first(where: { $0.id == id }) else { return }
        entry.sync.markDeleted(at: now(), by: deviceID)
        do {
            try await store.saveAll([entry])
            entries.removeAll { $0.id == id }
            didWrite?()
        } catch {
            lastError = "Couldn't delete: \(error.localizedDescription)"
        }
    }
}
