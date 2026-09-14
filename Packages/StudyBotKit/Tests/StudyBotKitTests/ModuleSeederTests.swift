import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("ModuleSeeder — §4 programme structure from the calendar")
struct ModuleSeederTests {
    private func seed() throws -> (reading: ICSProgrammeCalendarReader.Reading, modules: [Module]) {
        let reading = try ICSProgrammeCalendarReader.read(
            try BundledProgrammeCalendar.data(), importedAt: RealCalendar.importedAt)
        let terms = TermCalendar(events: reading.events, derivedAt: RealCalendar.importedAt)
        return (reading, ModuleSeeder.modules(from: reading, terms: terms, now: RealCalendar.importedAt))
    }

    @Test("the calendar names every year-1 and year-2 module exactly as §4 lists them")
    func namesFromCalendar() throws {
        let reading = try seed().reading
        #expect(reading.moduleNames["COM1018DA"] == "Programming")
        #expect(reading.moduleNames["COM1014DA"] == "Discrete Mathematics for Computer Science")
        #expect(reading.moduleNames["COM1013DA"] == "Object-Oriented Programming")
        #expect(reading.moduleNames["COM1016DA"] == "Computational Mathematics")
        #expect(reading.moduleNames["COM1015DA"] == "Computers and the Internet")
        #expect(reading.moduleNames["COM1019DA"] == "Social and Professional Issues")
        #expect(reading.moduleNames["COM1017DA"] == "Professional Development 1")
        #expect(reading.moduleNames["COM2022DA"] == "Database Theory and Design")
        #expect(reading.moduleNames["COM2023DA"] == "Network and Computer Security")
        #expect(reading.moduleNames["COM2024DA"] == "Software Development")
        #expect(reading.moduleNames["COM2027DA"] == "Artificial Intelligence and Applications")
        #expect(reading.moduleNames["COM2025DA"] == "Web Development")
        #expect(reading.moduleNames["COM2026DA"] == "Team Project")
        #expect(reading.moduleNames["COM2028DA"] == "Professional Development 2")
        #expect(reading.moduleNames["COM3103DA"] == "Professional Development 3")
        #expect(reading.moduleNames["COM3104DA"] == "Synoptic Project")
        #expect(reading.moduleNames["COM3105DA"] == nil, "specialism options are bare codes in the calendar")
    }

    @Test("26 modules: 7 + 7 + ten specialism options + PD3 + Synoptic, with stable ids")
    func moduleCount() throws {
        let modules = try seed().modules
        #expect(modules.count == 26)
        #expect(modules.filter { $0.year == 1 }.count == 7)
        #expect(modules.filter { $0.year == 2 }.count == 7)
        #expect(modules.filter { $0.year == 3 }.count == 12)
        #expect(Set(modules.map(\.id)).count == 26)
        #expect(modules.allSatisfy { $0.id == Module.stableID(forCode: $0.code) })
        #expect(modules.allSatisfy { $0.isValid })
    }

    @Test("Professional Development spans its year; everything else in years 1–2 sits in one term")
    func termsAndSpanning() throws {
        let modules = try seed().modules
        let byCode = Dictionary(uniqueKeysWithValues: modules.map { ($0.code, $0) })
        let expectedTerms: [String: Int] = [
            "COM1018DA": 1, "COM1014DA": 1, "COM1013DA": 2, "COM1016DA": 2, "COM1015DA": 3, "COM1019DA": 3,
            "COM2022DA": 1, "COM2023DA": 1, "COM2024DA": 2, "COM2027DA": 2, "COM2025DA": 3, "COM2026DA": 3,
            "COM3105DA": 1, "COM3113DA": 1,
        ]
        for (code, term) in expectedTerms {
            let module = try #require(byCode[code])
            #expect(module.termNumber == term, "\(code)")
            #expect(!module.spansYear, "\(code)")
        }
        for code in ["COM1017DA", "COM2028DA", "COM3103DA", "COM3104DA"] {
            let module = try #require(byCode[code])
            #expect(module.spansYear, "\(code) should span its year")
            #expect(module.termNumber == nil, "\(code)")
        }
        // The calendar lists the second-specialism options on every term-2 *and* term-3 event of
        // year 3 (the same module set covers both), so they span the year too. Whether they
        // really run past term 2 is for Exeter to confirm; the data does not separate them.
        let secondSpecialism = try #require(byCode["COM3106DA"])
        #expect(secondSpecialism.spansYear)
    }

    @Test("the ten year-3 specialism options are flagged and keep their code as a name")
    func specialisms() throws {
        let (reading, modules) = try seed()
        let expected: Set<String> = [
            "COM3105DA", "COM3106DA", "COM3107DA", "COM3108DA", "COM3109DA",
            "COM3110DA", "COM3111DA", "COM3112DA", "COM3113DA", "COM3114DA",
        ]
        #expect(reading.specialismOptionCodes == expected)
        let options = modules.filter(\.isSpecialismOption)
        #expect(Set(options.map(\.code)) == expected)
        #expect(options.allSatisfy { $0.name == $0.code })
        #expect(options.allSatisfy { !$0.isArchived })
        let synoptic = try #require(modules.first { $0.code == "COM3104DA" })
        #expect(!synoptic.isSpecialismOption)
    }

    @Test("colours go round the eight-colour palette in programme order")
    func colours() throws {
        let modules = try seed().modules
        #expect(modules.map(\.code).prefix(3) == ["COM1018DA", "COM1014DA", "COM1017DA"])
        #expect(Array(modules.map(\.colour).prefix(9)) == ModuleColour.allCases + [.indigo])
    }
}
