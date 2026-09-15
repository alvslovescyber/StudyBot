import Foundation
import StudyBotCore

/// A record as the store holds it: the typed value this build understands, plus any fields
/// it does not.
///
/// This is where §3.10a's rule lives at the storage layer. A record written by a newer build
/// may carry fields this build has never heard of. They are kept here, saved beside the
/// value, and put back on the wire unchanged. Saving a bare value never discards them: the
/// store keeps whatever unknown fields the row already had.
public struct StoredRecord<Value: Syncable>: Sendable, Hashable {
    public var value: Value
    /// Fields from a newer schema, keyed by wire field name. Empty for records this build wrote.
    public var unknownFields: [String: JSONValue]

    public init(_ value: Value, unknownFields: [String: JSONValue] = [:]) {
        self.value = value
        self.unknownFields = unknownFields
    }

    /// The record's stable id.
    public var id: UUID { value.id }
}
