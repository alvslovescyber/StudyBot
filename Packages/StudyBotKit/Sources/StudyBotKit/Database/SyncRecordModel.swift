import Foundation
import StudyBotCore
import SwiftData

/// What every persisted syncable model provides, so `Database` can be written once and work
/// for all fourteen record types.
///
/// Each model row holds: the eight sync fields as real columns (queryable, and persisted in
/// full even though nothing reads `seq` or `baseVersion` yet), a `body` blob with the whole
/// Core value, an `unknownFields` blob for fields from a newer build, and a few index columns
/// specific to the type. The body is the record; the columns are derived from it on every
/// write. That keeps the struct-to-model conversion trivial and means adding a field to a
/// Core struct needs no SwiftData migration.
protocol SyncRecordModel: PersistentModel {
    associatedtype Value: Persistable

    init(value: Value, unknownFields: Data?) throws

    var id: UUID { get }
    var dirty: Bool { get }
    var deletedAt: Date? { get }
    var body: Data { get }
    var unknownFields: Data? { get }

    /// Rewrites every column and the body from `value`.
    func update(value: Value, unknownFields: Data?) throws

    static func predicate(id: UUID) -> Predicate<Self>
    static var dirtyPredicate: Predicate<Self> { get }
    static var livePredicate: Predicate<Self> { get }
}

extension SyncRecordModel {
    /// The Core value this row holds, with its unknown fields.
    func storedRecord() throws -> StoredRecord<Value> {
        StoredRecord(
            try RecordCoding.decode(Value.self, from: body),
            unknownFields: try RecordCoding.decodeUnknownFields(unknownFields))
    }
}
