import AppKit
import StudyBotUI
import SwiftUI

/// The genuine macOS sidebar material (§9 "The sidebar"): `NSVisualEffectView` with the
/// `.sidebar` material and `.behindWindow` blending, so the desktop shows through the way it
/// does in Finder. The content pane beside it is opaque `surface`, which is what makes the
/// translucency read as a distinct region rather than a wash across the whole window.
struct SidebarBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Sidebar chrome: fixed width from the tokens, the material behind it, a hairline on its
/// trailing edge. Snapshot captures cannot render behind-window blending, so a debug capture
/// paints `canvas` instead; the layout is identical.
struct SidebarChrome<Content: View>: View {
    let isCollapsed: Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.sbScale) private var scale

    var body: some View {
        content()
            .frame(width: isCollapsed ? SBSpacing.sidebarRailWidth : SBSpacing.sidebarWidth(at: scale))
            .frame(maxHeight: .infinity)
            .background {
                if SidebarChrome.isSnapshotting {
                    SBColor.canvas
                } else {
                    SidebarBackground()
                }
            }
            .overlay(alignment: .trailing) {
                SBColor.border.frame(width: 1)
            }
    }

    private static var isSnapshotting: Bool {
        #if DEBUG
            ProcessInfo.processInfo.environment["STUDYBOT_SNAPSHOT_DIR"] != nil
        #else
            false
        #endif
    }
}
