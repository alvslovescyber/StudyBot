import Foundation
import Observation
import StudyBotCore

/// Evidence capture (§6.5): four fields, thirty seconds, from anywhere. KSBs are free-text
/// codes until Exeter's list exists (§14).
@MainActor
@Observable
public final class EvidenceStore {
    public private(set) var items: [Evidence] = []
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
            items = try await store.fetchAll(Evidence.self, includeDeleted: false).map(\.value)
                .sorted { $0.date > $1.date }
            lastError = nil
        } catch {
            lastError = "Couldn't read the evidence: \(error.localizedDescription)"
        }
    }

    /// What the capture sheet collects.
    public struct Draft: Hashable, Sendable {
        public var title = ""
        public var date: Date
        public var summary = ""
        /// Comma- or space-separated KSB codes as typed: "K3 S12".
        public var ksbCodes = ""
        public var source: EvidenceSource = .workProject
        public var sessionID: UUID?

        public init(date: Date, source: EvidenceSource = .workProject, sessionID: UUID? = nil) {
            self.date = date
            self.source = source
            self.sessionID = sessionID
        }

        /// The codes, split, upper-cased and de-duplicated in order.
        public var codes: [String] {
            var seen = Set<String>()
            return ksbCodes.uppercased()
                .split(whereSeparator: { $0 == "," || $0.isWhitespace })
                .map(String.init)
                .filter { seen.insert($0).inserted }
        }
    }

    /// Creates the item. Returns nil, with `lastError` set, when the draft is not valid.
    @discardableResult
    public func create(_ draft: Draft) async -> Evidence? {
        let evidence = Evidence(
            sync: .new(at: now(), deviceID: deviceID),
            title: draft.title.trimmingCharacters(in: .whitespaces),
            date: UKCalendar.startOfDay(draft.date),
            summary: draft.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            source: draft.source, sessionID: draft.sessionID, pendingKSBCodes: draft.codes)
        do {
            try evidence.validate()
            try await store.saveAll([evidence])
            await load()
            didWrite?()
            return evidence
        } catch let error as ValidationError {
            lastError = error.issues.map(\.message).joined(separator: ". ")
        } catch {
            lastError = "Couldn't save the evidence: \(error.localizedDescription)"
        }
        return nil
    }

    public func delete(_ id: UUID) async {
        guard var item = items.first(where: { $0.id == id }) else { return }
        item.sync.markDeleted(at: now(), by: deviceID)
        do {
            try await store.saveAll([item])
            await load()
            didWrite?()
        } catch {
            lastError = "Couldn't delete: \(error.localizedDescription)"
        }
    }
}
