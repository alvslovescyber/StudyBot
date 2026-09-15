import StudyBotCore
import SwiftUI

/// A grade as a number coloured by band (spec §6.2): distinction green, merit indigo, pass
/// grey, below every band red. Bands come from Settings.
public struct GradeBadge: View {
    private let grade: Double
    private let bands: [GradeBand]

    public init(_ grade: Double, bands: [GradeBand]) {
        self.grade = grade
        self.bands = bands
    }

    public var body: some View {
        Text(formatted)
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(colour)
            .accessibilityLabel("Grade \(formatted)\(bandLabel.map { ", \($0)" } ?? "")")
    }

    private var band: GradeBand? { GradeBand.band(for: grade, in: bands) }
    private var bandLabel: String? { band?.label }
    private var colour: Color { band.map { SBColor.band($0.colour) } ?? SBColor.danger }

    private var formatted: String {
        grade.rounded() == grade ? String(Int(grade)) : String(format: "%.1f", grade)
    }
}
