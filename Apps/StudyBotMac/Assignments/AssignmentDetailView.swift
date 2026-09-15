import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// The detail panel (§6.2 "Assignment detail"). Read-only by default; a primary Edit button
/// makes the whole panel editable at once; Cancel and Save changes replace it; Save writes
/// once. The draft is the exception and stays directly editable. Sections in the spec's order:
/// title and module, status/priority/due date, brief, rubric, draft, grade and feedback.
struct AssignmentDetailView: View {
    @Environment(AppModel.self) private var model
    let assignment: Assignment
    @Bindable var store: AssignmentStore

    @State private var draftText: String = ""
    @State private var draftSaveTask: Task<Void, Never>?
    @Environment(\.sbScale) private var scale

    private var editor: AssignmentEditor { model.editor }
    private var isEditing: Bool { editor.isEditing && editor.draft?.id == assignment.id }
    /// What the panel shows: the editing copy while editing, the saved value otherwise.
    private var shown: Assignment { isEditing ? (editor.draft ?? assignment) : assignment }

    var body: some View {
        @Bindable var editor = model.editor
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock
                    chips.padding(.top, 16)
                    Field("Brief", hint: shown.briefText == nil ? "not published yet" : nil) { brief }
                    Field(
                        "Rubric",
                        hint: shown.rubricText?.isEmpty ?? true
                            ? "needed before the checker can mark anything" : nil
                    ) {
                        rubric
                    }
                    Field("Draft", hint: draftHint) { draft }
                    Field("Grade and feedback", hint: nil) { gradeAndFeedback }
                    actions.padding(.top, 22)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 48)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(SBColor.surface)
        .onAppear { draftText = assignment.draftText ?? "" }
        .onChange(of: assignment.id) { _, _ in draftText = assignment.draftText ?? "" }
        .confirmationDialog(
            "Discard changes to this assignment?", isPresented: $editor.isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard changes", role: .destructive) { editor.discard() }
            Button("Keep editing", role: .cancel) { editor.isConfirmingDiscard = false }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            ModuleChip(store.module(for: shown))
            Spacer(minLength: 0)
            if isEditing {
                Btn.secondary("Cancel", size: .small) { editor.requestCancel() }
                Btn.primary("Save changes", icon: "checkmark", size: .small) {
                    Task { await model.saveEditing() }
                }
            } else {
                Btn.primary("Edit", icon: "pencil", size: .small) { model.beginEditingSelected() }
            }
            Button {
                model.escape()
            } label: {
                Image(systemName: "xmark")
                    .sbFont(12, weight: .medium)
                    .foregroundStyle(SBColor.textTertiary)
                    .frame(width: scale(20), height: scale(20))
            }
            .buttonStyle(.plain)
            .help(isEditing ? "Cancel (⎋)" : "Close (⎋)")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }
    }

    // MARK: Title and module

    @ViewBuilder
    private var titleBlock: some View {
        if isEditing {
            TextField("Title", text: field(\.title, default: ""), axis: .vertical)
                .lineLimit(1...3)
                .sbFont(17, weight: .semibold)
                .sbInput()
            Picker("Module", selection: field(\.moduleID, default: nil)) {
                Text("No module").tag(UUID?.none)
                ForEach(store.assignableModules) { module in
                    Text("\(module.code) \(module.name)").tag(Optional(module.id))
                }
            }
            .pickerStyle(.menu)
            .controlSize(controlSize)
            .padding(.top, 8)
        } else {
            Text(shown.title)
                .italic(shown.isCalendarStub)
                .sbFont(17, weight: .semibold)
                .foregroundStyle(shown.isCalendarStub ? SBColor.textSecondary : SBColor.textPrimary)
            Text(moduleLine)
                .sbFont(12)
                .foregroundStyle(SBColor.textSecondary)
                .padding(.top, 4)
        }
    }

    private var moduleLine: String {
        if let module = store.module(for: shown) { return "\(module.code) \(module.name)" }
        return shown.programmeEventID != nil ? "Module not known until the brief arrives" : "No module"
    }

    // MARK: Chips: status, priority, due date, word limit, weighting, source

    /// Assignment metadata, all in one row: status, priority, due date, word limit and weighting.
    /// Word limit and weighting are facts about the assignment, not about grading, so they sit
    /// here rather than under "Grade and feedback".
    @ViewBuilder
    private var chips: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Picker("Status", selection: field(\.status, default: .backlog)) {
                        ForEach(AssignmentStatus.allCases, id: \.self) { status in
                            Label(StatusIcon.label(for: status), systemImage: "circle").tag(status)
                        }
                    }
                    .pickerStyle(.menu).controlSize(controlSize).fixedSize()
                    Picker("Priority", selection: field(\.priority, default: .none)) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Text(priority.rawValue.capitalized).tag(priority)
                        }
                    }
                    .pickerStyle(.menu).controlSize(controlSize).fixedSize()
                    DatePicker(
                        "Due", selection: dueDateBinding, displayedComponents: .date
                    )
                    .datePickerStyle(.field).controlSize(controlSize).labelsHidden().fixedSize()
                    .environment(\.calendar, UKCalendar.calendar)
                    .environment(\.timeZone, UKCalendar.timeZone)
                    .environment(\.locale, UKCalendar.locale)
                }
                HStack(spacing: 8) {
                    TextField("Word limit", value: field(\.wordLimit, default: nil), format: .number)
                        .sbInput().frame(width: scale(110))
                    TextField("Weighting %", value: field(\.weighting, default: nil), format: .number)
                        .sbInput().frame(width: scale(110))
                }
            }
        } else {
            // A row of chips, or a column at accessibility sizes so none truncates (§9).
            let layout =
                scale.isAccessibility
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: scale(8)))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Chip(StatusIcon.label(for: shown.status)) { StatusIcon(shown.status, size: 12) }
                if shown.priority != .none {
                    Chip(shown.priority.rawValue.capitalized) { PriorityBars(shown.priority) }
                }
                if let due = shown.dueDate {
                    Chip(RelativeDate.fullDate(due))
                }
                if let limit = shown.wordLimit {
                    Chip(RelativeDate.wordCount(limit))
                }
                if let weighting = shown.weighting {
                    Chip("\(Int(weighting))% of module")
                }
                Chip(shown.programmeEventID != nil ? "via programme calendar" : "added by hand")
            }
        }
    }

    // MARK: Sections

    /// The brief arrives as a file, not as typing. Until one exists the section is a dashed
    /// drop zone in both modes (§6.2 "drop a PDF, the importer extracts text"); the text
    /// editor appears only once there is brief text to correct. The drop itself lands with
    /// the PDF importer.
    @ViewBuilder
    private var brief: some View {
        if let brief = shown.briefText, !brief.isEmpty || isEditing {
            if isEditing {
                TextEditor(text: optionalText(field(\.briefText, default: nil)))
                    .frame(minHeight: 76)
                    .sbInput()
            } else {
                Text(brief).sbFont(13).foregroundStyle(SBColor.textSecondary).lineSpacing(4)
            }
        } else {
            briefDropZone
        }
    }

    private var briefDropZone: some View {
        Text(briefDropCopy)
            .sbFont(12.5)
            .foregroundStyle(SBColor.textTertiary)
            .lineSpacing(4)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(SBColor.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
    }

    /// §6.2's copy, minus the claim about the module when the calendar did not give one.
    private var briefDropCopy: String {
        let gave = store.module(for: shown) == nil ? "the date" : "the date and the module"
        return "The calendar gave \(gave). The brief comes from ELE2. Drop the PDF here when it appears."
    }

    @ViewBuilder
    private var rubric: some View {
        if isEditing {
            TextEditor(text: optionalText(field(\.rubricText, default: nil)))
                .frame(minHeight: 76)
                .sbInput()
                .placeholder("Paste the real marking criteria here", when: shown.rubricText?.isEmpty ?? true)
        } else if let rubric = shown.rubricText, !rubric.isEmpty {
            Text(rubric).sbFont(12).foregroundStyle(SBColor.textSecondary).lineSpacing(5)
        } else {
            Text("No rubric yet. Press Edit and paste the marking criteria.")
                .sbFont(12.5)
                .foregroundStyle(SBColor.textTertiary)
        }
    }

    private var draftHint: String? {
        let words = draftText.wordCount
        if let limit = shown.wordLimit, limit > 0 { return "\(words) of \(limit) words" }
        return words > 0 ? "\(words) words" : nil
    }

    /// Always editable: a writing surface, not a form field (§6.2). Saves a second after typing stops.
    private var draft: some View {
        TextEditor(text: $draftText)
            .sbFont(17, design: .serif)
            .lineSpacing(scale(SBType.longFormLineSpacing))
            .frame(minHeight: 96)
            .sbInput()
            .placeholder("Start writing. The word count updates as you go.", when: draftText.isEmpty)
            .onChange(of: draftText) { _, newValue in
                guard newValue != (assignment.draftText ?? "") else { return }
                draftSaveTask?.cancel()
                draftSaveTask = Task {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    var updated = assignment
                    updated.draftText = newValue.isEmpty ? nil : newValue
                    await store.save(updated, changedFields: [])
                }
            }
    }

    @ViewBuilder
    private var gradeAndFeedback: some View {
        if isEditing {
            TextField("Grade", value: field(\.grade, default: nil), format: .number)
                .sbInput().frame(width: scale(90))
            TextEditor(text: optionalText(field(\.feedback, default: nil)))
                .frame(minHeight: 60)
                .sbInput()
                .placeholder("Paste the tutor's feedback here", when: shown.feedback?.isEmpty ?? true)
                .padding(.top, 8)
        } else {
            if let grade = shown.grade {
                GradeBadge(grade, bands: store.settings.gradeBands)
            } else {
                Text("Not graded").sbFont(12.5).foregroundStyle(SBColor.textTertiary)
            }
            if let feedback = shown.feedback, !feedback.isEmpty {
                Text(feedback).sbFont(12).foregroundStyle(SBColor.textSecondary).padding(.top, 6)
            }
        }
    }

    /// Check against rubric is the primary action and stays disabled, with its reason, until a
    /// rubric exists (§6.2). The AI itself arrives with a later milestone.
    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Btn.primary("Check against rubric", icon: "sparkles", size: .small) {}
                    .disabled(true)
                Btn.secondary("Outline", size: .small) {}.disabled(true)
                Btn.secondary("Draft a section", size: .small) {}.disabled(true)
            }
            Text(
                shown.rubricText?.isEmpty ?? true
                    ? "Needs the rubric first. Press Edit and paste the marking criteria."
                    : "AI actions arrive with the sync milestone."
            )
            .sbFont(11.5)
            .foregroundStyle(SBColor.textTertiary)
        }
    }

    /// System controls follow the text size in the one step they offer.
    private var controlSize: ControlSize { scale.isAccessibility ? .large : .small }

    // MARK: Bindings into the editing copy

    private func field<T>(_ keyPath: WritableKeyPath<Assignment, T>, default value: T) -> Binding<T> {
        Binding(
            get: { model.editor.draft?[keyPath: keyPath] ?? value },
            set: { model.editor.draft?[keyPath: keyPath] = $0 })
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { model.editor.draft?.dueDate ?? UKCalendar.startOfDay(model.now()) },
            set: { model.editor.draft?.dueDate = UKCalendar.startOfDay($0) })
    }

    private func optionalText(_ binding: Binding<String?>) -> Binding<String> {
        Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}

