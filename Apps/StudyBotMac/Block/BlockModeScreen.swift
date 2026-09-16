import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// Block mode (§6.6): a column per day, never assuming three; the selected session's notes;
/// the questions list aggregated across every day, always visible; the capture bar fixed at
/// the bottom. Deliberately narrow: no KSB grid, no assignments, no structured pane.
struct BlockModeScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    let block: CampusBlock

    private var days: [BlockDay] { SessionCatalog.days(of: block, in: model.events) }
    private var allSlotIDs: [UUID] { days.flatMap { $0.slots.map(\.id) } }

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                dayColumns
                    .frame(width: scale(220))
                SBColor.border.frame(width: 1)
                if let id = model.selectedSlotID, let slot = model.slot(id: id), allSlotIDs.contains(id) {
                    NoteWorkspaceView(slot: slot, showsStructured: false)
                        .id(slot.id)
                        .frame(maxWidth: .infinity)
                } else {
                    EmptyState("Pick a session on the left. Type. Sort it out later.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if !scale.isAccessibility {
                    SBColor.border.frame(width: 1)
                    questionsColumn
                        .frame(width: scale(260))
                }
            }
            CaptureBar(sessionID: model.selectedSlotID)
        }
        .background(SBColor.surface)
        .task {
            // Open every day's session so notes exist on both Macs from the first morning.
            guard let notes = model.notes else { return }
            for slot in days.flatMap(\.slots) {
                _ = await notes.open(slot, moduleID: model.moduleID(forCodes: slot.moduleCodes))
            }
        }
    }

    private var header: some View {
        ScreenHeader(
            title:
                "Block \(block.number) · \(RelativeDate.dayRange(block.start.date, block.end.date, relativeTo: model.now()))"
        ) {
            Btn.secondary("Leave Block mode", size: .small) { model.leaveBlockMode() }
        }
    }

    private var dayColumns: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(days) { day in
                    SectionHeader(
                        dayTitle(day.day), count: nil, note: day.day == LocalDay(model.now()) ? "today" : nil)
                    ForEach(day.slots) { slot in
                        ListRow(isSelected: model.selectedSlotID == slot.id) {
                            model.selectedSlotID = slot.id
                        } content: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.title).sbType(SBType.row).foregroundStyle(SBColor.textPrimary)
                                Text(
                                    model.modules(forCodes: slot.moduleCodes).map(\.shortCode).joined(
                                        separator: " · ")
                                )
                                .sbFont(11).foregroundStyle(SBColor.textTertiary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if day.slots.isEmpty {
                        Text("No sessions").sbFont(12).foregroundStyle(SBColor.textTertiary)
                            .padding(.vertical, scale(10)).padding(
                                .horizontal, scale(SBSpacing.rowHorizontal))
                    }
                }
            }
        }
    }

    /// "Tue 22 Sep": the day, not "Day 1", so it matches the timetable on the wall.
    private func dayTitle(_ day: LocalDay) -> String {
        "\(RelativeDate.weekday(day.date)) \(RelativeDate.absolute(day.date, relativeTo: model.now()))"
    }

    /// Every `ASK:` line across the block (§6.6): what to ask before the last session ends.
    private var questionsColumn: some View {
        let questions = model.notes?.questions(in: allSlotIDs) ?? []
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Questions to ask", count: questions.count)
            if questions.isEmpty {
                Text("Start a line with ASK: and it lands here.")
                    .sbFont(12.5).foregroundStyle(SBColor.textTertiary)
                    .padding(scale(SBSpacing.rowHorizontal))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: scale(10)) {
                    ForEach(questions) { question in
                        Button {
                            model.selectedSlotID = question.sessionID
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(question.text).sbFont(13).foregroundStyle(SBColor.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text(
                                    "\(question.sessionTitle) · \(RelativeDate.absolute(question.day.date, relativeTo: model.now()))"
                                )
                                .sbFont(11).foregroundStyle(SBColor.textTertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(scale(SBSpacing.rowHorizontal))
            }
            Spacer(minLength: 0)
        }
        .background(SBColor.canvas)
    }
}

/// The capture bar (§6.6): one field, one keystroke. Return files a note line, shift-return a
/// question, option-return opens evidence with the text as its title.
private struct CaptureBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    let sessionID: UUID?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: scale(10)) {
            TextField("Capture a thought", text: $text)
                .sbInput()
                .focused($focused)
                .onAppear { focused = true }
                .onKeyPress(.return, phases: .down) { press in
                    file(press.modifiers)
                    return .handled
                }
                .disabled(sessionID == nil)
            Text("⏎ note · ⇧⏎ question · ⌥⏎ evidence")
                .sbFont(11)
                .foregroundStyle(SBColor.textTertiary)
                .fixedSize()
        }
        .padding(.vertical, scale(10))
        .padding(.horizontal, scale(SBSpacing.rowHorizontal))
        .background(SBColor.canvas)
        .overlay(alignment: .top) { SBColor.border.frame(height: 1) }
    }

    private func file(_ modifiers: EventModifiers) {
        let thought = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thought.isEmpty, let sessionID else { return }
        if modifiers.contains(.option) {
            model.beginEvidence(source: .lecture, sessionID: sessionID, title: thought)
        } else {
            model.notes?.append(thought, asQuestion: modifiers.contains(.shift), to: sessionID)
        }
        text = ""
    }
}
