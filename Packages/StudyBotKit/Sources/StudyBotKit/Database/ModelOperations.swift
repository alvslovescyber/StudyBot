import Foundation
import StudyBotCore
import SwiftData

/// The store operations for one Core record type, erased over which `@Model` class backs it.
/// `Database` looks these up by Core type so its public API mentions only Core types.
protocol RecordOperations<Value>: Sendable {
    associatedtype Value: Persistable

    func fetch(id: UUID, in context: ModelContext) throws -> StoredRecord<Value>?
    func fetchAll(includeDeleted: Bool, in context: ModelContext) throws -> [StoredRecord<Value>]
    func fetchDirty(in context: ModelContext) throws -> [StoredRecord<Value>]
    func count(includeDeleted: Bool, in context: ModelContext) throws -> Int
    /// Inserts or updates the row. When `unknownFields` is nil the row's existing unknown
    /// fields are kept; pass a value (even `[:]`) to replace them.
    func upsert(_ value: Value, unknownFields: [String: JSONValue]?, in context: ModelContext) throws
    /// Removes the row entirely. Only for purging tombstones and for tests; deletion in the
    /// app is a tombstone via `SyncMetadata.markDeleted`.
    func purge(id: UUID, in context: ModelContext) throws
}

/// `RecordOperations` for a concrete `SyncRecordModel`.
struct ModelOperations<Model: SyncRecordModel>: RecordOperations {
    typealias Value = Model.Value

    private func row(id: UUID, in context: ModelContext) throws -> Model? {
        var descriptor = FetchDescriptor<Model>(predicate: Model.predicate(id: id))
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetch(id: UUID, in context: ModelContext) throws -> StoredRecord<Value>? {
        try row(id: id, in: context)?.storedRecord()
    }

    func fetchAll(includeDeleted: Bool, in context: ModelContext) throws -> [StoredRecord<Value>] {
        let descriptor = FetchDescriptor<Model>(predicate: includeDeleted ? nil : Model.livePredicate)
        return try context.fetch(descriptor).map { try $0.storedRecord() }
    }

    func fetchDirty(in context: ModelContext) throws -> [StoredRecord<Value>] {
        let descriptor = FetchDescriptor<Model>(predicate: Model.dirtyPredicate)
        return try context.fetch(descriptor).map { try $0.storedRecord() }
    }

    func count(includeDeleted: Bool, in context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<Model>(predicate: includeDeleted ? nil : Model.livePredicate)
        return try context.fetchCount(descriptor)
    }

    func upsert(_ value: Value, unknownFields: [String: JSONValue]?, in context: ModelContext) throws {
        if let existing = try row(id: value.id, in: context) {
            let kept = try unknownFields.map(RecordCoding.encodeUnknownFields) ?? existing.unknownFields
            try existing.update(value: value, unknownFields: kept)
        } else {
            let fresh = try Model(
                value: value, unknownFields: try RecordCoding.encodeUnknownFields(unknownFields ?? [:]))
            context.insert(fresh)
        }
    }

    func purge(id: UUID, in context: ModelContext) throws {
        if let existing = try row(id: id, in: context) {
            context.delete(existing)
        }
    }
}

/// Core type → operations. The only place that knows which model backs which value.
enum ModelRegistry {
    private static let operations: [ObjectIdentifier: any Sendable] = [
        ObjectIdentifier(Module.self): ModelOperations<ModuleModel>(),
        ObjectIdentifier(Term.self): ModelOperations<TermModel>(),
        ObjectIdentifier(Assignment.self): ModelOperations<AssignmentModel>(),
        ObjectIdentifier(Session.self): ModelOperations<SessionModel>(),
        ObjectIdentifier(Deck.self): ModelOperations<DeckModel>(),
        ObjectIdentifier(Card.self): ModelOperations<CardModel>(),
        ObjectIdentifier(QuizAttempt.self): ModelOperations<QuizAttemptModel>(),
        ObjectIdentifier(KSB.self): ModelOperations<KSBModel>(),
        ObjectIdentifier(Evidence.self): ModelOperations<EvidenceModel>(),
        ObjectIdentifier(OTJEntry.self): ModelOperations<OTJEntryModel>(),
        ObjectIdentifier(Proposal.self): ModelOperations<ProposalModel>(),
        ObjectIdentifier(Settings.self): ModelOperations<SettingsModel>(),
        ObjectIdentifier(Attachment.self): ModelOperations<AttachmentModel>(),
        ObjectIdentifier(AIRun.self): ModelOperations<AIRunModel>(),
    ]

    static func operations<T: Persistable>(for type: T.Type) throws -> any RecordOperations<T> {
        guard let ops = operations[ObjectIdentifier(type)] as? any RecordOperations<T> else {
            throw Database.Error.unregisteredType(T.recordType)
        }
        return ops
    }
}