/// A labelled section in the panel: 12pt semibold label, optional hint on the right, 22pt above.
private struct Field<Content: View>: View {
    let label: String
    let hint: String?
    @ViewBuilder let content: () -> Content

    init(_ label: String, hint: String?, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.hint = hint
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).sbFont(12, weight: .semibold).foregroundStyle(SBColor.textSecondary)
                Spacer()
                if let hint {
                    Text(hint).sbFont(11).foregroundStyle(SBColor.textTertiary)
                }
            }
            content()
        }
        .padding(.top, 22)
    }
}

extension View {
    /// Placeholder copy over an empty text area (§9: empty states direct). `TextEditor` has no
    /// prompt of its own, so this draws one in `textTertiary` that ignores the cursor.
    fileprivate func placeholder(_ text: String, when isEmpty: Bool) -> some View {
        modifier(PlaceholderModifier(text: text, isEmpty: isEmpty))
    }
}

private struct PlaceholderModifier: ViewModifier {
    let text: String
    let isEmpty: Bool
    @Environment(\.sbScale) private var scale

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            if isEmpty {
                Text(text)
                    .sbFont(13)
                    .foregroundStyle(SBColor.textTertiary)
                    .padding(.vertical, scale(9))
                    .padding(.horizontal, scale(16))
                    .allowsHitTesting(false)
            }
        }
    }
}
