import Foundation
import StudyBotCore
import SwiftData

/// The store operations the sync engine needs, erased over the record type so it can walk
/// every table without knowing any of them. `ModelOperations` provides them for each model.
protocol WireRecordOperations: Sendable {
    var recordType: String { get }

    /// Every dirty record as it would be pushed: full known fields (nil optionals as `null`),
    /// unknown fields, `baseVersion`, `updatedAt`, `deletedAt`. Tombstones included.
    func dirtyWireRecords(in context: ModelContext) throws -> [SyncRecord]

    /// The record's sync metadata, or nil if the store has never seen the id.
    func metadata(id: UUID, in context: ModelContext) throws -> SyncMetadata?

    /// The record as it stands locally, as a wire record, for archiving before it is replaced.
    func wireRecord(id: UUID, in context: ModelContext) throws -> SyncRecord?

    /// Replaces the local record with the server's version: every field from the wire, unknown
    /// fields replaced, sync metadata taken from the change, not dirty.
    func replace(with change: SyncRecord, in context: ModelContext) throws

    /// Applies the server's acknowledgement of a push. If the record was edited after the
    /// pushed `updatedAt`, it stays dirty but takes the new version as its base.
    func acknowledge(id: UUID, version: Int, seq: Int, pushedUpdatedAt: Date, in context: ModelContext) throws

    /// Marks every record dirty, for reconciling with a server restored from a backup.
    func markAllDirty(in context: ModelContext) throws

    /// Every row, tombstones included, as exported records with sync metadata verbatim.
    func exportAll(in context: ModelContext) throws -> [ExportedRecord]

    /// Writes an exported record back, sync metadata and unknown fields intact.
    func importRecord(_ record: ExportedRecord, in context: ModelContext) throws
}

extension ModelOperations: WireRecordOperations {
    var recordType: String { Value.recordType }

    func dirtyWireRecords(in context: ModelContext) throws -> [SyncRecord] {
        try fetchDirty(in: context).map { record in
            SyncRecord(
                type: Value.recordType, id: record.id, baseVersion: record.value.sync.baseVersion,
                updatedAt: record.value.sync.updatedAt, deletedAt: record.value.sync.deletedAt,
                fields: try RecordFields.fields(of: record),
                deviceID: record.value.sync.deviceID.isEmpty ? nil : record.value.sync.deviceID)
        }
    }

    func metadata(id: UUID, in context: ModelContext) throws -> SyncMetadata? {
        try fetch(id: id, in: context)?.value.sync
    }

    func wireRecord(id: UUID, in context: ModelContext) throws -> SyncRecord? {
        guard let record = try fetch(id: id, in: context) else { return nil }
        let sync = record.value.sync
        return SyncRecord(
            type: Value.recordType, id: id, baseVersion: sync.baseVersion, updatedAt: sync.updatedAt,
            deletedAt: sync.deletedAt, fields: try RecordFields.fields(of: record), version: sync.version,
            seq: sync.seq, deviceID: sync.deviceID)
    }

    func replace(with change: SyncRecord, in context: ModelContext) throws {
        let existing = try fetch(id: change.id, in: context)
        let version = change.version ?? 0
        let sync = SyncMetadata(
            id: change.id, createdAt: existing?.value.sync.createdAt ?? change.updatedAt,
            updatedAt: change.updatedAt, version: version, baseVersion: version, seq: change.seq ?? 0,
            deletedAt: change.deletedAt, dirty: false, deviceID: change.deviceID ?? "")
        let record = try RecordFields.record(Value.self, fields: change.fields, sync: sync)
        try upsert(record.value, unknownFields: record.unknownFields, in: context)
    }

    func acknowledge(id: UUID, version: Int, seq: Int, pushedUpdatedAt: Date, in context: ModelContext) throws
    {
        guard var record = try fetch(id: id, in: context) else { return }
        let editedSincePush = record.value.sync.updatedAt != pushedUpdatedAt
        record.value.sync.version = version
        record.value.sync.baseVersion = version
        record.value.sync.seq = seq
        record.value.sync.dirty = editedSincePush
        try upsert(record.value, unknownFields: nil, in: context)
    }

    func markAllDirty(in context: ModelContext) throws {
        for var record in try fetchAll(includeDeleted: true, in: context) where !record.value.sync.dirty {
            record.value.sync.dirty = true
            try upsert(record.value, unknownFields: nil, in: context)
        }
    }

    func exportAll(in context: ModelContext) throws -> [ExportedRecord] {
        try fetchAll(includeDeleted: true, in: context).map { record in
            ExportedRecord(
                type: Value.recordType, sync: record.value.sync, fields: try RecordFields.fields(of: record))
        }
    }

    func importRecord(_ record: ExportedRecord, in context: ModelContext) throws {
        let stored = try RecordFields.record(Value.self, fields: record.fields, sync: record.sync)
        try upsert(stored.value, unknownFields: stored.unknownFields, in: context)
    }
}

extension ModelRegistry {
    /// Every syncable table, in a fixed order.
    static var allWireOperations: [any WireRecordOperations] {
        wireOperationsByType.keys.sorted().compactMap { wireOperationsByType[$0] }
    }

    /// Wire type name → operations.
    static let wireOperationsByType: [String: any WireRecordOperations] = {
        let all: [any WireRecordOperations] = [
            ModelOperations<ModuleModel>(), ModelOperations<TermModel>(), ModelOperations<AssignmentModel>(),
            ModelOperations<SessionModel>(), ModelOperations<DeckModel>(), ModelOperations<CardModel>(),
            ModelOperations<QuizAttemptModel>(), ModelOperations<KSBModel>(),
            ModelOperations<EvidenceModel>(),
            ModelOperations<OTJEntryModel>(), ModelOperations<ProposalModel>(),
            ModelOperations<SettingsModel>(),
            ModelOperations<AttachmentModel>(), ModelOperations<AIRunModel>(),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.recordType, $0) })
    }()
}
