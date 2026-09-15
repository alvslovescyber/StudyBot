import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV2 {
    /// Persisted form of `SyncState`: one row. The cursor is a column so it can be read at a
    /// glance in the file; the rest of the struct is the body.
    @Model
    final class SyncStateModel {
        @Attribute(.unique) var id: UUID
        var cursor: Int
        var body: Data

        init(value: SyncState) throws {
            id = SyncState.singletonID
            cursor = value.cursor
            body = try RecordCoding.encode(value)
        }

        func update(value: SyncState) throws {
            cursor = value.cursor
            body = try RecordCoding.encode(value)
        }

        func value() throws -> SyncState {
            try RecordCoding.decode(SyncState.self, from: body)
        }
    }
}
