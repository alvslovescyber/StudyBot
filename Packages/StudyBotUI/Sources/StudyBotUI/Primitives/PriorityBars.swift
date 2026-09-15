import StudyBotCore
import SwiftUI

/// Priority as 0–4 ascending bars (spec §9 component inventory). Filled bars are
/// `textSecondary`, empty ones `border`. No red: overdue is the only place red appears.
///
/// At `none` nothing is drawn: the view is an empty spacer of the same width, so the column
/// still aligns but a list of unprioritised stubs does not carry a grey glyph on every row
/// that means nothing. The prototype drew three bars and turned the top level red; the
/// spec's inventory says four and §9 reserves red for overdue, so the spec wins.
public struct PriorityBars: View {
    /// The width every instance occupies, drawn or not, so list columns line up.
    public static let width: CGFloat = 18
    public static let height: CGFloat = 12

    private let priority: Priority

    public init(_ priority: Priority) {
        self.priority = priority
    }

    public var body: some View {
        Group {
            if priority == .none {
                Color.clear
            } else {
                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(index < priority.barCount ? SBColor.textSecondary : SBColor.border)
                            .frame(width: 3, height: 4 + CGFloat(index) * 2.5)
                    }
                }
            }
        }
        .frame(width: PriorityBars.width, height: PriorityBars.height, alignment: .bottom)
        .accessibilityLabel(priority == .none ? "No priority" : "Priority \(priority.rawValue)")
    }
}
