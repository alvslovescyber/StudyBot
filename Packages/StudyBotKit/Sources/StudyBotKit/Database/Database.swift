import Foundation
import StudyBotCore
import SwiftData

/// The one owner of the `ModelContainer` (spec §3.3). Nothing else touches SwiftData, which
/// makes threading a non-question: every call runs on this actor's executor with its own
/// `ModelContext`, and every mutating call saves before it returns.
///
/// The public surface speaks only Core types and `StoredRecord`. The `@Model` classes are
/// internal to StudyBotKit and cannot appear in a signature outside it.
@ModelActor
public actor Database {
    /// Errors the store raises beyond what SwiftData throws.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// A Core type with no registered model. A programming error, not a runtime condition.
        case unregisteredType(String)
        /// A row whose stored body no longer decodes. Named so a corrupt store fails legibly.
        case corruptRow(type: String, id: UUID, detail: String)
    }

    // MARK: Opening

    /// Opens (or creates) the on-disk store at `url`, applying `StudyBotMigrationPlan`.
    public static func onDisk(at url: URL) throws -> Database {
        let configuration = ModelConfiguration(schema: Self.schema, url: url)
        return Database(modelContainer: try container(configuration))
    }

    /// An in-memory store that vanishes with the actor. For tests and previews.
    public static func inMemory() throws -> Database {
        let configuration = ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: true)
        return Database(modelContainer: try container(configuration))
    }

    static let schema = Schema(versionedSchema: StudyBotMigrationPlan.current)

    private static func container(_ configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: schema, migrationPlan: StudyBotMigrationPlan.self, configurations: [configuration])
    }

    // MARK: Syncable records

    /// The record with this id, including tombstoned ones, or nil.
    public func fetch<T: Persistable>(_ type: T.Type, id: UUID) throws -> StoredRecord<T>? {
        try ModelRegistry.operations(for: type).fetch(id: id, in: modelContext)
    }

    /// Every record of the type. Tombstones are excluded unless asked for.
    public func fetchAll<T: Persistable>(_ type: T.Type, includeDeleted: Bool = false) throws
        -> [StoredRecord<T>]
    {
        try ModelRegistry.operations(for: type).fetchAll(includeDeleted: includeDeleted, in: modelContext)
    }

    /// Records with local changes the server has not acknowledged, tombstones included.
    public func fetchDirty<T: Persistable>(_ type: T.Type) throws -> [StoredRecord<T>] {
        try ModelRegistry.operations(for: type).fetchDirty(in: modelContext)
    }

    /// How many records of the type exist. Tombstones are excluded unless asked for.
    public func count<T: Persistable>(_ type: T.Type, includeDeleted: Bool = false) throws -> Int {
        try ModelRegistry.operations(for: type).count(includeDeleted: includeDeleted, in: modelContext)
    }

    /// Inserts or updates a record, replacing its unknown fields with the ones given.
    public func save<T: Persistable>(_ record: StoredRecord<T>) throws {
        try ModelRegistry.operations(for: T.self)
            .upsert(record.value, unknownFields: record.unknownFields, in: modelContext)
        try modelContext.save()
    }

    /// Inserts or updates a record. **Unknown fields already on the row are kept.** This is the
    /// path an older build takes when it edits a record a newer build wrote, and it must not
    /// erase what it does not understand (§3.10a).
    public func save<T: Persistable>(_ value: T) throws {
        try ModelRegistry.operations(for: T.self).upsert(value, unknownFields: nil, in: modelContext)
        try modelContext.save()
    }

    /// Saves several records of one type in a single transaction.
    public func saveAll<T: Persistable>(_ values: [T]) throws {
        let operations = try ModelRegistry.operations(for: T.self)
        for value in values {
            try operations.upsert(value, unknownFields: nil, in: modelContext)
        }
        try modelContext.save()
    }

    /// Tombstones a record: sets `deletedAt`, bumps `updatedAt`, marks it dirty. The row stays
    /// until the server has propagated the deletion and the 90-day purge runs (§3.4).
    public func tombstone<T: Persistable>(_ type: T.Type, id: UUID, at now: Date) throws {
        guard var record = try fetch(type, id: id) else { return }
        record.value.sync.markDeleted(at: now)
        try save(record)
    }

    /// Removes a row entirely. For purging old tombstones and for tests. Not for the UI.
    public func purge<T: Persistable>(_ type: T.Type, id: UUID) throws {
        try ModelRegistry.operations(for: type).purge(id: id, in: modelContext)
        try modelContext.save()
    }

    // MARK: Programme events (never synced)

    /// Every programme event, cancelled ones included unless excluded, sorted by start date.
    public func programmeEvents(includeCancelled: Bool = true) throws -> [ProgrammeEvent] {
        var descriptor = FetchDescriptor<ProgrammeEventModel>(sortBy: [SortDescriptor(\.startDate)])
        if !includeCancelled {
            descriptor.predicate = #Predicate { $0.cancelledAt == nil }
        }
        return try modelContext.fetch(descriptor).map { try $0.value() }
    }

    /// The event with this ICS UID, if any.
    public func programmeEvent(sourceUID: String) throws -> ProgrammeEvent? {
        var descriptor = FetchDescriptor<ProgrammeEventModel>(
            predicate: #Predicate { $0.sourceUID == sourceUID })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.value()
    }

    /// Inserts or updates events by `sourceUID`, in one transaction. Ids are never changed.
    public func saveProgrammeEvents(_ events: [ProgrammeEvent]) throws {
        for event in events {
            let uid = event.sourceUID
            var descriptor = FetchDescriptor<ProgrammeEventModel>(
                predicate: #Predicate { $0.sourceUID == uid })
            descriptor.fetchLimit = 1
            if let existing = try modelContext.fetch(descriptor).first {
                try existing.update(value: event)
            } else {
                modelContext.insert(try ProgrammeEventModel(value: event))
            }
        }
        try modelContext.save()
    }

    // MARK: Note revisions (local only)

    /// Adds a revision and trims idle snapshots for the session to the last 20 (§4).
    public func addNoteRevision(_ revision: NoteRevision) throws {
        modelContext.insert(NoteRevisionModel(value: revision))
        let sessionID = revision.sessionID
        let idle = RevisionReason.idleSnapshot.rawValue
        let descriptor = FetchDescriptor<NoteRevisionModel>(
            predicate: #Predicate { $0.sessionID == sessionID && $0.reason == idle },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        let snapshots = try modelContext.fetch(descriptor)
        for stale in snapshots.dropFirst(NoteRevision.retainedPerSession) {
            modelContext.delete(stale)
        }
        try modelContext.save()
    }

    /// Revisions for a session, newest first.
    public func noteRevisions(for sessionID: UUID) throws -> [NoteRevision] {
        let descriptor = FetchDescriptor<NoteRevisionModel>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map { try $0.value() }
    }

    /// Removes conflict-loser revisions older than 30 days (§4).
    public func pruneConflictLosers(now: Date) throws {
        let cutoff = now.addingTimeInterval(-Double(NoteRevision.conflictLoserRetentionDays) * 86_400)
        let loser = RevisionReason.conflictLoser.rawValue
        try modelContext.delete(
            model: NoteRevisionModel.self,
            where: #Predicate { $0.reason == loser && $0.capturedAt < cutoff })
        try modelContext.save()
    }
}
