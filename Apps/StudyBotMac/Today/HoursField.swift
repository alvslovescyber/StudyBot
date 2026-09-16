import StudyBotKit
import StudyBotUI
import SwiftUI

/// One field to log hours (Today, "One keystroke to log"): `L` from anywhere, type
/// "2h project work: rewrote the pipeline checks", Return files it. The line beneath shows
/// how the text will be read, so there is nothing to guess. No form, no dropdowns, no modal.
struct HoursField: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    @State private var text = ""
    @FocusState private var focused: Bool

    private var parsed: HoursLine? { HoursLine.parse(text) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { model.hoursFieldShown = false }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: scale(10)) {
                    Image(systemName: "clock").sbFont(13, weight: .medium).foregroundStyle(SBColor.textTertiary)
                    TextField("2h project work: what you did", text: $text)
                        .textFieldStyle(.plain)
                        .sbFont(14)
                        .foregroundStyle(SBColor.textPrimary)
                        .focused($focused)
                        .onSubmit(log)
                        .onKeyPress(.escape) {
                            model.hoursFieldShown = false
                            return .handled
                        }
                }
                .padding(.vertical, scale(12))
                .padding(.horizontal, scale(16))
                .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }

                HStack {
                    Text(preview)
                        .sbFont(12)
                        .foregroundStyle(parsed == nil ? SBColor.textTertiary : SBColor.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("⏎ to log")
                        .sbFont(11)
                        .foregroundStyle(SBColor.textTertiary)
                }
                .padding(.vertical, scale(9))
                .padding(.horizontal, scale(16))
            }
            .frame(width: min(scale(520), 860))
            .background(SBColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.sheet, style: .continuous).strokeBorder(SBColor.border)
            )
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.sheet, style: .continuous))
            .sbShadow(SBShadow.palette)
            .padding(.top, 96)
        }
        .onAppear { focused = true }
        .accessibilityLabel("Log hours")
    }

    /// "2h · Project work · rewrote the pipeline checks", or the hint.
    private var preview: String {
        guard let parsed else { return HoursLine.hint }
        var parts = ["\(WeekBarView.hours(parsed.hours))h", parsed.category.label]
        if !parsed.description.isEmpty { parts.append(parsed.description) }
        return parts.joined(separator: " · ")
    }

    private func log() {
        guard parsed != nil else { return }
        let line = text
        model.hoursFieldShown = false
        Task { await model.logHours(line) }
    }
}
