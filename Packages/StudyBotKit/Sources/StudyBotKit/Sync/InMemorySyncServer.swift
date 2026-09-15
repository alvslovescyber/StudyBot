import Foundation
import StudyBotCore

/// A complete sync server in memory: the same rules as the Vapor server, without the network
/// or SQLite. It runs `SyncMerge.decide` for every pushed record, keeps a `conflict_archive`,
/// assigns `seq` and `version`, paginates pulls, refuses a client more than one schema
/// version behind, and can be snapshotted and restored to play a server recovered from a
/// backup. The two-client data-safety tests run against this.
public actor InMemorySyncServer: SyncTransport {
    /// The whole server state, for snapshot and restore.
    public struct Snapshot: Sendable {
        public let records: [UUID: ServerRecordState]
        public let archive: [String: ArchivedRecord]
        public let headSeq: Int
        public let archiveCount: Int
    }

    public var schemaVersion: Int
    /// Tokens the server accepts. Empty means "accept anything", for tests that are not about auth.
    public var validTokens: Set<String> = []
    public private(set) var pushCount = 0
    public private(set) var pullCount = 0

    private var records: [UUID: ServerRecordState] = [:]
    private var archive: [String: ArchivedRecord] = [:]
    private var headSeq = 0
    private var archiveCount = 0
    private let now: @Sendable () -> Date

    public init(schemaVersion: Int = SyncSchema.current, now: @escaping @Sendable () -> Date = { Date() }) {
        self.schemaVersion = schemaVersion
        self.now = now
    }

    // MARK: Inspection

    public var head: Int { headSeq }
    public func record(id: UUID) -> ServerRecordState? { records[id] }
    public var allRecords: [ServerRecordState] { records.values.sorted { $0.seq < $1.seq } }
    public func archived(_ id: String) -> ArchivedRecord? { archive[id] }
    public var archivedRecords: [ArchivedRecord] { archive.values.sorted { $0.id < $1.id } }

    public func snapshot() -> Snapshot {
        Snapshot(records: records, archive: archive, headSeq: headSeq, archiveCount: archiveCount)
    }

    /// Puts the server back to an earlier state, as a Litestream restore would (§3.11).
    public func restore(_ snapshot: Snapshot) {
        records = snapshot.records
        archive = snapshot.archive
        headSeq = snapshot.headSeq
        archiveCount = snapshot.archiveCount
    }

    public func allow(token: String) { validTokens.insert(token) }
    public func revoke(token: String) { validTokens.remove(token) }

    // MARK: Transport

    public func push(_ request: SyncPushRequest, token: String) async throws -> SyncPushResponse {
        try authorise(token)
        try checkSchema(request.schemaVersion)
        pushCount += 1
        var accepted: [SyncAccepted] = []
        var conflicts: [SyncConflict] = []
        var mustInclude: [UUID] = []
        for incoming in request.records {
            let existing = records[incoming.id]
            switch SyncMerge.decide(incoming: incoming, from: request.deviceID, against: existing) {
            case .accept(let replacing):
                let archivedAs = replacing.map { archiveRecord($0.wireRecord) }
                let stored = store(
                    incoming, from: SyncMerge.writer(of: incoming, pushedBy: request.deviceID), over: existing
                )
                accepted.append(
                    SyncAccepted(
                        id: stored.id, version: stored.version, seq: stored.seq, archivedAs: archivedAs))
            case .reject:
                guard let existing else { continue }
                let archivedAs = archiveRecord(
                    incoming.withWriter(SyncMerge.writer(of: incoming, pushedBy: request.deviceID)))
                conflicts.append(
                    SyncConflict(id: incoming.id, serverVersion: existing.version, archivedAs: archivedAs))
                mustInclude.append(incoming.id)
            case .alreadyApplied:
                guard let existing else { continue }
                accepted.append(SyncAccepted(id: existing.id, version: existing.version, seq: existing.seq))
            }
        }
        let page = changes(
            since: request.cursor, limit: SyncPullResponse.pageSize, alwaysIncluding: mustInclude)
        return SyncPushResponse(
            cursor: page.cursor, accepted: accepted, conflicts: conflicts, changes: page.changes,
            hasMore: page.hasMore)
    }

    public func pull(since: Int, limit: Int, schemaVersion: Int, token: String) async throws
        -> SyncPullResponse
    {
        try authorise(token)
        try checkSchema(schemaVersion)
        pullCount += 1
        let page = changes(since: since, limit: min(limit, SyncPullResponse.pageSize), alwaysIncluding: [])
        return SyncPullResponse(cursor: page.cursor, changes: page.changes, hasMore: page.hasMore)
    }

    // MARK: Rules

    private func authorise(_ token: String) throws {
        guard validTokens.isEmpty || validTokens.contains(token) else {
            throw SyncTransportError.unauthorised
        }
    }

    private func checkSchema(_ clientVersion: Int) throws {
        let oldest = max(1, schemaVersion - 1)
        guard clientVersion >= oldest && clientVersion <= schemaVersion else {
            throw SyncTransportError.schemaRefused(
                SyncRefusal(requiredVersion: oldest, serverVersion: schemaVersion))
        }
    }

    /// Merges the pushed fields into what the server holds (absent keys unchanged, null
    /// clears) and assigns the next version and seq.
    private func store(_ incoming: SyncRecord, from deviceID: String, over existing: ServerRecordState?)
        -> ServerRecordState
    {
        var fields = existing?.fields ?? [:]
        for (key, value) in incoming.fields {
            if value.isNull { fields.removeValue(forKey: key) } else { fields[key] = value }
        }
        headSeq += 1
        let stored = ServerRecordState(
            type: incoming.type, id: incoming.id, version: (existing?.version ?? 0) + 1, seq: headSeq,
            updatedAt: incoming.updatedAt, deletedAt: incoming.deletedAt, deviceID: deviceID, fields: fields)
        records[incoming.id] = stored
        return stored
    }

    private func archiveRecord(_ record: SyncRecord) -> String {
        archiveCount += 1
        let id = "c_\(archiveCount)"
        archive[id] = ArchivedRecord(id: id, record: record, archivedAt: now())
        return id
    }

    /// Records with `seq > since`, oldest first, capped at `limit`. The cursor is the last seq
    /// in the page, or `min(since, head)` for an empty page so a client ahead of a restored
    /// server sees the regression. Conflicted records are always included so the client can
    /// replace its losing version.
    private struct Page {
        let cursor: Int
        let changes: [SyncRecord]
        let hasMore: Bool
    }

    private func changes(since: Int, limit: Int, alwaysIncluding: [UUID]) -> Page {
        let newer = records.values.filter { $0.seq > since }.sorted { $0.seq < $1.seq }
        var page = Array(newer.prefix(limit))
        let hasMore = newer.count > limit
        let included = Set(page.map(\.id))
        for id in alwaysIncluding where !included.contains(id) {
            if let state = records[id] { page.insert(state, at: 0) }
        }
        let cursor = newer.prefix(limit).last?.seq ?? min(since, headSeq)
        return Page(cursor: cursor, changes: page.map(\.wireRecord), hasMore: hasMore)
    }
}

extension SyncRecord {
    /// The record with its writer filled in, for archiving a rejected push.
    func withWriter(_ deviceID: String) -> SyncRecord {
        var copy = self
        copy.deviceID = deviceID
        return copy
    }
}
