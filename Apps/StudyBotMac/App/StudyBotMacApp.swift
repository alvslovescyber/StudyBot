import AppKit
import StudyBotUI
import SwiftUI

/// The Mac app: views and app lifecycle, nothing else (spec §3.2). Every decision lives in a
/// package; if something here needs an `if` with more than two branches, it is in the wrong place.
@main
struct StudyBotMacApp: App {
    @State private var model = AppModel()
    @State private var keyMonitor: KeyMonitor?
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("StudyBot") {
            RootView()
                .environment(model)
                .frame(minWidth: 1080, minHeight: 600)
                .dynamicTypeSize(textSizes)
                .task {
                    delegate.model = model
                    if keyMonitor == nil { keyMonitor = KeyMonitor(model: model) }
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

/// Quitting over unsaved notes is the one thing §16 forbids. Everything else about the app's
/// lifecycle is SwiftUI's.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor var model: AppModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            guard let model, model.hasUnsavedNotes else { return .terminateNow }
            let alert = NSAlert()
            alert.messageText = "Some notes are not saved"
            let titles = model.notes?.unsavedSessionTitles.joined(separator: ", ") ?? ""
            alert.informativeText =
                "\(titles) could not be written. The text is still in StudyBot. Free some disk space, then Try again on the note. Quitting now loses it."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Keep StudyBot open")
            alert.addButton(withTitle: "Quit and lose the notes")
            return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
        }
    }
}
