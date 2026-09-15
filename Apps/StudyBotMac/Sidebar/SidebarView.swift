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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SBColor.textPrimary)
                    .lineLimit(1)
                    .transition(.opacity)
                Spacer(minLength: 0)
                Button {
                    withAnimation(SBMotion.segment) { model.sidebarCollapsed = true }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .medium))
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
                withAnimation(SBMotion.segment) { model.sidebarCollapsed = false }
            }
        }
    }
}

/// One sidebar row. Hollow symbol, kept hollow when selected.
private struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let isCollapsed: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                if !isCollapsed {
                    Text(item.title)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .foregroundStyle(isSelected ? SBColor.accent : SBColor.textSecondary)
            .padding(.horizontal, 8)
            .frame(height: SBSpacing.sidebarRowHeight)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(
                RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous)
                    .fill(isSelected ? SBColor.accentSoft : isHovering ? Color.primary.opacity(0.06) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(isCollapsed ? item.title : "")
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
