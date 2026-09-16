import AppKit
import StudyBotUI
import SwiftUI

/// Who this is and where the data goes, at the foot of the sidebar: the Mac account's name,
/// and whether this Mac is paired. Opens Settings. Nothing here is typed into the app; the
/// name is the account's, and the pairing is the sync state.
struct SidebarUserBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    @State private var isHovering = false
    let isCollapsed: Bool

    private var fullName: String {
        let name = NSFullUserName()
        return name.isEmpty ? NSUserName() : name
    }

    private var initials: String {
        let parts = fullName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var secondLine: String {
        guard let sync = model.sync, sync.isPaired else { return "This Mac only" }
        if let device = sync.state.deviceName { return "Synced as \(device)" }
        return "Synced"
    }

    var body: some View {
        Button {
            NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } label: {
            HStack(spacing: scale(9)) {
                Text(initials)
                    .sbFont(10, weight: .semibold)
                    .foregroundStyle(SBColor.accent)
                    .frame(width: scale(24), height: scale(24))
                    .background(Circle().fill(SBColor.accentSoft))
                    .accessibilityHidden(true)
                if !isCollapsed {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(fullName)
                            .sbFont(12, weight: .medium)
                            .foregroundStyle(SBColor.textPrimary)
                            .lineLimit(1)
                        Text(secondLine)
                            .sbFont(11)
                            .foregroundStyle(SBColor.textTertiary)
                            .lineLimit(1)
                    }
                    .transition(.opacity.animation(SBMotion.sidebarLabel.animation))
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, scale(6))
            .padding(.vertical, scale(6))
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(
                RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.06) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(SBMotion.hover, value: isHovering)
        .help("Settings")
        .accessibilityLabel("\(fullName). \(secondLine). Opens Settings.")
    }
}
