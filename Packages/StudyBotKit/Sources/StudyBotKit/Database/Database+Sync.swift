import Foundation
import StudyBotCore
import SwiftData

/// The store's side of the sync engine. Every method here is one transaction: a response is
/// applied whole or not at all, and the cursor moves in the same save as the records it
/// accounts for, so an interruption can never leave records without their cursor or a cursor
/// without its records (§3.12 "Interrupted mid-push leaves no partial state").
extension Database {
    // MARK: State

    public func syncState() throws -> SyncState {
        try syncStateRow()?.value() ?? SyncState()
    }

    public func saveSyncState(_ state: SyncState) throws {
        if let row = try syncStateRow() {
            try row.update(value: state)
        } else {
            modelContext.insert(try SyncStateModel(value: state))
        }
        try modelContext.save()
    }

    private func syncStateRow() throws -> SyncStateModel? {
        let id = SyncState.singletonID
        var descriptor = FetchDescriptor<SyncStateModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: Outgoing

    /// Every dirty record in every table, oldest edit first, as wire records.
    public func dirtyWireRecords() throws -> [SyncRecord] {
        try ModelRegistry.allWireOperations
            .flatMap { try $0.dirtyWireRecords(in: modelContext) }
            .sorted { ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString) }
    }

    /// Marks every record dirty. Used when reconciling with a restored server and by tests.
    public func markAllDirty() throws {
        for operations in ModelRegistry.allWireOperations {
            try operations.markAllDirty(in: modelContext)
        }
        try modelContext.save()
    }

    // MARK: Incoming

    /// Applies a push response: acknowledgements, then changes, then the cursor. One save.
    public func applyPushResponse(_ response: SyncPushResponse, pushed: [SyncRecord], now: Date) throws
        -> SyncApplication
    {
        var state = try syncState()
        var summary = SyncApplication(cursor: state.cursor)
        let applier = SyncApplier(context: modelContext, now: now)
        try applier.acknowledge(response.accepted, pushed: pushed)
        try applier.apply(changes: response.changes, conflicts: response.conflicts, into: &summary)
        try applier.advanceCursor(to: response.cursor, state: &state, summary: &summary)
        try writeSyncState(state)
        try modelContext.save()
        return summary
    }

    /// Applies a page of pulled changes and the cursor. One save.
    public func applyPullResponse(_ response: SyncPullResponse, now: Date) throws -> SyncApplication {
        var state = try syncState()
        var summary = SyncApplication(cursor: state.cursor)
        let applier = SyncApplier(context: modelContext, now: now)
        try applier.apply(changes: response.changes, conflicts: [], into: &summary)
        try applier.advanceCursor(to: response.cursor, state: &state, summary: &summary)
        try writeSyncState(state)
        try modelContext.save()
        return summary
    }

    private func writeSyncState(_ state: SyncState) throws {
        if let row = try syncStateRow() {
            try row.update(value: state)
        } else {
            modelContext.insert(try SyncStateModel(value: state))
        }
    }

    // MARK: Conflict losers

    /// Losing versions of one record, newest first.
    public func conflictLosers(for recordID: UUID) throws -> [ConflictLoser] {
        let descriptor = FetchDescriptor<ConflictLoserModel>(
            predicate: #Predicate { $0.recordID == recordID },
            sortBy: [SortDescriptor(\.archivedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map { try $0.value() }
    }

    /// Every loser kept locally, newest first.
    public func allConflictLosers() throws -> [ConflictLoser] {
        let descriptor = FetchDescriptor<ConflictLoserModel>(
            sortBy: [SortDescriptor(\.archivedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map { try $0.value() }
    }

    /// Removes losers older than 30 days (§3.4), and the note revisions kept for the same reason.
    public func pruneConflictLoserRecords(now: Date) throws {
        let cutoff = now.addingTimeInterval(-Double(ConflictLoser.retentionDays) * 86_400)
        try modelContext.delete(model: ConflictLoserModel.self, where: #Predicate { $0.archivedAt < cutoff })
        try modelContext.save()
        try pruneConflictLosers(now: now)
    }
}
