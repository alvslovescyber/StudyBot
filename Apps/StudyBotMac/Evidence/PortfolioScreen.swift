import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// Portfolio (§6.5), the Evidence segment: a reverse-chronological list and the capture
/// button. KSBs and Off-the-job arrive with their data and their milestones.
struct PortfolioScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Portfolio") {
                Btn.primary("New evidence", icon: "plus", size: .small) { model.beginEvidence() }
            }
            if let store = model.evidence {
                if store.items.isEmpty {
                    EmptyState(
                        "No evidence yet. Log something from this week's work.", actionTitle: "New evidence"
                    ) {
                        model.beginEvidence()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            SectionHeader("Evidence", count: store.items.count)
                            ForEach(store.items) { item in
                                row(item)
                            }
                        }
                    }
                }
            }
        }
        .background(SBColor.surface)
    }

    private func row(_ item: Evidence) -> some View {
        ListRow(
            isSelected: false, action: {},
            content: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).sbType(SBType.row).foregroundStyle(SBColor.textPrimary).lineLimit(1)
                    Text(item.summary).sbFont(12).foregroundStyle(SBColor.textSecondary).lineLimit(
                        scale.isAccessibility ? 3 : 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !item.pendingKSBCodes.isEmpty {
                    Text(item.pendingKSBCodes.joined(separator: " "))
                        .font(SBType.mono(10.5, weight: .semibold))
                        .foregroundStyle(SBColor.accent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(SBColor.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous))
                }
                if item.isWorkConfidential {
                    Tag("confidential")
                }
                Text(RelativeDate.absolute(item.date, relativeTo: model.now()))
                    .sbFont(12).foregroundStyle(SBColor.textSecondary).monospacedDigit()
                    .frame(width: scale(96), alignment: .trailing)
            }
        )
        .contextMenu {
            Button("Delete…", role: .destructive) { Task { await model.evidence?.delete(item.id) } }
        }
    }
}
