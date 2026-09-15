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
                    .setContentSize(NSSize(width: 1320, height: 800))
                try? await Task.sleep(for: .seconds(0.5))
                await capture("1-first-run", to: directory)

                if case .firstRun = model.phase {
                    model.continueFromFirstRun()
                }
                try? await Task.sleep(for: .seconds(2.5))
                await capture("2-today", to: directory)

                model.selection = .assignments
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

                NSApplication.shared.terminate(nil)
            }
        }

        /// Renders the window's layer tree, which includes layer-backed AppKit controls that
        /// `cacheDisplay` misses. Needs no screen-recording permission. Behind-window vibrancy
        /// cannot be rendered this way, so the sidebar shows its fallback material.
        private static func capture(_ name: String, to directory: URL) async {
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
