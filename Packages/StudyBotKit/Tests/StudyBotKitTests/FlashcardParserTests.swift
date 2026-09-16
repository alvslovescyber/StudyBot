import StudyBotKit
import Testing

@Suite("FlashcardParser — defensive JSON")
struct FlashcardParserTests {
    @Test("finds the array inside a fence, drops half cards and yes/no fronts")
    func parses() throws {
        let output = """
            Here you go:
            ```json
            [{"front": "What is 3NF?", "back": "No transitive dependencies.", "sourceLine": "- 3NF"},
             {"front": "Is 3NF strict?", "back": "yes"},
             {"front": "", "back": "orphan"},
             {"front": "Define a relation", "back": "A subset of A × B."}]
            ```
            """
        let cards = try FlashcardParser.parse(output)
        #expect(cards.map(\.front) == ["What is 3NF?", "Define a relation"])
        #expect(cards[0].sourceLine == "- 3NF")
    }

    @Test("unreadable and empty outputs are named failures, never crashes")
    func failures() {
        #expect(throws: FlashcardParser.Failure.unreadable) { try FlashcardParser.parse("no json here") }
        #expect(throws: FlashcardParser.Failure.unreadable) { try FlashcardParser.parse("[{broken") }
        #expect(throws: FlashcardParser.Failure.empty) {
            try FlashcardParser.parse("[{\"front\": \"Is it?\", \"back\": \"yes\"}]")
        }
    }
}
