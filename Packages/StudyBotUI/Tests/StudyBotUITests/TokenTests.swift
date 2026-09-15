import StudyBotCore
import SwiftUI
import Testing

@testable import StudyBotUI

/// §0: "Do not invent these — design tokens and component values (§9)." Pins the values.
@Suite("Design tokens match §9")
struct TokenTests {
    private func hex(_ color: Color) -> String {
        let resolved = color.resolve(in: EnvironmentValues())
        func channel(_ value: Float) -> String {
            String(format: "%02X", Int((value * 255).rounded()))
        }
        return "#" + channel(resolved.red) + channel(resolved.green) + channel(resolved.blue)
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

    @Test("status labels always accompany the icon")
    func statusLabels() {
        #expect(
            AssignmentStatus.allCases.map(StatusIcon.label(for:)) == [
                "Backlog", "Todo", "Drafting", "In review", "Submitted", "Graded",
            ])
    }
}
