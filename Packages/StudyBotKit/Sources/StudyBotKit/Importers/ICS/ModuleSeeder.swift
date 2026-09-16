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
/// - Colours: eight across 26 modules means repeats, so they are assigned in programme order
///   such that modules sharing a term never share a colour while one is free (§9 patch 9).
///   Only year 3's specialism options, eleven modules in one term, are forced to repeat, and
///   then the least-used colour in that term is taken. User-changeable afterwards.
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

        var usedByTerm: [UUID: [ModuleColour]] = [:]
        return codes.enumerated().map { index, code in
            let year = Module.year(fromCode: code) ?? 0
            let termsTeaching = terms.terms.filter {
                $0.year == year && terms.moduleCodes(in: $0).contains(code)
            }
            let spansYear = termsTeaching.count > 1
            // A year-spanning module shares every term of its year.
            let sharedTerms = spansYear ? terms.terms.filter { $0.year == year } : termsTeaching
            let colour = ModuleSeeder.colour(
                preferring: index, avoiding: sharedTerms.flatMap { usedByTerm[$0.id] ?? [] })
            for term in sharedTerms {
                usedByTerm[term.id, default: []].append(colour)
            }
            return Module(
                sync: SyncMetadata.new(id: Module.stableID(forCode: code), at: now),
                name: reading.moduleNames[code] ?? code,
                code: code,
                colour: colour,
                year: year,
                termNumber: spansYear ? nil : termsTeaching.first?.number,
                spansYear: spansYear,
                isSpecialismOption: reading.specialismOptionCodes.contains(code))
        }
    }

    /// The first colour from `index` round the palette that no module sharing a term has taken;
    /// when every colour is taken, the one taken fewest times.
    public static func colour(preferring index: Int, avoiding taken: [ModuleColour]) -> ModuleColour {
        let palette = ModuleColour.allCases
        let order = (0..<palette.count).map { ModuleColour.roundRobin(index + $0) }
        if let free = order.first(where: { !taken.contains($0) }) { return free }
        var counts: [ModuleColour: Int] = [:]
        for colour in taken { counts[colour, default: 0] += 1 }
        return order.min {
            (counts[$0] ?? 0, order.firstIndex(of: $0) ?? 0) < (
                counts[$1] ?? 0, order.firstIndex(of: $1) ?? 0
            )
        }
            ?? palette[0]
    }
}
