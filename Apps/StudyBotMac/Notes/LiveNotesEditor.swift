import AppKit
import StudyBotKit
import StudyBotUI
import SwiftUI

/// The live notes editor (§6.3): a plain `NSTextView` with attributed-string styling applied
/// in place. Styling changes colour, background and left decoration only, never font size,
/// weight or character count, so the caret lands exactly where it looks like it should.
/// Restyling happens per edited paragraph, not per document (§3.9).
///
/// TextKit 1 on purpose: the bullet glyph and the `ASK:` band are drawn by a layout manager
/// subclass, which TextKit 2 does not offer.
struct LiveNotesEditor: NSViewRepresentable {
    @Binding var text: String
    let scale: SBScale
    let onChange: (String) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layoutManager = LiveNotesLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = NSTextView(frame: .zero, textContainer: container)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.usesFontPanel = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: scale(SBSpacing.liveNotesInset), height: scale(20))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        storage.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.styler = LiveNotesStyler(scale: scale)
        textView.typingAttributes = context.coordinator.styler.baseAttributes
        textView.insertionPointColor = NSColor(SBColor.accent)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        context.coordinator.replaceText(text)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onChange = onChange
        if coordinator.styler.scale != scale, let textView = coordinator.textView {
            coordinator.styler = LiveNotesStyler(scale: scale)
            textView.textContainerInset = NSSize(width: scale(SBSpacing.liveNotesInset), height: scale(20))
            textView.typingAttributes = coordinator.styler.baseAttributes
            coordinator.restyleAll()
        }
        if let textView = coordinator.textView, textView.string != text, !coordinator.isEditing {
            coordinator.replaceText(text)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, styler: LiveNotesStyler(scale: scale))
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency NSTextViewDelegate,
        @preconcurrency NSTextStorageDelegate
    {
        var onChange: (String) -> Void
        var styler: LiveNotesStyler
        weak var textView: NSTextView?
        /// True while the user's own edit is being processed, so `updateNSView` does not
        /// write the same text back and move the caret.
        private(set) var isEditing = false

        init(onChange: @escaping (String) -> Void, styler: LiveNotesStyler) {
            self.onChange = onChange
            self.styler = styler
        }

        func replaceText(_ text: String) {
            guard let textView, let storage = textView.textStorage else { return }
            let selected = textView.selectedRange()
            storage.beginEditing()
            storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
            storage.endEditing()
            restyleAll()
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selected.location, length), length: 0))
        }

        func restyleAll() {
            guard let storage = textView?.textStorage else { return }
            styler.restyle(storage, in: NSRange(location: 0, length: storage.length))
        }

        // The edit's paragraphs, and only those, are restyled: diff by line (§3.9).
        func textStorage(
            _ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange, changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            let paragraphs = (textStorage.string as NSString).paragraphRange(for: editedRange)
            styler.restyle(textStorage, in: paragraphs)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            isEditing = true
            onChange(textView.string)
            isEditing = false
        }
    }
}

/// The attributes for each kind of line. One place, so the mirror rule (§6.3) is checkable:
/// every attribute set here is colour, background or a marker for the layout manager.
struct LiveNotesStyler {
    let scale: SBScale

    static let lineKind = NSAttributedString.Key("studybot.lineKind")
    /// Marks the one `-` character a bullet is drawn over.
    static let bulletDash = NSAttributedString.Key("studybot.bulletDash")

    var font: NSFont { .systemFont(ofSize: scale(SBType.liveNotesSize)) }

    var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.7
        style.paragraphSpacing = 0
        return style
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: NSColor(SBColor.textPrimary), .paragraphStyle: paragraphStyle]
    }

    func restyle(_ storage: NSTextStorage, in range: NSRange) {
        guard range.length > 0 || storage.length == 0 else { return }
        let text = storage.string as NSString
        let slice = text.substring(with: range)
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: range)
        for line in LiveNoteParser.lines(in: slice) where line.range.length > 0 {
            let lineRange = NSRange(location: range.location + line.range.location, length: line.range.length)
            switch line.kind {
            case .plain:
                continue
            case .bullet:
                storage.addAttribute(Self.lineKind, value: "bullet", range: lineRange)
                if let marker = line.markerRange {
                    // The dash stays in the text and the layout manager draws a bullet over it.
                    let dash = NSRange(location: range.location + marker.location, length: 1)
                    storage.addAttribute(Self.bulletDash, value: true, range: dash)
                    storage.addAttribute(.foregroundColor, value: NSColor.clear, range: dash)
                }
            case .question:
                storage.addAttribute(Self.lineKind, value: "question", range: lineRange)
                storage.addAttribute(.foregroundColor, value: NSColor(SBColor.accent), range: lineRange)
                // "- ASK:" keeps its bullet, drawn in accent.
                let leading =
                    (text.substring(with: lineRange) as NSString).length
                    - (text.substring(with: lineRange).drop(while: \.isWhitespace) as NSString).length
                if (text.substring(with: lineRange).drop(while: \.isWhitespace)).hasPrefix("- ") {
                    storage.addAttribute(
                        Self.bulletDash, value: true,
                        range: NSRange(location: lineRange.location + leading, length: 1))
                    storage.addAttribute(
                        .foregroundColor, value: NSColor.clear,
                        range: NSRange(location: lineRange.location + leading, length: 1))
                }
            }
        }
        storage.endEditing()
    }
}

/// Draws what attributes cannot: the bullet glyph in place of `-`, and the `ASK:` band with
/// its 2pt accent rule across the full width of the line.
final class LiveNotesLayoutManager: NSLayoutManager {
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, let container = textContainers.first else { return }
        let characters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        storage.enumerateAttribute(LiveNotesStyler.lineKind, in: characters) { value, range, _ in
            guard value as? String == "question" else { return }
            let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var band = CGRect.null
            enumerateLineFragments(forGlyphRange: glyphs) { rect, _, _, _, _ in
                band = band.union(rect)
            }
            guard !band.isNull else { return }
            let full = CGRect(
                x: origin.x, y: band.minY + origin.y, width: container.size.width, height: band.height)
            NSColor(SBColor.accentSoft).setFill()
            full.fill()
            NSColor(SBColor.accent).setFill()
            CGRect(x: full.minX, y: full.minY, width: 2, height: full.height).fill()
        }
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage else { return }
        let characters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        storage.enumerateAttribute(LiveNotesStyler.bulletDash, in: characters) { value, range, _ in
            guard value as? Bool == true else { return }
            let glyph = glyphIndexForCharacter(at: range.location)
            guard glyph < numberOfGlyphs else { return }
            let lineRect = lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let glyphLocation = location(forGlyphAt: glyph)
            let dashWidth = boundingRect(
                forGlyphRange: NSRange(location: glyph, length: 1), in: textContainers[0]
            ).width
            let font =
                (storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont)
                ?? .systemFont(ofSize: 15)
            let isQuestion =
                storage.attribute(LiveNotesStyler.lineKind, at: range.location, effectiveRange: nil)
                as? String == "question"
            let colour = NSColor(isQuestion ? SBColor.accent : SBColor.textTertiary)
            let bullet = NSAttributedString(string: "•", attributes: [.font: font, .foregroundColor: colour])
            let size = bullet.size()
            // Sit the bullet on the dash's baseline, centred over the dash.
            let baseline = lineRect.minY + glyphLocation.y
            let point = NSPoint(
                x: lineRect.minX + glyphLocation.x + (dashWidth - size.width) / 2 + origin.x,
                y: baseline - font.ascender + origin.y)
            bullet.draw(at: point)
        }
    }
}
