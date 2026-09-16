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
            ready
        }
    }

    @ViewBuilder
    private var ready: some View {
        @Bindable var model = model
        ZStack {
            HStack(spacing: 0) {
                SidebarChrome(isCollapsed: model.sidebarCollapsed) {
                    SidebarView()
                }
                Group {
                    if let block = model.blockMode {
                        BlockModeScreen(block: block)
                    } else {
                        content
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SBColor.surface)
            }
            .animation(SBMotion.segment, value: model.sidebarCollapsed)
            if model.paletteShown {
                CommandPaletteView()
            }
        }
        .ignoresSafeArea()
        .sheet(item: $model.evidenceDraft) { draft in
            EvidenceSheet(draft: draft).environment(model)
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
            ModulesScreen()
        case .revision:
            ComingLaterView(
                title: "Revision", line: "Queue clear. Decks appear once notes have been structured.")
        case .portfolio:
            PortfolioScreen()
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
/// When the controls do not fit beside the title (large text in a small window) they drop to a
/// second line rather than clipping (§9).
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing
    @Environment(\.sbScale) private var scale

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: scale(8)) {
                titleText
                Spacer(minLength: SBSpacing.x2)
                trailing().fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: scale(10)) {
                titleText
                trailing().fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, scale(14))
        .padding(.horizontal, scale(SBSpacing.rowHorizontal))
        .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }
    }

    private var titleText: some View {
        Text(title)
            .fontWeight(.semibold)
            .sbType(SBType.section)
            .foregroundStyle(SBColor.textPrimary)
            .lineLimit(1)
            .fixedSize()
    }
}
