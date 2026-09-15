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

    /// Applies a **partial** wire `fields` map to a stored record (§3.5: "fields is a partial —
    /// only what changed"). Fields absent from the partial are left exactly as stored, known or
    /// unknown. A field present with `null` clears a known optional or removes an unknown field.
    /// The record's sync metadata is not touched here; the caller applies the record-level
    /// `updatedAt`, `deletedAt`, `version` and `seq`.
    public static func applying<T: Persistable>(
        _ partial: [String: JSONValue], to record: StoredRecord<T>
    ) throws -> StoredRecord<T> {
        // Overlay the partial on the stored fields, then decode. The decoder ignores keys the
        // struct does not declare, so whatever it kept is known and the rest is unknown.
        var merged = try knownFields(of: record.value)
        var unknown = record.unknownFields
        for (key, value) in partial where key != syncKey {
            if value.isNull {
                merged.removeValue(forKey: key)
                unknown.removeValue(forKey: key)
            } else {
                merged[key] = value
            }
        }
        merged[syncKey] = try SyncCoding.decode(JSONValue.self, from: SyncCoding.encode(record.value.sync))
        let value = try SyncCoding.decode(T.self, from: SyncCoding.encode(merged))

        let known = Set(try knownFields(of: value).keys)
        for (key, jsonValue) in partial where !known.contains(key) && key != syncKey && !jsonValue.isNull {
            unknown[key] = jsonValue
        }
        for key in known {
            unknown.removeValue(forKey: key)
        }
        return StoredRecord(value, unknownFields: unknown)
    }
}
