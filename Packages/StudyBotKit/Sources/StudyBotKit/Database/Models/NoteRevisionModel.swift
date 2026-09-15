import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `NoteRevision`. Local-only, never synced (§4): independent insurance
    /// against both the sync engine and the app.
    @Model
    final class NoteRevisionModel {
        @Attribute(.unique) var id: UUID
        var sessionID: UUID
        var capturedAt: Date
        var reason: String
        var body: String

        init(value: NoteRevision) {
            id = value.id
            sessionID = value.sessionID
            capturedAt = value.capturedAt
            reason = value.reason.rawValue
            body = value.body
        }

        func value() throws -> NoteRevision {
            guard let reason = RevisionReason(rawValue: reason) else {
                throw Database.Error.corruptRow(
                    type: "noteRevision", id: id, detail: "unknown reason \(reason)")
            }
            return NoteRevision(
                id: id, sessionID: sessionID, body: body, capturedAt: capturedAt, reason: reason)
        }
    }
}
