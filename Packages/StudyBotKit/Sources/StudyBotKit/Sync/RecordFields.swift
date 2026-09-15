import Foundation
import StudyBotCore

/// The seam between a `StoredRecord` and the wire's `fields` map (§3.5).
///
/// Going out: the value's fields plus whatever unknown fields the row carried, so a field
/// this build never understood is sent back exactly as it arrived. Coming in: the fields this
/// build's struct knows about become the value; the rest are kept as unknown. `SyncMetadata`
/// travels at the record level on the wire, never inside `fields`.
///
/// Milestone four's sync engine builds on this; it exists now so the storage round-trip test
/// exercises the real path a stale client would take.
public enum RecordFields {
    static let syncKey = "sync"

    /// The wire `fields` for a stored record: known fields merged with unknown ones. Unknown
    /// fields never overwrite a known key.
    public static func fields<T: Persistable>(of record: StoredRecord<T>) throws -> [String: JSONValue] {
        var fields = try knownFields(of: record.value)
        for (key, value) in record.unknownFields where fields[key] == nil {
            fields[key] = value
        }
        return fields
    }

    /// The fields of a value as JSON, without `sync`.
    static func knownFields<T: Persistable>(of value: T) throws -> [String: JSONValue] {
        var fields = try SyncCoding.decode([String: JSONValue].self, from: SyncCoding.encode(value))
        fields.removeValue(forKey: syncKey)
        return fields
    }

    /// Builds a stored record from wire fields and the record-level sync metadata. Fields the
    /// struct does not declare are kept as unknown. A field whose value is `null` is treated
    /// as an absent optional and not preserved, because nil and absent mean the same thing.
    public static func record<T: Persistable>(
        _ type: T.Type, fields: [String: JSONValue], sync: SyncMetadata
    ) throws -> StoredRecord<T> {
        var object = fields
        object[syncKey] = try SyncCoding.decode(JSONValue.self, from: SyncCoding.encode(sync))
        let value = try SyncCoding.decode(T.self, from: SyncCoding.encode(object))

        let known = Set(try knownFields(of: value).keys)
        var unknown: [String: JSONValue] = [:]
        for (key, jsonValue) in fields where !known.contains(key) && key != syncKey && !jsonValue.isNull {
            unknown[key] = jsonValue
        }
        return StoredRecord(value, unknownFields: unknown)
    }
}
