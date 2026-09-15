import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// The Assignments screen (§6.2): the list, and the detail panel sliding in from the right
/// when a row is open.
struct AssignmentsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            if let store = model.assignments {
                AssignmentsList(store: store)
                    .frame(minWidth: 420, maxWidth: .infinity)
                if let assignment = model.selectedAssignment {
                    SBColor.border.frame(width: 1)
                    AssignmentDetailView(assignment: assignment, store: store)
                        .frame(width: 440)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(SBMotion.detailPanel, value: model.selectedAssignmentID != nil)
        .background(SBColor.surface)
    }
}

/// The grouped list with the scope control and the hidden-count footer.
private struct AssignmentsList: View {
    @Environment(AppModel.self) private var model
    @Bindable var store: AssignmentStore
    @State private var collapsed: Set<AssignmentStatus> = []
    @State private var pendingDelete: Assignment?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Assignments") {
                // At the minimum window width with the panel open there is no room for every
                // control; the module filter goes first, since every day-one stub has no module.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        scopePicker
                        modulePicker
                        newButton
                    }
                    HStack(spacing: 8) {
                        scopePicker
                        newButton
                    }
                }
            }

            if let error = store.lastError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(SBColor.danger)
                    .padding(.vertical, 8)
                    .padding(.horizontal, SBSpacing.rowHorizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    if store.groups.isEmpty {
                        emptyState
                    }
                    ForEach(store.groups) { group in
                        SectionHeader(
                            StatusIcon.label(for: group.status),
                            count: group.assignments.count,
                            isCollapsed: collapsedBinding(group.status))
                        if !collapsed.contains(group.status) {
                            ForEach(group.assignments) { assignment in
                                row(assignment)
                            }
                        }
                    }
                    if store.hiddenCount > 0 {
                        footer
                    }
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { move(-1) }
        .onKeyPress(.downArrow) { move(1) }
        .onKeyPress(.return) {
            guard let assignment = model.selectedAssignment ?? store.visible.first else { return .ignored }
            model.open(assignment)
            return .handled
        }
        .onKeyPress(characters: .init(charactersIn: "c"), phases: .down) { _ in
            guard !model.editor.isEditing else { return .ignored }
            Task { await model.createAssignment() }
            return .handled
        }
        .onDeleteCommand {
            guard !model.editor.isEditing, let assignment = model.selectedAssignment else { return }
            pendingDelete = assignment
        }
        .confirmationDialog(
            "Delete this assignment?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let assignment = pendingDelete else { return }
                Task {
                    await store.delete(assignment.id)
                    model.closeDetail()
                }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(
                "It is removed from this Mac and, once syncing, from the other. Notes and files attached to it go with it."
            )
        }
    }

    // MARK: Header controls

    private var newButton: some View {
        Btn.primary("New", icon: "plus", size: .small) {
            Task { await model.createAssignment() }
        }
    }

    private var scopePicker: some View {
        Picker("Scope", selection: $store.scope) {
            Text("Current term").tag(AssignmentListScope.currentTerm)
            Text("Current year").tag(AssignmentListScope.currentYear)
            Text("All").tag(AssignmentListScope.all)
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel("Scope")
    }

    private var modulePicker: some View {
        Picker("Module", selection: $store.moduleFilter) {
            Text("All modules").tag(UUID?.none)
            ForEach(store.assignableModules) { module in
                Text(module.shortCode).tag(Optional(module.id))
            }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .labelsHidden()
        .frame(width: 132)
        .accessibilityLabel("Module")
    }

    // MARK: Rows

    private func row(_ assignment: Assignment) -> some View {
        ListRow(isSelected: model.selectedAssignmentID == assignment.id) {
            model.open(assignment)
        } content: {
            StatusIcon(assignment.status)
            Text(assignment.title)
                .sbType(SBType.row)
                .italic(assignment.isCalendarStub)
                .foregroundStyle(assignment.isCalendarStub ? SBColor.textSecondary : SBColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            ModuleChip(store.module(for: assignment)).frame(width: 58, alignment: .leading)
            PriorityBars(assignment.priority)
            DueDateLabel(assignment.dueDate, now: model.now()).frame(width: 96, alignment: .trailing)
            trailingColumn(assignment).frame(width: 56, alignment: .trailing)
        }
        .contextMenu {
            Button("Edit") {
                model.open(assignment)
                model.beginEditingSelected()
            }
            Button("Delete…", role: .destructive) {
                model.open(assignment)
                pendingDelete = assignment
            }
        }
    }

    /// Progress while drafting, the grade once graded, otherwise nothing.
    @ViewBuilder
    private func trailingColumn(_ assignment: Assignment) -> some View {
        if let grade = assignment.grade {
            GradeBadge(grade, bands: store.settings.gradeBands)
        } else if let limit = assignment.wordLimit, limit > 0, let words = assignment.draftText?.wordCount,
            words > 0
        {
            ProgressBar(Double(words) / Double(limit), width: 44)
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    // MARK: Footer and empty state

    /// "18 more submissions in later terms. Show all" (§6.2). Nothing is hidden without being
    /// acknowledged, and "Show all" is the only way to reach the hidden ones, so it reads as an
    /// action in `accent` rather than as more grey text.
    private var footer: some View {
        Button {
            store.scope = .all
        } label: {
            HStack(spacing: 4) {
                Text(footerText)
                    .foregroundStyle(SBColor.textTertiary)
                Text("Show all")
                    .foregroundStyle(SBColor.accent)
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, SBSpacing.rowHorizontal)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(footerText) Show all")
    }

    private var footerText: String {
        let location = store.hiddenAreAllLater ? "later terms" : "other terms"
        let noun = store.hiddenCount == 1 ? "submission" : "submissions"
        return "\(store.hiddenCount) more \(noun) in \(location)."
    }

    private var emptyState: some View {
        EmptyState(
            store.moduleFilter == nil
                ? "No submissions this term. Show all \(store.assignments.count)."
                : "No assignments for this module in this scope.",
            actionTitle: store.moduleFilter == nil ? "Show all" : "All modules"
        ) {
            if store.moduleFilter == nil { store.scope = .all } else { store.moduleFilter = nil }
        }
    }

    // MARK: Helpers

    private func collapsedBinding(_ status: AssignmentStatus) -> Binding<Bool> {
        Binding(
            get: { collapsed.contains(status) },
            set: { isCollapsed in
                withAnimation(SBMotion.collapse) {
                    if isCollapsed { collapsed.insert(status) } else { collapsed.remove(status) }
                }
            })
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        let visible = store.groups.flatMap(\.assignments)
        guard !visible.isEmpty else { return .ignored }
        let currentIndex = visible.firstIndex { $0.id == model.selectedAssignmentID }
        let nextIndex = min(
            max((currentIndex ?? (delta > 0 ? -1 : visible.count)) + delta, 0), visible.count - 1)
        model.open(visible[nextIndex])
        return .handled
    }
}

extension String {
    /// Words as a draft's word count sees them.
    var wordCount: Int {
        split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
