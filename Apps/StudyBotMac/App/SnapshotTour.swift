#if DEBUG
    import AppKit
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

                // The Settings scene has no programmatic opener the tour can reach, so show the
                // same view in a plain window for the capture.
                let settings = NSWindow(
                    contentViewController: NSHostingController(rootView: SettingsView().environment(model)))
                settings.title = "Settings"
                settings.setContentSize(NSSize(width: 620, height: 480))
                settings.center()
                settings.makeKeyAndOrderFront(nil)
                try? await Task.sleep(for: .seconds(1.5))
                await capture("9-settings", to: directory, preferring: "Settings")
                settings.close()

                NSApplication.shared.terminate(nil)
            }
        }

        /// Two ways to capture. With `STUDYBOT_SNAPSHOT_EXTERNAL` set, the tour writes
        /// `<name>.ready`, waits for an outside process (`Tools/screenshots.sh`) to take a real
        /// screenshot and touch `<name>.done`, then moves on: that path shows exactly what is on
        /// screen, vibrancy and scroll views included, but needs Screen Recording permission for
        /// the shell running the script. Otherwise the window's layer tree is rendered, which
        /// needs no permission but cannot show behind-window blending.
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
