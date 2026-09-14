/// One column of the configurable off-the-job export (spec §4 Supporting types, §6.5).
public struct ExportColumn: Codable, Hashable, Sendable {
    /// The column heading as it should appear in the exported file.
    public var header: String
    public var field: OTJField
    /// Left-to-right position.
    public var order: Int
    /// A date format pattern for `date` fields, e.g. `"dd/MM/yyyy"`. Nil for other fields.
    public var dateFormat: String?

    public init(header: String, field: OTJField, order: Int, dateFormat: String? = nil) {
        self.header = header
        self.field = field
        self.order = order
        self.dateFormat = dateFormat
    }

    /// A sensible starting mapping until Exeter's template is known (§14, open question 2).
    public static let defaults: [ExportColumn] = [
        ExportColumn(header: "Date", field: .date, order: 0, dateFormat: "dd/MM/yyyy"),
        ExportColumn(header: "Hours", field: .hours, order: 1),
        ExportColumn(header: "Category", field: .category, order: 2),
        ExportColumn(header: "Description", field: .description, order: 3),
    ]
}
