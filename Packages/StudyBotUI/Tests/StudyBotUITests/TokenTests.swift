import AppKit
import StudyBotCore
import SwiftUI
import Testing

@testable import StudyBotUI

/// §0: "Do not invent these — design tokens and component values (§9)." Pins the values.
@MainActor
@Suite("Design tokens match §9")
struct TokenTests {
    /// The token's hex under an appearance. Adaptive tokens resolve through AppKit.
    private func hex(_ color: Color, appearance: NSAppearance.Name = .aqua) -> String {
        guard let named = NSAppearance(named: appearance) else { return "?" }
        var result = "?"
        named.performAsCurrentDrawingAppearance {
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            func channel(_ value: CGFloat) -> String { String(format: "%02X", Int((value * 255).rounded())) }
            result =
                "#" + channel(rgb.redComponent) + channel(rgb.greenComponent) + channel(rgb.blueComponent)
        }
        return result
    }

    @Test("colour tokens")
    func colours() {
        #expect(hex(SBColor.canvas) == "#FBFBFA")
        #expect(hex(SBColor.surface) == "#FFFFFF")
        #expect(hex(SBColor.border) == "#E8E8E6")
        #expect(hex(SBColor.borderStrong) == "#D4D4D1")
        #expect(hex(SBColor.textPrimary) == "#1D1D1F")
        #expect(hex(SBColor.textSecondary) == "#6E6E73")
        #expect(hex(SBColor.textTertiary) == "#A1A1A6")
        #expect(hex(SBColor.accent) == "#5E6AD2")
        #expect(hex(SBColor.accentSoft) == "#EEF0FB")
        #expect(hex(SBColor.statusBacklog) == "#A1A1A6")
        #expect(hex(SBColor.statusTodo) == "#6E6E73")
        #expect(hex(SBColor.statusDrafting) == "#D9A441")
        #expect(hex(SBColor.statusReview) == "#5E6AD2")
        #expect(hex(SBColor.statusDone) == "#4A9E6B")
        #expect(hex(SBColor.danger) == "#C4483D")
        #expect(hex(SBColor.module(.indigo)) == "#5E6AD2")
        #expect(hex(SBColor.module(.slate)) == "#6B7280")
        #expect(hex(Color(hex: "garbage")) == "#000000", "a malformed hex is loud, not silent")
    }

