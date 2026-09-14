/// A grade band (spec §4 Supporting types, §12). Bands are configurable in Settings;
/// the defaults are the common UK undergraduate pattern and must be confirmed with
/// Exeter at induction (§14, open question 6).
public struct GradeBand: Codable, Hashable, Sendable {
    public var label: String
    /// The lowest mark that reaches this band, inclusive.
    public var minimum: Double
    public var colour: BandColour

    public init(label: String, minimum: Double, colour: BandColour) {
        self.label = label
        self.minimum = minimum
        self.colour = colour
    }

    /// Distinction 70, Merit 60, Pass 50, Threshold 40. Colours per §6.2.
    public static let defaults: [GradeBand] = [
        GradeBand(label: "Distinction", minimum: 70, colour: .green),
        GradeBand(label: "Merit", minimum: 60, colour: .indigo),
        GradeBand(label: "Pass", minimum: 50, colour: .grey),
        GradeBand(label: "Threshold", minimum: 40, colour: .grey),
    ]

    /// The highest band whose minimum `mark` reaches, or nil when the mark is below every band.
    public static func band(for mark: Double, in bands: [GradeBand]) -> GradeBand? {
        bands.filter { mark >= $0.minimum }.max { $0.minimum < $1.minimum }
    }
}
