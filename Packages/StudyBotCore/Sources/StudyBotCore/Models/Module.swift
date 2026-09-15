import Foundation

/// A taught module (spec §4). Seeded from the real programme structure on import; codes
/// and titles come from the official calendar, never typed.
///
/// Relationships in the spec (`assignments`, `sessions`) are inverses: an assignment or
/// session carries a `moduleID`, and the store answers "which assignments belong to this
/// module" by lookup. A value type cannot hold a two-way object graph.
public struct Module: Syncable {
    public static let recordType = "module"

    public var sync: SyncMetadata
    /// "Discrete Mathematics for Computer Science"
    public var name: String
    /// "COM1014DA"
    public var code: String
    public var colour: ModuleColour
    /// 1, 2 or 3.
    public var year: Int
    /// Term number within the year, 1–3. Nil when `spansYear` is true.
    public var termNumber: Int?
    /// Professional Development and the Synoptic Project run across more than one term.
    public var spansYear: Bool
    public var credits: Int?
    /// Share of the year, once known.
    public var weighting: Double?
    /// Year 3: offered but not yet chosen.
    public var isSpecialismOption: Bool
    /// Unchosen specialisms, completed modules.
    public var isArchived: Bool

    public init(
        sync: SyncMetadata,
        name: String,
        code: String,
        colour: ModuleColour,
        year: Int,
        termNumber: Int?,
        spansYear: Bool = false,
        credits: Int? = nil,
        weighting: Double? = nil,
        isSpecialismOption: Bool = false,
        isArchived: Bool = false
    ) {
        self.sync = sync
        self.name = name
        self.code = code
        self.colour = colour
        self.year = year
        self.termNumber = termNumber
        self.spansYear = spansYear
        self.credits = credits
        self.weighting = weighting
        self.isSpecialismOption = isSpecialismOption
        self.isArchived = isArchived
    }

    /// The id of the one term this module sits in, derived from `year` and `termNumber`.
    /// Nil for year-spanning modules.
    public var termID: UUID? {
        termNumber.map { Term.stableID(year: year, number: $0) }
    }

    /// The deterministic id for a module code, so both Macs derive the same record.
    public static func stableID(forCode code: String) -> UUID {
        StableID.uuid(namespace: StableID.Namespace.module, name: code.uppercased())
    }

    /// The year a module code implies: `COM1…` is year 1, `COM2…` year 2, `COM3…` year 3.
    /// Nil when the code does not follow the Exeter pattern.
    public static func year(fromCode code: String) -> Int? {
        guard code.count >= 4, code.hasPrefix("COM") else { return nil }
        let digit = code[code.index(code.startIndex, offsetBy: 3)]
        guard let year = digit.wholeNumberValue, (1...3).contains(year) else { return nil }
        return year
    }
}
