#if DEBUG
    import AppKit
    import StudyBotCore
    import StudyBotKit
    import SwiftUI

    /// The two-machine drill (§3.11, §16) without a second Mac: `Tools/drill.sh` runs two copies
    /// of this build on separate stores and device ids, has each append to the same session's
    /// notes while the server is down, brings the server back, and checks both stores and the
    /// server archive. This runner is what the script drives inside the app.
    ///
    /// `STUDYBOT_DRILL=append:<text>`: open Block 1's induction session, append the text as a
    /// note line, write it, give the sync engine one attempt, quit.
    /// `STUDYBOT_DRILL=show`: wait for the launch sync, open Block mode on the induction
    /// session, hand the window to the external screenshot loop, quit.
    @MainActor
    enum DrillRunner {
        static func runIfRequested(model: AppModel) async {
            guard let spec = ProcessInfo.processInfo.environment["STUDYBOT_DRILL"] else { return }
            if case .firstRun = model.phase { model.continueFromFirstRun() }
            guard let notes = model.notes, let calendar = model.termCalendar,
                let block = calendar.blocks.first,
                let induction = SessionCatalog.days(of: block, in: model.events).first?.slots.first
            else { return }

            if spec.hasPrefix("append:") {
                let text = String(spec.dropFirst("append:".count))
                _ = await notes.open(induction, moduleID: model.moduleID(forCodes: induction.moduleCodes))
                notes.append(text, asQuestion: text.hasPrefix("ASK:"), to: induction.id)
                await notes.flush(induction.id)
                _ = await model.sync?.syncNow()
                try? await Task.sleep(for: .seconds(1))
                NSApplication.shared.terminate(nil)
            } else if spec == "show" {
                for _ in 0..<40 where model.sync?.lastOutcome == nil {
                    try? await Task.sleep(for: .milliseconds(250))
                }
                _ = await model.sync?.syncNow()
                model.blockMode = block
                model.selectedSlotID = induction.id
                try? await Task.sleep(for: .seconds(2))
                if let directory = SnapshotTour.directory {
                    NSApplication.shared.windows.first(where: { $0.isVisible })?
                        .setContentSize(SnapshotTour.windowSize)
                    try? await Task.sleep(for: .milliseconds(500))
                    await SnapshotTour.captureExternally("drill-\(model.deviceID)", to: directory)
                }
                NSApplication.shared.terminate(nil)
            }
        }
    }
#endif
