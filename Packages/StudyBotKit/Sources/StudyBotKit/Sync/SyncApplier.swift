import Foundation
import StudyBotCore
import SwiftData

/// Applies a server response to a `ModelContext` (spec §3.5 "The response is authoritative and
/// the client overwrites local state with it"), with the one exception §3.4 demands: a local
/// edit that has not been pushed yet is compared with `SyncMerge`, and if it loses it is
/// archived as a `ConflictLoser` before being replaced. Nothing here saves; `Database` wraps
/// a whole response in one save so an interruption leaves either all of it or none.
struct SyncApplier {
    let context: ModelContext
    let now: Date

    /// Acknowledgements for pushed records. `pushed` supplies the `updatedAt` each was pushed
    /// with, so an edit made during the push keeps the record dirty.
    func acknowledge(_ accepted: [SyncAccepted], pushed: [SyncRecord]) throws {
        let pushedByID = Dictionary(pushed.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for acceptance in accepted {
            guard let record = pushedByID[acceptance.id],
                let operations = ModelRegistry.wireOperationsByType[record.type]
            else { continue }
            try operations.acknowledge(
                id: acceptance.id, version: acceptance.version, seq: acceptance.seq,
                pushedUpdatedAt: record.updatedAt, in: context)
        }
    }

    /// Applies `changes`. `conflicts` name the pushes the server refused, so the local losers
    /// can carry the server's archive id.
    func apply(changes: [SyncRecord], conflicts: [SyncConflict], into summary: inout SyncApplication) throws {
        let archiveIDs = Dictionary(
            conflicts.map { ($0.id, $0.archivedAs) }, uniquingKeysWith: { first, _ in first })
        for change in changes {
            guard let operations = ModelRegistry.wireOperationsByType[change.type] else {
                summary.unknownTypes.insert(change.type)
                continue
            }
            if let local = try operations.metadata(id: change.id, in: context), local.dirty {
                if SyncMerge.localEditWins(local: local, over: change) {
                    summary.keptLocal += 1
                    continue
                }
                if let losing = try operations.wireRecord(id: change.id, in: context) {
                    try archive(losing, replacedBy: change, serverArchiveID: archiveIDs[change.id])
                    summary.losersArchived += 1
                }
            }
            try operations.replace(with: change, in: context)
            summary.applied += 1
        }
    }

    /// Keeps the losing version whole, and for a session's notes also as a `NoteRevision`
    /// so the note itself can say "An older version of this note was replaced."
    private func archive(_ losing: SyncRecord, replacedBy change: SyncRecord, serverArchiveID: String?) throws
    {
        let loser = ConflictLoser(
            record: losing, archivedAt: now, replacedByVersion: change.version ?? 0,
            serverArchiveID: serverArchiveID)
        context.insert(try ConflictLoserModel(value: loser))
        if losing.type == Session.recordType, let notes = losing.fields["liveNotes"]?.stringValue,
            !notes.isEmpty
        {
            context.insert(
                NoteRevisionModel(
                    value: NoteRevision(
                        sessionID: losing.id, body: notes, capturedAt: now, reason: .conflictLoser)))
        }
    }

    /// Moves the cursor. A server cursor behind ours means the server was restored from a
    /// backup: every local record is marked dirty so the next push offers them all back.
    func advanceCursor(to serverCursor: Int, state: inout SyncState, summary: inout SyncApplication) throws {
        if serverCursor < state.cursor {
            for operations in ModelRegistry.allWireOperations {
                try operations.markAllDirty(in: context)
            }
            summary.cursorRegressed = true
        }
        state.cursor = serverCursor
        summary.cursor = serverCursor
    }
}