    @Test("every adaptive token has a distinct dark value and text stays legible on canvas")
    func darkTokens() {
        #expect(hex(SBColor.canvas, appearance: .darkAqua) == "#1A1A1C")
        #expect(hex(SBColor.surface, appearance: .darkAqua) == "#202023")
        #expect(hex(SBColor.textPrimary, appearance: .darkAqua) == "#EDEDEF")
        #expect(hex(SBColor.accent, appearance: .darkAqua) == "#7B86E2")
        #expect(hex(SBColor.danger, appearance: .darkAqua) == "#E0655B")
        #expect(hex(SBColor.canvas, appearance: .darkAqua) != hex(SBColor.canvas))
        #expect(hex(SBColor.textPrimary, appearance: .darkAqua) != hex(SBColor.textPrimary))
        #expect(
            hex(SBColor.module(.indigo), appearance: .darkAqua) == "#5E6AD2", "module colours do not change")
    }

    @Test("status and band colours map as §6.2 and §9 say")
    func semanticMapping() {
        #expect(hex(SBColor.status(.submitted)) == hex(SBColor.statusDone))
        #expect(hex(SBColor.status(.graded)) == hex(SBColor.statusDone))
        #expect(hex(SBColor.status(.review)) == hex(SBColor.accent))
        #expect(hex(SBColor.band(.green)) == hex(SBColor.statusDone))
        #expect(hex(SBColor.band(.indigo)) == hex(SBColor.accent))
        #expect(hex(SBColor.band(.grey)) == hex(SBColor.textSecondary))
        #expect(hex(SBColor.band(.red)) == hex(SBColor.danger))
    }

    @Test("type scale")
    func typeScale() {
        #expect(
            SBType.display.size == 28 && SBType.display.weight == .semibold
                && SBType.display.trackingEm == -0.02)
        #expect(
            SBType.title.size == 20 && SBType.title.weight == .semibold && SBType.title.trackingEm == -0.01)
        #expect(SBType.section.size == 15 && SBType.section.weight == .medium)
        #expect(SBType.body.size == 13 && SBType.body.weight == .regular)
        #expect(SBType.row.size == 13 && SBType.rowEmphasis.weight == .medium)
        #expect(SBType.meta.size == 12)
        #expect(SBType.micro.size == 11 && SBType.micro.weight == .medium && SBType.micro.trackingEm == 0.01)
        #expect(SBType.display.trackingPoints == 28 * -0.02)
        #expect(SBType.longFormMeasure == 68 && SBType.liveNotesMeasure == 66)
    }

    @Test("the type scale follows the Dynamic Type size and graphic elements do not")
    func dynamicTypeScale() {
        #expect(SBType.scale(for: .large) == 1)
        #expect(SBScale(.large)(13) == 13)
        let ordered: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge, .accessibility1, .accessibility2,
            .accessibility3, .accessibility4, .accessibility5,
        ]
        let factors = ordered.map(SBType.scale(for:))
        #expect(factors == factors.sorted(), "monotonic")
        #expect(SBType.scale(for: .accessibility5) > 3, "the largest size triples text")
        #expect(SBScale(.accessibility5)(13) == 40.5, "half-point rounding")
        #expect(SBScale(.accessibility1).isAccessibility && !SBScale(.xxxLarge).isAccessibility)
        #expect(SBType.body.font(at: SBScale(.accessibility5)) != SBType.body.font)
        // Sidebar grows with text but no further than half again; the rail never moves.
        #expect(SBSpacing.sidebarWidth(at: SBScale(.large)) == 228)
        #expect(SBSpacing.sidebarWidth(at: SBScale(.accessibility5)) == 410)
        #expect(SBSpacing.sidebarRailWidth == 56)
        #expect(PriorityBars.width == 18 && TermStripView.height == 28)
    }

    @Test("spacing, radius and layout constants")
    func spacing() {
        #expect(
            [
                SBSpacing.x1, SBSpacing.x2, SBSpacing.x3, SBSpacing.x4, SBSpacing.x6, SBSpacing.x8,
                SBSpacing.x12,
            ] == [4, 8, 12, 16, 24, 32, 48])
        #expect(SBSpacing.rowInset == 16 && SBSpacing.region == 24 && SBSpacing.detailOuter == 32)
        #expect(SBSpacing.rowHeight == 38 && SBSpacing.rowHorizontal == 20)
        #expect(
            SBSpacing.sidebarWidth == 228 && SBSpacing.sidebarRailWidth == 56
                && SBSpacing.sidebarRowHeight == 28)
        #expect(SBRadius.control == 6 && SBRadius.button == 7 && SBRadius.card == 10 && SBRadius.sheet == 14)
        #expect(SBRadius.pill == 999)
    }

    @Test("motion follows the §9 table: instant under the cursor, springs and eases elsewhere")
    func motion() {
        #expect(SBMotion.hover == nil, "row hover and selection have no transition at all")
        #expect(SBMotion.buttonHover == SBMotion.Spec(0.10, .ease))
        #expect(SBMotion.buttonPress == SBMotion.Spec(0.06, .easeOut))
        #expect(SBMotion.rowMove == SBMotion.Spec(0.28, .spring(damping: 0.86)))
        #expect(SBMotion.rowRemove == SBMotion.Spec(0.20, .easeOut))
        #expect(SBMotion.rowInsert.duration == 0.24 && SBMotion.rowInsert.isSpring)
        #expect(SBMotion.collapse == SBMotion.Spec(0.20, .ease))
        #expect(SBMotion.count.duration == 0.18)
        #expect(SBMotion.detailPanel == SBMotion.Spec(0.26, .spring(damping: 0.88)))
        #expect(SBMotion.palette.duration == 0.18 && SBMotion.palette.isSpring)
        #expect(SBMotion.popover.duration == 0.14 && SBMotion.popover.isSpring)
        #expect(SBMotion.progressBar == SBMotion.Spec(0.40, .easeOut))
        #expect(SBMotion.hoursBar == SBMotion.Spec(0.50, .spring(damping: 0.8)))
        #expect(SBMotion.segment.duration == 0.22 && SBMotion.segment.isSpring)
        #expect(SBMotion.flip == SBMotion.Spec(0.42, .easeInOut))
        #expect(SBMotion.sidebar.duration == 0.22 && SBMotion.sidebarLabel.duration == 0.08)
        #expect(SBMotion.reduced == SBMotion.Spec(0.10, .easeInOut))
        // Everything a person points at responds in under 100ms.
        #expect(SBMotion.buttonHover.duration <= 0.10 && SBMotion.buttonPress.duration <= 0.10)
        // Reduce Motion: every spring becomes the crossfade.
        #expect(SBMotion.honouring(true, SBMotion.rowMove) == SBMotion.reduced.animation)
        #expect(SBMotion.honouring(false, SBMotion.rowMove) == SBMotion.rowMove.animation)
    }

    @Test("status labels always accompany the icon")
    func statusLabels() {
        #expect(
            AssignmentStatus.allCases.map(StatusIcon.label(for:)) == [
                "Backlog", "Todo", "Drafting", "In review", "Submitted", "Graded",
            ])
    }
}
