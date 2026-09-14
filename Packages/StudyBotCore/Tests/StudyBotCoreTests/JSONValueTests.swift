import Foundation
import StudyBotCore
import Testing

@Suite("JSONValue")
struct JSONValueTests {
    @Test("every JSON type round-trips through Codable unchanged")
    func roundTrip() throws {
        let value: JSONValue = [
            "title": "Programming coursework 1",
            "status": "drafting",
            "dueDate": "2026-10-15",
            "wordLimit": 2500,
            "weighting": 0.4,
            "submitted": false,
            "grade": nil,
            "fieldOverrides": ["dueDate"],
            "nested": ["a": ["b": [1, 2, 3]]],
        ]
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("a field this build has never heard of survives decode and re-encode")
    func unknownFieldsSurvive() throws {
        // A newer client added "mentorName". This build must not drop it (§3.10a).
        let wire = #"{"title":"Coursework","mentorName":"Dr Patel","futureFlag":true}"#
        let decoded = try JSONDecoder().decode(
            [String: JSONValue].self, from: Data(wire.utf8))
        #expect(decoded["mentorName"] == "Dr Patel")
        #expect(decoded["futureFlag"] == true)

        let reencoded = try JSONEncoder().encode(decoded)
        let again = try JSONDecoder().decode([String: JSONValue].self, from: reencoded)
        #expect(again == decoded)
    }

    @Test("null is preserved as an explicit null, not dropped")
    func nullIsExplicit() throws {
        let wire = #"{"grade":null}"#
        let decoded = try JSONDecoder().decode(
            [String: JSONValue].self, from: Data(wire.utf8))
        #expect(decoded["grade"] == .null)
        #expect(decoded["grade"]?.isNull == true)
    }

    @Test("typed accessors return the payload only for the matching case")
    func accessors() {
        #expect(JSONValue.string("x").stringValue == "x")
        #expect(JSONValue.string("x").numberValue == nil)
        #expect(JSONValue.number(7).intValue == 7)
        #expect(JSONValue.number(7.5).intValue == nil)
        #expect(JSONValue.number(7.5).numberValue == 7.5)
        #expect(JSONValue.bool(true).boolValue == true)
        #expect(JSONValue.array([1]).arrayValue == [.number(1)])
        #expect(JSONValue.object(["k": "v"]).objectValue == ["k": .string("v")])
    }

    @Test("a JSON string that is not a number is not coerced into one")
    func stringsStayStrings() throws {
        let decoded = try JSONDecoder().decode(JSONValue.self, from: Data(#""42""#.utf8))
        #expect(decoded == .string("42"))
    }
}
