import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `ProgrammeEvent`. Not syncable (§4), so no sync columns; matched on
    /// `sourceUID` by the importer and never hard-deleted, only cancelled.
    @Model
    final class ProgrammeEventModel {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var sourceUID: String
        var startDate: Date
        var endDate: Date
        var kind: String
        var cancelledAt: Date?
        var lastImportedAt: Date
        var termID: UUID?
        /// The whole `ProgrammeEvent`, encoded by `RecordCoding`.
        var body: Data

        init(value: ProgrammeEvent) throws {
            id = value.id
            sourceUID = value.sourceUID
            startDate = value.startDate
            endDate = value.endDate
            kind = value.kind.rawValue
            cancelledAt = value.cancelledAt
            lastImportedAt = value.lastImportedAt
            termID = value.termID
            body = try RecordCoding.encode(value)
        }

        func update(value: ProgrammeEvent) throws {
            startDate = value.startDate
            endDate = value.endDate
            kind = value.kind.rawValue
            cancelledAt = value.cancelledAt
            lastImportedAt = value.lastImportedAt
            termID = value.termID
            body = try RecordCoding.encode(value)
        }

        func value() throws -> ProgrammeEvent {
            try RecordCoding.decode(ProgrammeEvent.self, from: body)
        }
    }
}
