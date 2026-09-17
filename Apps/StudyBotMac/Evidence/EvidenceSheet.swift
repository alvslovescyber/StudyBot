import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// Evidence capture (§6.5): title, date, what you did, KSBs. Thirty seconds. KSBs are typed
/// codes until Exeter's list exists (§14); nothing waits on it.
struct EvidenceSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    @State var draft: EvidenceStore.Draft
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: scale(14)) {
            Text("New evidence").sbType(SBType.section).fontWeight(.semibold).foregroundStyle(
                SBColor.textPrimary)

            field("Title") {
                TextField("What is this a record of?", text: $draft.title).sbInput().focused($titleFocused)
            }
            HStack(alignment: .top, spacing: scale(12)) {
                field("Date") {
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                        .datePickerStyle(.field).labelsHidden()
                        .environment(\.calendar, UKCalendar.calendar)
                        .environment(\.timeZone, UKCalendar.timeZone)
                        .environment(\.locale, UKCalendar.locale)
                }
                field("Source") {
                    Picker("Source", selection: $draft.source) {
                        ForEach(EvidenceSource.allCases, id: \.self) { source in
                            Text(label(source)).tag(source)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden()
                }
            }
            field("What you did") {
                TextEditor(text: $draft.summary)
                    .sbFont(13)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: scale(90))
                    .sbInput()
            }
            field("KSBs") {
                TextField("K3 S12, or leave empty until the list arrives", text: $draft.ksbCodes).sbInput()
            }
            if draft.source.defaultsToConfidential {
                Text("From work, so marked confidential: it never goes to the AI.")
                    .sbFont(11.5).foregroundStyle(SBColor.textTertiary)
            }
            if let error = model.evidence?.lastError {
                Text(error).sbFont(12).foregroundStyle(SBColor.danger)
            }
            HStack(spacing: scale(8)) {
                Spacer()
                Btn.secondary("Cancel") { model.evidenceDraft = nil }
                Btn.primary("Save evidence", icon: "plus") {
                    Task {
                        if await model.evidence?.create(draft) != nil {
                            model.evidenceDraft = nil
                        }
                    }
                }
                .disabled(
                    draft.title.trimmingCharacters(in: .whitespaces).isEmpty
                        || draft.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(SBSpacing.region)
        .frame(width: 520)
        .background(SBColor.surface)
        .onAppear { titleFocused = true }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: scale(5)) {
            Text(label).sbFont(12).foregroundStyle(SBColor.textSecondary)
            content()
        }
    }

    private func label(_ source: EvidenceSource) -> String {
        switch source {
        case .workProject: "Work project"
        case .assignment: "Assignment"
        case .lecture: "Lecture"
        case .reflection: "Reflection"
        case .codeCommit: "Code commit"
        }
    }
}

extension EvidenceStore.Draft: @retroactive Identifiable {
    public var id: String { "\(sessionID?.uuidString ?? "")#\(source.rawValue)" }
}
