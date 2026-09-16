import StudyBotUI
import SwiftUI

/// The sidebar (§9 "The sidebar"): Finder's is the reference. 28pt rows, 8pt inset, icons in a
/// fixed 20pt frame so every label starts on the same x, selection changes colour and
/// background only. No keyboard hints. Collapses to a 56pt icon rail.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 6)
                .padding(.bottom, 16)

            ForEach(SidebarItem.allCases) { item in
                SidebarRow(
                    item: item,
                    badge: model.sidebarCount(for: item),
                    isSelected: model.selection == item,
                    isCollapsed: model.sidebarCollapsed
                ) {
                    model.selection = item
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SBSpacing.sidebarInset)
        // 52pt clears the traffic lights, which sit over the sidebar under the hidden title bar.
        .padding(.top, 52)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 9) {
            AppMark(size: 18)
            if !model.sidebarCollapsed {
                Text("StudyBot")
                    .sbFont(13, weight: .semibold)
                    .foregroundStyle(SBColor.textPrimary)
                    .lineLimit(1)
                    .transition(.opacity.animation(SBMotion.sidebarLabel.animation))
                Spacer(minLength: 0)
                Button {
                    withSBAnimation(SBMotion.sidebar) { model.sidebarCollapsed = true }
                } label: {
                    Image(systemName: "sidebar.left")
                        .sbFont(13, weight: .medium)
                        .foregroundStyle(SBColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Hide sidebar (⌥⌘S)")
            }
        }
        .frame(height: 22)
        .frame(maxWidth: .infinity, alignment: model.sidebarCollapsed ? .center : .leading)
        .onTapGesture {
            if model.sidebarCollapsed {
                withSBAnimation(SBMotion.sidebar) { model.sidebarCollapsed = false }
            }
        }
    }
}

/// One sidebar row. Hollow symbol, kept hollow when selected. The count at the right is the
/// one number that section carries (§ UI revision: questions to ask, assignments due this
/// term, sessions with notes, cards due today, evidence logged); nothing is shown for zero.
private struct SidebarRow: View {
    let item: SidebarItem
    /// The section's one number; nothing is drawn for zero.
    let badge: Int
    let isSelected: Bool
    let isCollapsed: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.sbScale) private var scale

    var body: some View {
        Button(action: action) {
            HStack(spacing: scale(10)) {
                Image(systemName: item.symbol)
                    .sbFont(15, weight: .medium)
                    .frame(width: scale(20))
                if !isCollapsed {
                    // Two lines at accessibility sizes rather than an ellipsis (§9).
                    Text(item.title)
                        .sbFont(13, weight: isSelected ? .medium : .regular)
                        .lineLimit(scale.isAccessibility ? 2 : 1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .transition(.opacity.animation(SBMotion.sidebarLabel.animation))
                    if badge > 0 {
                        Spacer(minLength: scale(6))
                        Text("\(badge)")
                            .sbFont(12)
                            .foregroundStyle(SBColor.textTertiary)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(badge)))
                            .sbAnimation(SBMotion.count, value: badge)
                            .transition(.opacity.animation(SBMotion.sidebarLabel.animation))
                    }
                }
            }
            .foregroundStyle(isSelected ? SBColor.accent : SBColor.textSecondary)
            .padding(.horizontal, scale(8))
            .frame(minHeight: scale(SBSpacing.sidebarRowHeight))
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(
                RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous)
                    .fill(isSelected ? SBColor.accentSoft : isHovering ? Color.primary.opacity(0.06) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Instant: a hover that fades reads as lag (§9).
        .onHover { isHovering = $0 }
        .animation(SBMotion.hover, value: isHovering)
        .help(isCollapsed ? item.title : "")
        .accessibilityLabel(item.title)
        .accessibilityValue(badge > 0 ? "\(badge)" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
