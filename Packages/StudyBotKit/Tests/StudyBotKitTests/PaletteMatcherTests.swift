import StudyBotKit
import Testing

@Suite("PaletteMatcher — ranking for ⌘K")
struct PaletteMatcherTests {
    private let commands = [
        PaletteCommand(id: "today", section: .goTo, title: "Today"),
        PaletteCommand(id: "assignments", section: .goTo, title: "Assignments"),
        PaletteCommand(id: "new-evidence", section: .actions, title: "New evidence"),
        PaletteCommand(id: "new-assignment", section: .actions, title: "New assignment", detail: "⌘N"),
        PaletteCommand(id: "block", section: .actions, title: "Open Block mode"),
        PaletteCommand(
            id: "module", section: .goTo, title: "Programming", detail: "COM1018DA", keywords: ["COM1018DA"]),
        PaletteCommand(
            id: "session", section: .goTo, title: "Online lectures", detail: "28 Sep", keywords: ["28 Sep"]),
    ]

    @Test("an empty query keeps the given order")
    func empty() {
        #expect(PaletteMatcher.matches("", in: commands) == commands)
    }

    @Test("title prefix beats word start beats subsequence; codes and dates match")
    func ranking() {
        let ev = PaletteMatcher.matches("ev", in: commands).map(\.id)
        #expect(ev.first == "new-evidence")
        let assign = PaletteMatcher.matches("assign", in: commands).map(\.id)
        #expect(assign == ["assignments", "new-assignment"])
        #expect(PaletteMatcher.matches("com1018", in: commands).map(\.id) == ["module"])
        #expect(PaletteMatcher.matches("28 sep", in: commands).map(\.id) == ["session"])
        #expect(PaletteMatcher.matches("blk", in: commands).map(\.id) == ["block"], "subsequence")
        #expect(PaletteMatcher.matches("zzz", in: commands).isEmpty)
    }
}
