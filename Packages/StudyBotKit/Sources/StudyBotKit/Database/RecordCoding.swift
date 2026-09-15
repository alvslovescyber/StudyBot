import Foundation
import StudyBotCore

/// JSON coding for record bodies inside the store. Distinct from `SyncCoding` (the wire):
/// dates are stored as seconds since 1970 so a round trip through the store is lossless to
/// sub-second precision, which the wire's second-precision ISO 8601 is not.
enum RecordCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    /// Unknown fields are stored as a JSON object, or nil when there are none, so a row
    /// written by this build has no blob to carry.
    static func encodeUnknownFields(_ fields: [String: JSONValue]) throws -> Data? {
        fields.isEmpty ? nil : try encoder.encode(fields)
    }

    static func decodeUnknownFields(_ data: Data?) throws -> [String: JSONValue] {
        guard let data else { return [:] }
        return try decoder.decode([String: JSONValue].self, from: data)
    }
}
