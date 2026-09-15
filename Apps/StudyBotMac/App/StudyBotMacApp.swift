import StudyBotUI
import SwiftUI

/// The Mac app: views and app lifecycle, nothing else (spec §3.2). Every decision lives in a
/// package; if something here needs an `if` with more than two branches, it is in the wrong place.
@main
struct StudyBotMacApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("StudyBot") {
            RootView()
                .environment(model)
                .frame(minWidth: 1080, minHeight: 600)
                .task {
                    await model.start()
                    #if DEBUG
                        SnapshotTour.runIfRequested(model: model)
                    #endif
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1320, height: 800)
        .commands {
            AppCommands(model: model)
        }
    }
}
