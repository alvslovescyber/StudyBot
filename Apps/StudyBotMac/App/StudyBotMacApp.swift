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
                .dynamicTypeSize(textSizes)
                .task {
                    await model.start()
                    #if DEBUG
                        if ProcessInfo.processInfo.environment["STUDYBOT_DRILL"] == nil {
                            SnapshotTour.runIfRequested(model: model)
                        }
                    #endif
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1320, height: 800)
        .commands {
            AppCommands(model: model)
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }

    /// The full range, so the system setting rules, unless a debug snapshot pins one size.
    private var textSizes: ClosedRange<DynamicTypeSize> {
        #if DEBUG
            SnapshotTour.textSize ?? DynamicTypeSize.xSmall...DynamicTypeSize.accessibility5
        #else
            DynamicTypeSize.xSmall...DynamicTypeSize.accessibility5
        #endif
    }
}
