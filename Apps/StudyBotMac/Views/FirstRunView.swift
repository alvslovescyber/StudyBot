import StudyBotKit
import StudyBotUI
import SwiftUI

/// Launch one (§6.0): a single screen, not a carousel. Three lines of real numbers pulled from
/// the import, one button. No wizard, no sample data, no permission prompts.
struct FirstRunView: View {
    @Environment(AppModel.self) private var model
    let facts: AppModel.FirstRunFacts

    var body: some View {
        VStack(alignment: .leading, spacing: SBSpacing.x6) {
            AppMark(size: 36)
            Text("Your programme is already loaded.")
                .sbType(SBType.title)
                .foregroundStyle(SBColor.textPrimary)

            VStack(alignment: .leading, spacing: SBSpacing.x2) {
                Text("\(facts.submissionCount) submissions across three years")
                if let first = facts.firstDeadline {
                    Text("First one due \(RelativeDate.fullDate(first))")
                }
                if let days = facts.daysToBlockOne, let block = facts.blockOne {
                    Text(blockLine(days: days, block: block))
                }
            }
            .sbType(SBType.body)
            .foregroundStyle(SBColor.textSecondary)

            Btn.primary("Continue", icon: "arrow.right") {
                model.continueFromFirstRun()
            }
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(SBSpacing.detailOuter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SBColor.canvas)
    }

    private func blockLine(days: Int, block: CampusBlock) -> String {
        let name = block.includesInduction ? "Induction" : "Block \(block.number)"
        switch days {
        case 0: return "\(name) is today"
        case 1: return "\(name) tomorrow"
        default: return "\(name) in \(days) days"
        }
    }
}
