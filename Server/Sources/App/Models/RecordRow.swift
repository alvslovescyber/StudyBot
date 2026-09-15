import Fluent
import Foundation
import StudyBotCore
import Vapor

/// The authoritative copy of one synced record: `ServerRecordState` as a table row. Dates are
/// seconds since 1970 as doubles so a millisecond `updatedAt` round-trips exactly; equality on
/// it is what recognises a replayed push.
final class RecordRow: Model, @unchecked Sendable {
    static let schema = "records"

    @ID(custom: "id", generatedBy: .user) var id: UUID?
    @Field(key: "record_type") var recordType: String
    @Field(key: "version") var version: Int
    @Field(key: "seq") var seq: Int
    @Field(key: "updated_at") var updatedAt: Double
    @OptionalField(key: "deleted_at") var deletedAt: Double?
    @Field(key: "device_id") var deviceID: String
    /// The whole field set as JSON text.
    @Field(key: "fields") var fields: String
    /// `conflict_archive` id of the version this one overrode by last-write-wins, if any.
    @OptionalField(key: "replaced_archive_id") var replacedArchiveID: String?

    init() {}

    init(state: ServerRecordState) throws {
        id = state.id
        try apply(state)
    }

    func apply(_ state: ServerRecordState) throws {
        recordType = state.type
        version = state.version
        seq = state.seq
        updatedAt = state.updatedAt.timeIntervalSince1970
        deletedAt = state.deletedAt?.timeIntervalSince1970
        deviceID = state.deviceID
        fields = try JSONText.encode(state.fields)
        replacedArchiveID = state.replacedArchiveID
    }

    func state() throws -> ServerRecordState {
        ServerRecordState(
            type: recordType, id: id ?? UUID(), version: version, seq: seq,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            deletedAt: deletedAt.map(Date.init(timeIntervalSince1970:)), deviceID: deviceID,
            fields: try JSONText.decode([String: JSONValue].self, from: fields),
            replacedArchiveID: replacedArchiveID)
    }
}

/// JSON as text columns, through the one wire configuration.
enum JSONText {
    static func encode<T: Encodable>(_ value: T) throws -> String {
        guard let text = String(data: try SyncCoding.encode(value), encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "Record fields were not valid UTF-8.")
        }
        return text
    }

    static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        try SyncCoding.decode(type, from: Data(text.utf8))
    }
}
