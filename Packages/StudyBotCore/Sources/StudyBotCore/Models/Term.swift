import Foundation

/// One of the nine terms, September 2026 to July 2029 (spec §4). Dates are derived from
/// the programme calendar by `TermCalendar` in StudyBotKit; nothing here is typed by hand.
///
/// `modules` and `events` from the spec are inverses resolved by lookup on `year`/`termNumber`
/// and on date range respectively.
public struct Term: Syncable {
    public static let recordType = "term"

    public var sync: SyncMetadata
    /// 1, 2 or 3.
    public var year: Int
    /// 1, 2 or 3 within the year.
    public var number: Int
    /// First day of the term, at Europe/London midnight.
    public var startDate: Date
    /// Last day of the term, inclusive, at Europe/London midnight.
    public var endDate: Date

    public init(sync: SyncMetadata, year: Int, number: Int, startDate: Date, endDate: Date) {
        self.sync = sync
        self.year = year
        self.number = number
        self.startDate = startDate
        self.endDate = endDate
    }

    /// The deterministic id for a (year, number) pair, so both Macs derive the same record.
    public static func stableID(year: Int, number: Int) -> UUID {
        StableID.uuid(namespace: StableID.Namespace.term, name: "Y\(year)T\(number)")
    }

    /// "Y1 T2", for logs and compact labels.
    public var shortLabel: String { "Y\(year) T\(number)" }
}
