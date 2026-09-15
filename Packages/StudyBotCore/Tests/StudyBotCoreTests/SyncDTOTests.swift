import Foundation
import StudyBotCore
import Testing

@Suite("Sync DTOs match the §3.5 wire shape")
struct SyncDTOTests {
    /// The worked example from §3.5, verbatim apart from full UUIDs.
    static let pushExample = """
        {
          "schemaVersion": 1,
          "deviceID": "1F0C0000-0000-4000-8000-000000000001",
          "cursor": 4821,
          "records": [
            { "type": "assignment", "id": "9A3F0000-0000-4000-8000-000000000002", "baseVersion": 7,
              "updatedAt": "2026-10-02T19:44:10Z", "deletedAt": null,
              "fields": { "title": "Programming coursework 1", "status": "drafting",
                          "dueDate": "2026-10-15", "fieldOverrides": ["dueDate"] } }
          ]
        }
        """

    static let responseExample = """
        {
          "cursor": 4839,
          "accepted": [ { "id": "9A3F0000-0000-4000-8000-000000000002", "version": 8, "seq": 4839 } ],
          "conflicts": [ { "id": "2B710000-0000-4000-8000-000000000003", "serverVersion": 12,
                           "resolution": "serverWins", "archivedAs": "c_5512" } ],
          "changes": [
            { "type": "session", "id": "7C000000-0000-4000-8000-000000000004", "baseVersion": 2,
              "version": 3, "seq": 4839, "updatedAt": "2026-10-02T19:40:00Z", "deletedAt": null,
              "fields": { "liveNotes": "- normalisation", "brandNewField": {"x": 1} } }
          ],
          "hasMore": false
        }
        """

    @Test("the spec's push example decodes field for field")
    func decodesPushExample() throws {
        let request = try SyncCoding.decode(SyncPushRequest.self, from: Data(Self.pushExample.utf8))
        #expect(request.schemaVersion == 1)
        #expect(request.cursor == 4821)
        #expect(request.records.count == 1)
        let record = try #require(request.records.first)
        #expect(record.type == "assignment")
        #expect(record.baseVersion == 7)
        #expect(record.deletedAt == nil)
        #expect(record.version == nil)
        #expect(record.fields["title"] == "Programming coursework 1")
        #expect(record.fields["status"] == "drafting")
        #expect(record.fields["dueDate"] == "2026-10-15")
        #expect(record.fields["fieldOverrides"] == ["dueDate"])
        #expect(record.updatedAt == Date(timeIntervalSince1970: 1_790_970_250))
    }

    @Test("the spec's response example decodes, including an unknown field in changes")
    func decodesResponseExample() throws {
        let response = try SyncCoding.decode(SyncPushResponse.self, from: Data(Self.responseExample.utf8))
        #expect(response.cursor == 4839)
        #expect(
            response.accepted == [
                SyncAccepted(
                    id: try #require(UUID(uuidString: "9A3F0000-0000-4000-8000-000000000002")), version: 8,
                    seq: 4839)
            ])
        let conflict = try #require(response.conflicts.first)
        #expect(conflict.serverVersion == 12)
        #expect(conflict.resolution == .serverWins)
        #expect(conflict.archivedAs == "c_5512")
        let change = try #require(response.changes.first)
        #expect(change.version == 3)
        #expect(change.seq == 4839)
        #expect(change.fields["brandNewField"] == ["x": 1])
        #expect(!response.hasMore)
    }

    @Test("encoding uses the spec's key names and ISO 8601 dates, and round-trips")
    func encodesWithSpecKeys() throws {
        let record = SyncRecord(
            type: "assignment",
            id: try #require(UUID(uuidString: "9A3F0000-0000-4000-8000-000000000002")),
            baseVersion: 7,
            updatedAt: Date(timeIntervalSince1970: 1_790_970_250),
            fields: ["title": "Programming coursework 1"])
        let request = SyncPushRequest(deviceID: "mac-1", cursor: 4821, records: [record])
        let data = try SyncCoding.encode(request)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains(#""schemaVersion":1"#))
        #expect(json.contains(#""deviceID":"mac-1""#))
        #expect(json.contains(#""baseVersion":7"#))
        #expect(json.contains(#""updatedAt":"2026-10-02T19:44:10Z""#))
        #expect(json.contains(#""deletedAt":null"#) || !json.contains("deletedAt"))
        #expect(!json.contains(#""version""#), "version is server-assigned and must not be sent on push")

        let decoded = try SyncCoding.decode(SyncPushRequest.self, from: data)
        #expect(decoded == request)
    }

    @Test("a tombstone is a record with deletedAt set")
    func tombstone() {
        let record = SyncRecord(
            type: "note", id: UUID(), baseVersion: 1, updatedAt: Date(), deletedAt: Date(), fields: [:])
        #expect(record.isDeleted)
    }

    @Test("wire dates keep milliseconds when present and stay plain when not")
    func datePrecision() throws {
        let whole = Date(timeIntervalSince1970: 1_790_970_250)
        let fractional = Date(timeIntervalSince1970: 1_790_970_250.25)
        #expect(SyncCoding.string(from: whole) == "2026-10-02T19:44:10Z")
        #expect(SyncCoding.string(from: fractional) == "2026-10-02T19:44:10.250Z")
        #expect(SyncCoding.date(from: "2026-10-02T19:44:10Z") == whole)
        #expect(SyncCoding.date(from: "2026-10-02T19:44:10.250Z") == fractional)
        #expect(SyncCoding.date(from: "15/10/2026") == nil)

        let encoded = try SyncCoding.encode([fractional])
        #expect(try SyncCoding.decode([Date].self, from: encoded) == [fractional])
        #expect(throws: DecodingError.self) {
            try SyncCoding.decode([Date].self, from: Data(#"["yesterday"]"#.utf8))
        }
    }

    @Test("the pull page size is 500 per §3.4")
    func pageSize() {
        #expect(SyncPullResponse.pageSize == 500)
    }
}
