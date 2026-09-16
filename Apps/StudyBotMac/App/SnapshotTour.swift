#if DEBUG
    import AppKit
    import StudyBotCore
    import StudyBotKit
    import SwiftUI

    /// A debug-only walk through the app that writes a PNG of the window at each step, so a
    /// build can be judged against the real import without anyone screen-recording.
    ///
    /// Enabled by launching with `STUDYBOT_SNAPSHOT_DIR=/some/folder`. Captures the window's
    /// own drawing through AppKit, which needs no screen-recording permission. Quits when done.
    @MainActor
    enum SnapshotTour {
        static var directory: URL? {
            ProcessInfo.processInfo.environment["STUDYBOT_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
        }

        /// `STUDYBOT_SNAPSHOT_TEXT_SIZE=accessibility5` pins a Dynamic Type size for the run, so
        /// §16's largest sizes can be judged without changing the Mac's own setting.
        static var textSize: ClosedRange<DynamicTypeSize>? {
            guard let raw = ProcessInfo.processInfo.environment["STUDYBOT_SNAPSHOT_TEXT_SIZE"] else {
                return nil
            }
            let sizes: [String: DynamicTypeSize] = [
                "large": .large, "xxxLarge": .xxxLarge, "accessibility1": .accessibility1,
                "accessibility3": .accessibility3, "accessibility5": .accessibility5,
            ]
            return sizes[raw].map { $0...$0 }
        }

        /// `STUDYBOT_SNAPSHOT_WINDOW=1080x600` sets the window size; the default is 1320×800.
        static var windowSize: NSSize {
            let raw = ProcessInfo.processInfo.environment["STUDYBOT_SNAPSHOT_WINDOW"] ?? ""
            let parts = raw.split(separator: "x").compactMap { Double($0) }
            guard parts.count == 2 else { return NSSize(width: 1320, height: 800) }
            return NSSize(width: parts[0], height: parts[1])
        }

        static func runIfRequested(model: AppModel) {
            guard let directory else { return }
            switch ProcessInfo.processInfo.environment["STUDYBOT_SNAPSHOT_APPEARANCE"] {
            case "dark": NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
            case "light": NSApplication.shared.appearance = NSAppearance(named: .aqua)
            default: break
            }
            Task { @MainActor in
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? await Task.sleep(for: .seconds(1))
                // A known size, so captures do not depend on a remembered window frame.
                NSApplication.shared.windows.first(where: { $0.isVisible })?
                    .setContentSize(windowSize)
                try? await Task.sleep(for: .seconds(0.5))
                await capture("1-first-run", to: directory)

                if case .firstRun = model.phase {
                    model.continueFromFirstRun()
                }
                try? await Task.sleep(for: .seconds(2.5))
                await capture("2-today", to: directory)

                model.selection = .assignments
                // The scope persists in Settings; start from the default so the footer shows.
                model.assignments?.scope = .currentTerm
                try? await Task.sleep(for: .seconds(1))
                await capture("3-assignments", to: directory)

                if let first = model.assignments?.visible.first {
                    model.open(first)
                    try? await Task.sleep(for: .seconds(1))
                    await capture("4-detail", to: directory)

                    model.beginEditingSelected()
                    try? await Task.sleep(for: .seconds(1))
                    await capture("5-editing", to: directory)
                    model.editor.discard()
                }

                model.assignments?.scope = .all
                try? await Task.sleep(for: .seconds(1))
                await capture("6-all-scope", to: directory)

                model.sidebarCollapsed = true
                try? await Task.sleep(for: .seconds(1))
                await capture("7-rail", to: directory)

                model.sidebarCollapsed = false
                model.closeDetail()
                model.selection = .today
                try? await Task.sleep(for: .seconds(1.5))
                await capture("8-today-again", to: directory)

                await captureCaptureSurfaces(model: model, directory: directory)
                await captureSettings(model: model, directory: directory)

                NSApplication.shared.terminate(nil)
            }
        }

        /// Modules & notes with a session open, then Block mode, the palette and evidence.
        private static func captureCaptureSurfaces(model: AppModel, directory: URL) async {

            let sample = ProcessInfo.processInfo.environment["STUDYBOT_SNAPSHOT_SAMPLE_NOTES"] != nil
            model.selection = .modules
            if let slot = model.sessionSlots.first(where: { $0.kind == .online }) {
                model.selectedSlotID = slot.id
                if sample, let notes = model.notes {
                    _ = await notes.open(slot, moduleID: model.moduleID(forCodes: slot.moduleCodes))
                    notes.updateLiveNotes(
                        slot.id,
                        text: """
                            - sets, relations, functions
                            - a relation is a subset of A × B
                            - ASK: does the exam expect proofs or just definitions
                            transitive closure: keep adding until nothing changes
                            - ASK: which textbook chapter covers this

                            """)
                }
            }
            try? await Task.sleep(for: .seconds(1.5))
            await capture("10-notes", to: directory)

            model.enterBlockMode()
            if sample, let notes = model.notes, let block = model.blockMode {
                let days = SessionCatalog.days(of: block, in: model.events)
                for slot in days.flatMap(\.slots) {
                    _ = await notes.open(slot, moduleID: model.moduleID(forCodes: slot.moduleCodes))
                }
                if let induction = days.first?.slots.first {
                    notes.append("bring the enrolment letter", asQuestion: false, to: induction.id)
                    notes.append(
                        "how do off-the-job hours get evidenced", asQuestion: true, to: induction.id)
                    model.selectedSlotID = induction.id
                }
                if let dayTwo = days.dropFirst().first?.slots.first {
                    notes.append(
                        "is the Programming coursework individual or paired", asQuestion: true,
                        to: dayTwo.id)
                }
            }
            try? await Task.sleep(for: .seconds(1.5))
            await capture("11-block", to: directory)
            model.leaveBlockMode()

            model.selection = .today
            model.paletteShown = true
            try? await Task.sleep(for: .seconds(1.2))
            await capture("12-palette", to: directory)
            model.paletteShown = false

            model.beginEvidence(source: .lecture)
            try? await Task.sleep(for: .seconds(1.5))
            await capture("13-evidence", to: directory)
            model.evidenceDraft = nil
            try? await Task.sleep(for: .seconds(0.5))

            // Hours: a few entries so the week bar has heights, then the field itself.
            if sample, let hours = model.hours {
                let today = LocalDay(model.now())
                let monday = today.adding(days: -(today.isoWeekday - 1))
                _ = await hours.log("1h30 lecture: networks", on: monday)
                _ = await hours.log("2h project work: rewrote the pipeline checks", on: monday.adding(days: 1))
                _ = await hours.log("45m mentoring with Sam")
                model.refreshPlan()
            }
            model.showHoursField()
            try? await Task.sleep(for: .seconds(1.2))
            await capture("14-hours", to: directory)
            model.hoursFieldShown = false
            try? await Task.sleep(for: .seconds(0.5))

        }

        /// The Settings scene has no programmatic opener the tour can reach, so show the same
        /// view in a plain window for the capture.
        private static func captureSettings(model: AppModel, directory: URL) async {
            // The Settings scene has no programmatic opener the tour can reach, so show the
            // same view in a plain window for the capture.
            let settings = NSWindow(
                contentViewController: NSHostingController(
                    rootView: SettingsView().environment(model)
                        .dynamicTypeSize(
                            textSize ?? DynamicTypeSize.xSmall...DynamicTypeSize.accessibility5)))
            settings.title = "Settings"
            settings.setContentSize(NSSize(width: 620, height: 480))
            settings.center()
            settings.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for: .seconds(1.5))
            await capture("9-settings", to: directory, preferring: "Settings")
            settings.close()
        }

        /// For other debug runners: one external capture of the main window.
        static func captureExternally(_ name: String, to directory: URL) async {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            await waitForExternalCapture(name, in: directory, preferring: nil)
        }

        /// `preferring` names a window by title (the Settings window) instead of the key one.
        private static func capture(_ name: String, to directory: URL, preferring title: String? = nil) async
        {
            if ProcessInfo.processInfo.environment["STUDYBOT_SNAPSHOT_EXTERNAL"] != nil {
                await waitForExternalCapture(name, in: directory, preferring: title)
            } else {
                renderLayerTree(name, to: directory)
            }
        }

        private static func waitForExternalCapture(
            _ name: String, in directory: URL, preferring title: String?
        )
            async
        {
            let ready = directory.appendingPathComponent("\(name).ready")
            let done = directory.appendingPathComponent("\(name).done")
            let visible = NSApplication.shared.windows.filter(\.isVisible)
            let titled = title.flatMap { wanted in
                visible.first { $0.title.localizedCaseInsensitiveContains(wanted) }
            }
            let window = titled ?? NSApplication.shared.keyWindow ?? visible.first
            let windowNumber = window?.windowNumber ?? 0
            try? "\(windowNumber)".write(to: ready, atomically: true, encoding: .utf8)
            for _ in 0..<150 where !FileManager.default.fileExists(atPath: done.path) {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        private static func renderLayerTree(_ name: String, to directory: URL) {
            guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }),
                let view = window.contentView, let layer = view.layer
            else { return }
            let scale = window.backingScaleFactor
            let size = view.bounds.size
            guard
                let context = CGContext(
                    data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
                    bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            // The layer tree renders bottom-up into a top-down bitmap; flip so the PNG reads normally.
            context.translateBy(x: 0, y: size.height * scale)
            context.scaleBy(x: scale, y: -scale)
            view.displayIfNeeded()
            layer.render(in: context)
            guard let image = context.makeImage() else { return }
            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
#endif
