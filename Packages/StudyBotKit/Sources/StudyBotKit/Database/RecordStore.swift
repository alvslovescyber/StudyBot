import Foundation
import StudyBotCore

/// What the programme calendar import needs from a store. `Database` is the real one;
/// `InMemoryRecordStore` is for tests and previews. The importer itself never knows which.
public protocol RecordStore: Sendable {
    func programmeEvents(includeCancelled: Bool) async throws -> [ProgrammeEvent]
    func saveProgrammeEvents(_ events: [ProgrammeEvent]) async throws
    func fetchAll<T: Persistable>(_ type: T.Type, includeDeleted: Bool) async throws -> [StoredRecord<T>]
    func saveAll<T: Persistable>(_ values: [T]) async throws
}

extension Database: RecordStore {}

/// A `RecordStore` held in dictionaries. Keeps unknown fields the same way the real store
/// does, so tests of the import path can run without SwiftData.
public actor InMemoryRecordStore: RecordStore {
    private var events: [String: ProgrammeEvent] = [:]
    private var records: [ObjectIdentifier: [UUID: any Sendable]] = [:]

    public init() {}

    public func programmeEvents(includeCancelled: Bool) throws -> [ProgrammeEvent] {
        events.values
            .filter { includeCancelled || !$0.isCancelled }
            .sorted { ($0.startDate, $0.sourceUID) < ($1.startDate, $1.sourceUID) }
    }

    public func saveProgrammeEvents(_ incoming: [ProgrammeEvent]) {
        for event in incoming {
            events[event.sourceUID] = event
        }
    }

    public func fetchAll<T: Persistable>(_ type: T.Type, includeDeleted: Bool) throws -> [StoredRecord<T>] {
        (records[ObjectIdentifier(type)] ?? [:]).values
            .compactMap { $0 as? StoredRecord<T> }
            .filter { includeDeleted || !$0.value.sync.isDeleted }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    public func fetch<T: Persistable>(_ type: T.Type, id: UUID) -> StoredRecord<T>? {
        records[ObjectIdentifier(type)]?[id] as? StoredRecord<T>
    }

    /// Saves a value, keeping any unknown fields already stored for that id.
    public func saveAll<T: Persistable>(_ values: [T]) {
        for value in values {
            let existing = fetch(T.self, id: value.id)
            records[ObjectIdentifier(T.self), default: [:]][value.id] =
                StoredRecord(value, unknownFields: existing?.unknownFields ?? [:])
        }
    }

    public func save<T: Persistable>(_ record: StoredRecord<T>) {
        records[ObjectIdentifier(T.self), default: [:]][record.id] = record
    }
}
