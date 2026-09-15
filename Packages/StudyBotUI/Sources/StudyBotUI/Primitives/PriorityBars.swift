import StudyBotCore
import SwiftUI

/// Priority as 0–4 ascending bars (spec §9 component inventory). Filled bars are
/// `textSecondary`, empty ones `border`. No red: overdue is the only place red appears.
///
/// The prototype drew three bars and turned the top level red; the spec's inventory says
/// four and §9 reserves red for overdue, so the spec wins.
public struct PriorityBars: View {
    private let priority: Priority

    public init(_ priority: Priority) {
        self.priority = priority
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < priority.barCount ? SBColor.textSecondary : SBColor.border)
                    .frame(width: 3, height: 4 + CGFloat(index) * 2.5)
            }
        }
        .frame(width: 18, height: 12, alignment: .bottom)
        .accessibilityLabel("Priority \(priority.rawValue)")
    }
}
