import AppKit
import Foundation

/// The bare `L` (Today, "One keystroke to log"): opens the hours field from anywhere in the
/// main window, unless the person is typing. A bare letter cannot live in a menu without
/// swallowing it from every text field, so this watches key events instead; ⌘L in the menu
/// is the discoverable twin (§10).
@MainActor
final class KeyMonitor {
    private var monitor: Any?

    init(model: AppModel) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // The event is read here; only the decision crosses into the main actor.
            let isLetter = KeyMonitor.isBareLetter(event, "l")
            let consumed = MainActor.assumeIsolated {
                guard isLetter, KeyMonitor.canOpenHoursField(model) else { return false }
                model.showHoursField()
                return true
            }
            return consumed ? nil : event
        }
    }

    /// Stops watching. The app keeps one monitor for its whole life, so this is for tests
    /// and for a monitor that is replaced.
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// The letter with no modifier but, at most, shift.
    static func isBareLetter(_ event: NSEvent, _ letter: String) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .function])
        return modifiers.isEmpty && event.charactersIgnoringModifiers?.lowercased() == letter
    }

    /// Only when nothing else is taking keystrokes: no text field first, no palette, no sheet.
    static func canOpenHoursField(_ model: AppModel) -> Bool {
        guard model.phase == .ready, !model.paletteShown, !model.hoursFieldShown, model.evidenceDraft == nil,
            model.explanation == nil, let window = NSApp.keyWindow, window.attachedSheet == nil
        else { return false }
        if window.firstResponder is NSText { return false }
        // Only the main window: Settings and sheets have their own fields.
        return window.title == "StudyBot" || window.title.isEmpty
    }
}
