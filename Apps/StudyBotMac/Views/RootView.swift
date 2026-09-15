import StudyBotUI
import SwiftUI

/// The window: a fixed-width vibrancy sidebar beside an opaque `surface` content pane, so
/// the sidebar reads as a distinct region (§9 "The sidebar"). The sidebar runs under the
/// hidden title bar exactly as Finder's does. Launch phases per §6.0.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.phase {
        case .loading:
            SBColor.canvas.overlay(ProgressView().controlSize(.small))
        case .firstRun(let facts):
            FirstRunView(facts: facts)
        case .failed(let message):
            SBColor.canvas.overlay(
                Text(message)
                    .sbType(SBType.body)
                    .foregroundStyle(SBColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .padding(SBSpacing.region)
            )
        case .ready:
            HStack(spacing: 0) {
                SidebarChrome(isCollapsed: model.sidebarCollapsed) {
                    SidebarView()
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SBColor.surface)
            }
            .ignoresSafeArea()
            .animation(SBMotion.segment, value: model.sidebarCollapsed)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.selection {
        case .today:
            TodayView()
        case .assignments:
            AssignmentsScreen()
        case .modules:
            ComingLaterView(
                title: "Modules & notes",
                line: "Session notes arrive in the next milestone. Your 26 modules are already imported.")
        case .revision:
            ComingLaterView(
                title: "Revision", line: "Queue clear. Decks appear once notes have been structured.")
        case .portfolio:
            ComingLaterView(
                title: "Portfolio", line: "No evidence yet. Capture arrives with the next milestone.")
        }
    }
}

/// A section that exists in the sidebar but not yet in the build. One honest line, no illustration.
private struct ComingLaterView: View {
    let title: String
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(title: title) { EmptyView() }
            EmptyState(line)
            Spacer()
        }
    }
}

/// The header every screen shares: 15pt semibold title, controls on the right, hairline below.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .sbType(SBType.section)
                .fontWeight(.semibold)
                .foregroundStyle(SBColor.textPrimary)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: SBSpacing.x2)
            trailing()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, SBSpacing.rowHorizontal)
        .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }
    }
}
