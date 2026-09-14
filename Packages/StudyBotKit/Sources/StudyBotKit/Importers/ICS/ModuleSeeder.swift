import Foundation
import StudyBotCore

/// Derives the `Module` records from the programme calendar (spec §4 "Seed from the real
/// programme structure"). Codes and titles come from the calendar's descriptions, never
/// from a typed list, so a reissued calendar reseeds the same way.
///
/// - `year` comes from the code (`COM1…` is year 1).
/// - `termNumber` is the one term whose module set contains the code; a module taught in
///   more than one term of its year (Professional Development, the Synoptic Project) gets
///   `spansYear` instead.
/// - Year-3 codes offered inside a "Specialism N module (out of …)" phrase are
///   `isSpecialismOption`. They have no name in the calendar, so the code stands in until the
///   user renames them in Settings; nothing is invented.
/// - Colours are assigned round-robin in programme order and are user-changeable afterwards.
public enum ModuleSeeder {
    /// Builds modules from a calendar reading and the terms derived from it.
    public static func modules(
        from reading: ICSProgrammeCalendarReader.Reading, terms: TermCalendar, now: Date
    )
        -> [Module]
    {
        // Programme order: the order codes first appear when events are read by date, and
        // within one event the order the calendar lists them ("COM1018DA Programming / COM1014DA …").
        let live = reading.events.filter { !$0.isCancelled }.sorted { $0.startDate < $1.startDate }
        var codes: [String] = []
        var seen = Set<String>()
        for event in live {
            for code in event.moduleCodes where seen.insert(code).inserted {
                codes.append(code)
            }
        }
        codes.sort { lhs, rhs in
            let lhsYear = Module.year(fromCode: lhs) ?? 0
            let rhsYear = Module.year(fromCode: rhs) ?? 0
            if lhsYear != rhsYear { return lhsYear < rhsYear }
            return false  // stable: keep first-appearance order within a year
        }

        return codes.enumerated().map { index, code in
            let year = Module.year(fromCode: code) ?? 0
            let termsTeaching = terms.terms.filter {
                $0.year == year && terms.moduleCodes(in: $0).contains(code)
            }
            let spansYear = termsTeaching.count > 1
            return Module(
                sync: SyncMetadata.new(id: Module.stableID(forCode: code), at: now),
                name: reading.moduleNames[code] ?? code,
                code: code,
                colour: ModuleColour.roundRobin(index),
                year: year,
                termNumber: spansYear ? nil : termsTeaching.first?.number,
                spansYear: spansYear,
                isSpecialismOption: reading.specialismOptionCodes.contains(code))
        }
    }
}
