import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// Revision (§6.4 Study): one card at a time, Space to flip, then Got it or Again. The queue
/// is what is due today; finishing it ends the session rather than offering more. The flip
/// is the one piece of showy motion in the app and it has earned its place (§9).
struct RevisionScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The card being shown, chosen from the queue or the weak-areas strip.
    @State private var currentID: UUID?
    @State private var flipped = false
    /// How many the session started with, for "3 of 12".
    @State private var sessionTotal = 0
    @State private var answered = 0

    private var today: LocalDay { LocalDay(model.now()) }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Revision") {
                if let store = model.revision, !store.queue(on: today).isEmpty {
                    Text(dueLine(store.queue(on: today).count))
                        .sbFont(12)
                        .foregroundStyle(SBColor.textSecondary)
                        .monospacedDigit()
                }
            }
            if let store = model.revision {
                if let weak = weakAreas(store) {
                    weak
                }
                content(store)
            }
        }
        .background(SBColor.surface)
        .task {
            await model.revision?.load()
            beginSession()
        }
        .onChange(of: model.revision?.cards.count) { _, _ in
            if sessionTotal == 0 { beginSession() }
        }
    }

    // MARK: The session

    private func beginSession() {
        guard let store = model.revision else { return }
        let queue = store.queue(on: today)
        sessionTotal = queue.count
        answered = 0
        currentID = queue.first?.id
        flipped = false
    }

    private var current: Card? {
        guard let store = model.revision else { return nil }
        if let currentID, let card = store.cards.first(where: { $0.id == currentID }) { return card }
        return store.queue(on: today).first
    }

    @ViewBuilder
    private func content(_ store: RevisionStore) -> some View {
        if store.cards.isEmpty {
            emptyLine("Cards made from your notes appear here.")
        } else if let card = current {
            study(card, store: store)
        } else {
            emptyLine(queueClearLine(store))
        }
    }

    private func emptyLine(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .sbFont(13)
                .foregroundStyle(SBColor.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(SBSpacing.region)
    }

    /// "Queue clear. Next cards are due tomorrow." (§9 empty states), with the real day.
    private func queueClearLine(_ store: RevisionStore) -> String {
        guard let next = store.nextDueDay(after: today) else { return "Queue clear." }
        return
            "Queue clear. Next cards are due \(RelativeDate.string(for: next.date, relativeTo: model.now()))."
    }

    private func dueLine(_ count: Int) -> String {
        count == 1 ? "1 card due" : "\(count) cards due"
    }

    // MARK: Studying

    private func study(_ card: Card, store: RevisionStore) -> some View {
        VStack(spacing: scale(20)) {
            Spacer(minLength: 0)
            HStack(spacing: scale(8)) {
                if let deck = store.deck(for: card) {
                    Text(deck.title).sbFont(12).foregroundStyle(SBColor.textSecondary)
                    if let moduleID = deck.moduleID,
                        let module = model.assignments?.modules.first(where: { $0.id == moduleID })
                    {
                        ModuleChip(module)
                    }
                }
                Spacer(minLength: 0)
                if sessionTotal > 0 {
                    Text("\(min(answered + 1, sessionTotal)) of \(sessionTotal)")
                        .sbFont(12).foregroundStyle(SBColor.textTertiary).monospacedDigit()
                        .contentTransition(.numericText(value: Double(answered)))
                        .sbAnimation(SBMotion.count, value: answered)
                }
            }
            .frame(maxWidth: scale(560))

            FlashcardView(front: card.front, back: card.back, flipped: flipped, source: card.source) {
                flip()
            }
            .frame(maxWidth: scale(560))
            .frame(minHeight: scale(260))

            HStack(spacing: scale(10)) {
                if flipped {
                    Btn.secondary("Again") { answer(card, correct: false, store: store) }
                        .help("Again: back to box 1, due tomorrow (←)")
                    Btn.primary("Got it", icon: "checkmark") { answer(card, correct: true, store: store) }
                        .help("Got it: up a box (→ or ⏎)")
                } else {
                    Text("Space to flip")
                        .sbFont(12)
                        .foregroundStyle(SBColor.textTertiary)
                        .frame(height: scale(30))
                }
            }
            .sbAnimation(SBMotion.collapse, value: flipped)
            if let error = store.lastError {
                Text(error).sbFont(12).foregroundStyle(SBColor.danger)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SBSpacing.detailOuter)
        .frame(maxWidth: .infinity)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            flip()
            return .handled
        }
        .onKeyPress(.return) {
            guard flipped else { return .ignored }
            answer(card, correct: true, store: store)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard flipped else { return .ignored }
            answer(card, correct: true, store: store)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard flipped else { return .ignored }
            answer(card, correct: false, store: store)
            return .handled
        }
    }

    private func flip() {
        if reduceMotion {
            flipped.toggle()
        } else {
            withAnimation(SBMotion.flip.animation) { flipped.toggle() }
        }
    }

    private func answer(_ card: Card, correct: Bool, store: RevisionStore) {
        let day = today
        // The next card comes up at once; the write follows.
        let remaining = store.queue(on: day).filter { $0.id != card.id }
        answered += 1
        flipped = false
        currentID = remaining.first?.id
        Task { await store.answer(card.id, correct: correct, on: day) }
    }

    // MARK: Weak areas (§6.4)

    private func weakAreas(_ store: RevisionStore) -> (some View)? {
        let weak = store.weakAreas()
        guard !weak.isEmpty else { return nil as AnyView? }
        return AnyView(
            HStack(spacing: scale(8)) {
                Text("Weak areas")
                    .sbFont(12, weight: .semibold)
                    .foregroundStyle(SBColor.textSecondary)
                ForEach(weak) { card in
                    Button {
                        currentID = card.id
                        flipped = false
                    } label: {
                        Chip("\(card.front.prefix(40))\(card.front.count > 40 ? "…" : "")  ·  \(card.lapses)")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("\(card.lapses) lapses. Show this card.")
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, scale(10))
            .padding(.horizontal, scale(SBSpacing.rowHorizontal))
            .background(SBColor.canvas)
            .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }
        )
    }
}

/// The card: front, and on flip the back. A 3D turn about the vertical axis, 420ms
/// ease-in-out, content swapping at 90° (§9). Reduce Motion swaps instantly. The card is one
/// of the three things in the app that float, so it carries the flashcard shadow.
struct FlashcardView: View, @MainActor Animatable {
    let front: String
    let back: String
    let source: String?
    let onTap: () -> Void
    /// 0 for the front, 180 for the back; interpolated by SwiftUI during the flip.
    var angle: Double

    @Environment(\.sbScale) private var scale

    init(front: String, back: String, flipped: Bool, source: String?, onTap: @escaping () -> Void) {
        self.front = front
        self.back = back
        self.source = source
        self.onTap = onTap
        angle = flipped ? 180 : 0
    }

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private var showsBack: Bool { angle >= 90 }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: scale(12)) {
                Text(showsBack ? "Answer" : "Question")
                    .sbFont(11, weight: .medium)
                    .foregroundStyle(SBColor.textTertiary)
                Text(showsBack ? back : front)
                    .sbFont(17)
                    .foregroundStyle(SBColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity)
                if showsBack, let source, !source.isEmpty {
                    Text(source)
                        .sbFont(11)
                        .foregroundStyle(SBColor.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(SBSpacing.region)
            .frame(maxWidth: .infinity, minHeight: scale(220))
            // The back face is drawn mirrored so that, turned through 180°, it reads forwards.
            .rotation3DEffect(.degrees(showsBack ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .sbCard()
            .sbShadow(SBShadow.flashcard)
            .contentShape(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .accessibilityLabel(showsBack ? "Answer: \(back)" : "Question: \(front)")
        .accessibilityHint("Flips the card")
    }
}
