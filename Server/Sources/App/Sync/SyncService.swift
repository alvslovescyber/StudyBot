import Fluent
import Foundation
import StudyBotCore
import Vapor

/// The server's half of §3.4 and §3.5, on a Fluent database. Every push is one transaction:
/// all of its records land with their `seq`s, or none do. The decision per record is
/// `SyncMerge.decide`, shared with the client and the in-memory test server.
struct SyncService {
    let db: any Database
    let now: Date

    // MARK: Push

    func push(_ request: SyncPushRequest) async throws -> SyncPushResponse {
        try SchemaGuard.check(request.schemaVersion)
        return try await db.transaction { db in
            let service = SyncService(db: db, now: now)
            var accepted: [SyncAccepted] = []
            var conflicts: [SyncConflict] = []
            var mustInclude: [UUID] = []
            var nextSeq = try await service.headSeq() + 1

            for incoming in request.records {
                let row = try await RecordRow.find(incoming.id, on: db)
                let existing = try row?.state()
                let writer = SyncMerge.writer(of: incoming, pushedBy: request.deviceID)
                switch SyncMerge.decide(incoming: incoming, from: request.deviceID, against: existing) {
                case .accept(let replacing):
                    let archivedAs = try await replacing.asyncMap { try await service.archive($0.wireRecord) }
                    let stored = try await service.store(
                        Write(incoming: incoming, writer: writer, seq: nextSeq, replacing: archivedAs),
                        over: existing, row: row)
                    nextSeq += 1
                    accepted.append(
                        SyncAccepted(
                            id: stored.id, version: stored.version, seq: stored.seq, archivedAs: archivedAs))
                case .reject:
                    guard let existing else { continue }
                    let archivedAs = try await service.archive(incoming.withWriter(writer))
                    conflicts.append(
                        SyncConflict(id: incoming.id, serverVersion: existing.version, archivedAs: archivedAs)
                    )
                    mustInclude.append(incoming.id)
                case .alreadyApplied:
                    guard let existing else { continue }
                    accepted.append(
                        SyncAccepted(id: existing.id, version: existing.version, seq: existing.seq))
                }
            }
            let page = try await service.changes(
                since: request.cursor, limit: SyncPullResponse.pageSize, alwaysIncluding: mustInclude)
            return SyncPushResponse(
                cursor: page.cursor, accepted: accepted, conflicts: conflicts, changes: page.changes,
                hasMore: page.hasMore)
        }
    }

    // MARK: Pull

    func pull(since: Int, limit: Int) async throws -> SyncPullResponse {
        let page = try await changes(
            since: since, limit: min(max(limit, 1), SyncPullResponse.pageSize), alwaysIncluding: [])
        return SyncPullResponse(cursor: page.cursor, changes: page.changes, hasMore: page.hasMore)
    }

    func archived(_ archiveID: String) async throws -> ArchivedRecord? {
        guard let rowID = ConflictArchiveRow.rowID(from: archiveID) else { return nil }
        return try await ConflictArchiveRow.find(rowID, on: db)?.archivedRecord()
    }

    // MARK: Maintenance

    /// Removes tombstones older than 90 days (§3.4). `sync_log` keeps their seqs.
    func purgeTombstones(olderThan days: Int = 90) async throws -> Int {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400).timeIntervalSince1970
        let stale = try await RecordRow.query(on: db).filter(\.$deletedAt != nil).filter(
            \.$deletedAt < cutoff
        ).all()
        for row in stale {
            try await row.delete(on: db)
        }
        return stale.count
    }

    // MARK: Internals

    /// The highest `seq` ever assigned, from the log, which is never purged.
    func headSeq() async throws -> Int {
        try await SyncLogRow.query(on: db).max(\.$id) ?? 0
    }

    /// An accepted write about to be stored.
    private struct Write {
        let incoming: SyncRecord
        let writer: String
        let seq: Int
        /// Archive id of the concurrent version this write overrides, if any.
        let replacing: String?
    }

    /// Merges the pushed fields into what the server holds (absent keys unchanged, null
    /// clears), assigns the next version, writes the row and the log entry.
    private func store(_ write: Write, over existing: ServerRecordState?, row: RecordRow?) async throws
        -> ServerRecordState
    {
        var fields = existing?.fields ?? [:]
        for (key, value) in write.incoming.fields {
            if value.isNull { fields.removeValue(forKey: key) } else { fields[key] = value }
        }
        let state = ServerRecordState(
            type: write.incoming.type, id: write.incoming.id, version: (existing?.version ?? 0) + 1,
            seq: write.seq,
            updatedAt: write.incoming.updatedAt, deletedAt: write.incoming.deletedAt, deviceID: write.writer,
            fields: fields, replacedArchiveID: write.replacing)
        if let row {
            try row.apply(state)
            try await row.save(on: db)
        } else {
            try await RecordRow(state: state).create(on: db)
        }
        try await SyncLogRow(
            seq: write.seq, recordID: state.id, recordType: state.type, deviceID: write.writer, at: now
        ).create(on: db)
        return state
    }

    private func archive(_ losing: SyncRecord) async throws -> String {
        let row = try ConflictArchiveRow(losing: losing, archivedAt: now)
        try await row.create(on: db)
        return row.archiveID
    }

    private struct Page {
        let cursor: Int
        let changes: [SyncRecord]
        let hasMore: Bool
    }

    /// Records with `seq > since`, oldest first, capped at `limit`, plus any the caller insists
    /// on (the server's version of a conflicted record). The cursor for an empty page is
    /// `min(since, head)`, so a client ahead of a restored server notices.
    private func changes(since: Int, limit: Int, alwaysIncluding: [UUID]) async throws -> Page {
        let rows = try await RecordRow.query(on: db).filter(\.$seq > since).sort(\.$seq).limit(limit + 1)
            .all()
        let hasMore = rows.count > limit
        var page = try rows.prefix(limit).map { try $0.state() }
        let included = Set(page.map(\.id))
        for id in alwaysIncluding where !included.contains(id) {
            if let state = try await RecordRow.find(id, on: db)?.state() {
                page.insert(state, at: 0)
            }
        }
        let head = try await headSeq()
        let cursor = page.filter { $0.seq > since }.map(\.seq).max() ?? min(since, head)
        return Page(cursor: cursor, changes: page.map(\.wireRecord), hasMore: hasMore)
    }
}

/// §3.10a: the server accepts its own schema version and one behind; older is a 409.
enum SchemaGuard {
    static func check(_ clientVersion: Int) throws {
        guard SyncSchema.accepts(clientVersion) else {
            throw SchemaRefusedError(
                refusal: SyncRefusal(
                    requiredVersion: SyncSchema.oldestAccepted, serverVersion: SyncSchema.current))
        }
    }
}

/// Carries the `SyncRefusal` body out of the service so the route can answer 409 with it.
struct SchemaRefusedError: Error {
    let refusal: SyncRefusal
}

extension SyncRecord {
    func withWriter(_ deviceID: String) -> SyncRecord {
        var copy = self
        copy.deviceID = deviceID
        return copy
    }
}

extension Optional {
    /// `map` for an async, throwing transform.
    func asyncMap<T>(_ transform: (Wrapped) async throws -> T) async throws -> T? {
        guard let value = self else { return nil }
        return try await transform(value)
    }
}
