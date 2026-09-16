import StudyBotKit
import StudyBotUI
import SwiftUI

/// ⌘K (§6.7): navigation and actions. Type to filter, arrows to move, return to run, escape to
/// close. The one surface in the app that floats, so the one with a shadow (§9).
struct CommandPaletteView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool

    private var results: [PaletteCommand] {
        PaletteMatcher.matches(query, in: model.paletteCommands)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { model.paletteShown = false }
            VStack(spacing: 0) {
                HStack(spacing: scale(10)) {
                    Image(systemName: "command").sbFont(13, weight: .medium).foregroundStyle(
                        SBColor.textTertiary)
                    TextField("Go to, or do…", text: $query)
                        .textFieldStyle(.plain)
                        .font(SBType.mono(scale(14)))
                        .focused($focused)
                        .onKeyPress(.upArrow) { move(-1) }
                        .onKeyPress(.downArrow) { move(1) }
                        .onKeyPress(.return) { run() }
                        .onKeyPress(.escape) {
                            model.paletteShown = false
                            return .handled
                        }
                }
                .padding(.vertical, scale(12))
                .padding(.horizontal, scale(16))
                .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(PaletteCommand.Section.allCases, id: \.self) { section in
                                let items = results.filter { $0.section == section }
                                if !items.isEmpty {
                                    Text(section.rawValue)
                                        .sbFont(11, weight: .semibold)
                                        .foregroundStyle(SBColor.textTertiary)
                                        .padding(.top, scale(10)).padding(.bottom, scale(4))
                                        .padding(.horizontal, scale(16))
                                    ForEach(items) { command in
                                        row(command, index: results.firstIndex(of: command) ?? 0)
                                            .id(command.id)
                                    }
                                }
                            }
                            if results.isEmpty {
                                Text("Nothing matches. Try fewer words.")
                                    .sbFont(13).foregroundStyle(SBColor.textSecondary)
                                    .padding(scale(16))
                            }
                        }
                        .padding(.bottom, scale(8))
                    }
                    .onChange(of: highlighted) { _, index in
                        if results.indices.contains(index) { proxy.scrollTo(results[index].id) }
                    }
                }
                .frame(maxHeight: scale(360))
            }
            .frame(width: min(scale(560), 900))
            .background(SBColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.sheet, style: .continuous).strokeBorder(
                    SBColor.border)
            )
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.sheet, style: .continuous))
            .sbShadow(SBShadow.palette)
            .padding(.top, 96)
        }
        .onAppear { focused = true }
        .onChange(of: query) { _, _ in highlighted = 0 }
    }

    private func row(_ command: PaletteCommand, index: Int) -> some View {
        Button {
            model.perform(command)
        } label: {
            HStack(spacing: scale(10)) {
                Text("›").sbFont(13).foregroundStyle(SBColor.textTertiary)
                Text(command.title).sbFont(13).foregroundStyle(SBColor.textPrimary).lineLimit(1)
                Spacer(minLength: 0)
                if let detail = command.detail {
                    Text(detail).sbFont(12).foregroundStyle(SBColor.textTertiary)
                }
            }
            .padding(.vertical, scale(7))
            .padding(.horizontal, scale(16))
            .background(index == highlighted ? SBColor.accentSoft : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { if $0 { highlighted = index } }
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        guard !results.isEmpty else { return .ignored }
        highlighted = min(max(highlighted + delta, 0), results.count - 1)
        return .handled
    }

    private func run() -> KeyPress.Result {
        guard results.indices.contains(highlighted) else { return .ignored }
        model.perform(results[highlighted])
        return .handled
    }
}
