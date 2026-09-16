import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// Modules & notes (§6.3): the current term's modules, each expanding to its sessions in date
/// order; a session opens into the note workspace beside it. The tree lives in this screen's
/// own column rather than the sidebar (see docs/decisions.md).
struct ModulesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale

    var body: some View {
        HStack(spacing: 0) {
            list
                .frame(width: scale.isAccessibility && model.selectedSlotID != nil ? 0 : scale(320))
                .clipped()
            if model.selectedSlotID != nil {
                SBColor.border.frame(width: 1)
            }
            if let id = model.selectedSlotID, let slot = model.slot(id: id) {
                NoteWorkspaceView(slot: slot)
                    .id(slot.id)
                    .frame(maxWidth: .infinity)
            } else {
                EmptyState("Pick a session to take notes. Type. Sort it out later.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(SBColor.surface)
    }

    private var list: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Modules & notes") { EmptyView() }
            ScrollView {
                LazyVStack(spacing: 0) {
                    let modules = model.currentTermModules
                    if modules.isEmpty {
                        EmptyState("No modules in this term yet.")
                    }
                    ForEach(modules) { module in
                        SectionHeader(
                            module.name,
                            count: model.sessionSlots.filter { $0.moduleCodes.contains(module.code) }.count,
                            isCollapsed: collapsedBinding(module.id),
                            accent: isExpanded(module.id) ? SBColor.module(module.colour) : nil)
                        if isExpanded(module.id) {
                            ForEach(SessionCatalog.slots(in: model.events, moduleCode: module.code)) { slot in
                                row(slot)
                            }
                        }
                    }
                }
            }
        }
    }

    private func row(_ slot: SessionSlot) -> some View {
        let session = model.notes?.session(for: slot)
        return ListRow(isSelected: model.selectedSlotID == slot.id) {
            model.selectedSlotID = slot.id
        } content: {
            Circle()
                .fill(session?.countsAsAttended == true ? SBColor.accent : Color.clear)
                .overlay(Circle().strokeBorder(SBColor.borderStrong, lineWidth: 1))
                .frame(width: 8, height: 8)
                .accessibilityLabel(session?.countsAsAttended == true ? "Has notes" : "No notes yet")
            Text(slot.title)
                .sbType(SBType.row)
                .foregroundStyle(SBColor.textPrimary)
                .lineLimit(scale.isAccessibility ? 2 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(RelativeDate.absolute(slot.day.date, relativeTo: model.now()))
                .sbFont(12)
                .foregroundStyle(SBColor.textSecondary)
                .monospacedDigit()
        }
    }

    /// The module for today's session starts expanded; the rest start collapsed.
    private func isExpanded(_ moduleID: UUID) -> Bool {
        model.selectedModuleID == moduleID
            || (model.selectedModuleID == nil && moduleID == model.currentTermModules.first?.id)
    }

    private func collapsedBinding(_ moduleID: UUID) -> Binding<Bool> {
        Binding(
            get: { !isExpanded(moduleID) },
            set: { collapsed in
                withSBAnimation(SBMotion.collapse) {
                    model.selectedModuleID = collapsed ? UUID() : moduleID
                }
            })
    }
}
