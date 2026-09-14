import Foundation
import StudyBotKit
import Testing

@Suite("ICSParser — RFC 5545 tokenizing")
struct ICSParserTests {
    @Test("folded lines are joined, with CRLF and with bare LF")
    func unfolding() {
        let crlf =
            "DESCRIPTION:Induction (start of the apprenticeship).\\n\\nModules in this b\r\n lock: COM1018DA\r\nEND:X\r\n"
        #expect(
            ICSParser.unfold(crlf) == [
                "DESCRIPTION:Induction (start of the apprenticeship).\\n\\nModules in this block: COM1018DA",
                "END:X",
                "",
            ])
        let lf = "SUMMARY:one\n two\n\tthree\nUID:x"
        #expect(ICSParser.unfold(lf) == ["SUMMARY:onetwothree", "UID:x"])
    }

    @Test("a folded line keeps a double space when the break fell after a space")
    func foldAfterSpace() {
        // The real file has "Discrete Mathematics for Computer\r\n  Science": the fold marker is
        // one space, the second space is content.
        let text = "X:Computer\r\n  Science\r\n"
        #expect(ICSParser.unfold(text).first == "X:Computer Science")
    }

    @Test("parameters are parsed and a quoted value may contain a colon")
    func parameters() throws {
        let calendar = try ICSParser.parse(
            """
            BEGIN:VCALENDAR
            BEGIN:VEVENT
            DTSTART;VALUE=DATE:20260923
            ATTENDEE;CN="Doe: Jane";ROLE=CHAIR:mailto:jane@example.org
            END:VEVENT
            END:VCALENDAR
            """)
        let event = try #require(calendar.events.first)
        let start = try #require(event.property("dtstart"))
        #expect(start.value == "20260923")
        #expect(start[parameter: "value"] == "DATE")
        let attendee = try #require(event.property("ATTENDEE"))
        #expect(attendee.parameters == ["CN": "Doe: Jane", "ROLE": "CHAIR"])
        #expect(attendee.value == "mailto:jane@example.org")
    }

    @Test("TEXT escapes resolve and unknown escapes are preserved")
    func textEscapes() {
        let property = ICSProperty(name: "DESCRIPTION", value: #"a\nb\Nc\,d\;e\\f\qg\"#)
        #expect(property.textValue == "a\nb\nc,d;e\\f\\qg\\")
        #expect(property.value == #"a\nb\Nc\,d\;e\\f\qg\"#)
    }

    @Test("nested components land under their parents")
    func nesting() throws {
        let calendar = try ICSParser.parse(
            """
            BEGIN:VCALENDAR
            VERSION:2.0
            BEGIN:VEVENT
            UID:1
            BEGIN:VALARM
            ACTION:DISPLAY
            END:VALARM
            END:VEVENT
            BEGIN:VEVENT
            UID:2
            END:VEVENT
            END:VCALENDAR
            """)
        #expect(calendar.name == "VCALENDAR")
        #expect(calendar.property("VERSION")?.value == "2.0")
        #expect(calendar.events.count == 2)
        #expect(calendar.events[0].children(named: "VALARM").count == 1)
        #expect(calendar.events[0].properties.map(\.name) == ["UID"])
        #expect(calendar.events[1].property("UID")?.value == "2")
    }

    @Test("a UTF-8 byte-order mark is tolerated")
    func byteOrderMark() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n".utf8))
        let calendar = try ICSParser.parse(data)
        #expect(calendar.name == "VCALENDAR")
    }

    @Test("malformed input fails with a named error rather than a crash")
    func errors() {
        #expect(throws: ICSParser.Error.malformedLine(2)) {
            try ICSParser.parse("BEGIN:VCALENDAR\nthis line has no colon\nEND:VCALENDAR")
        }
        #expect(throws: ICSParser.Error.mismatchedEnd(expected: "VEVENT", found: "VCALENDAR")) {
            try ICSParser.parse("BEGIN:VCALENDAR\nBEGIN:VEVENT\nEND:VCALENDAR")
        }
        #expect(throws: ICSParser.Error.unterminatedComponent("VEVENT")) {
            try ICSParser.parse("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:1\n")
        }
        #expect(throws: ICSParser.Error.noCalendar) {
            try ICSParser.parse("")
        }
        #expect(throws: ICSParser.Error.notUTF8) {
            try ICSParser.parse(Data([0xFF, 0xFE, 0xFD]))
        }
    }

    @Test("the real programme calendar tokenizes into 156 VEVENTs with unfolded descriptions")
    func realFile() throws {
        let calendar = try ICSParser.parse(try BundledProgrammeCalendar.data())
        #expect(calendar.events.count == 156)
        #expect(calendar.property("X-WR-TIMEZONE")?.value == "Europe/London")
        let induction = try #require(calendar.events.first)
        let description = try #require(induction.property("DESCRIPTION")).textValue
        // This phrase is split across a fold in the file; it only reads correctly if unfolding worked.
        #expect(description.contains("Modules in this block: COM1018DA Programming"))
        #expect(description.contains("COM1014DA Discrete Mathematics for Computer Science"))
        #expect(description.contains("\n\n"))
        for event in calendar.events {
            #expect(event.property("DTSTART")?[parameter: "VALUE"] == "DATE")
            #expect(event.property("DTEND") != nil)
            #expect(event.property("UID") != nil)
        }
    }
}
