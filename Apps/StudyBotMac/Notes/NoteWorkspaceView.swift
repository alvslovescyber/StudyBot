import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// The note workspace (§6.3): live notes on the left, structured on the right, the questions
/// list and the transcript beneath the live pane. Live notes are always directly editable;
/// nothing here steals a keystroke. A replaced version, if sync ever replaces one, is one
/// line at the top with the way back (§3.4).
struct NoteWorkspaceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    let slot: SessionSlot
    /// Hide the structured pane, as Block mode does (§6.6 "deliberately narrow").
    var showsStructured = true

    @State private var liveText = ""
    @State private var transcriptText = ""
    @State private var losers: [ConflictLoser] = []
    @State private var showingHistory = false
    @State private var aiStatus: String?

    private var session: Session? { model.notes?.session(id: slot.id) }

    private var edgeColour: Color? {
        let modules = model.modules(forCodes: slot.moduleCodes)
        guard modules.count == 1, let module = modules.first else { return nil }
        return SBColor.module(module.colour)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let failure = model.notes?.saveFailures[slot.id] {
                saveFailureBanner(failure)
            }
            if !losers.isEmpty {
                replacedNotice
            }
            HStack(spacing: 0) {
                livePane
                    .frame(maxWidth: showsStructured ? .infinity : .infinity)
                if showsStructured {
                    SBColor.border.frame(width: 1)
                    structuredPane
                        .frame(maxWidth: .infinity)
                }
            }
            footer
        }
        .background(SBColor.surface)
        // §9 patch 9: the note's left edge carries its module's colour, when it has one module.
        .overlay(alignment: .leading) {
            if let colour = edgeColour {
                colour.frame(width: 3)
            }
        }
        .task(id: slot.id) {
            guard let notes = model.notes else { return }
            let opened = await notes.open(slot, moduleID: model.moduleID(forCodes: slot.moduleCodes))
            liveText = opened.liveNotes
            transcriptText = opened.transcript ?? ""
            losers = await notes.conflictLosers(for: slot.id)
        }
        .onChange(of: session?.liveNotes) { _, newValue in
            // A restore or a synced change: the editor follows the store.
            if let newValue, newValue != liveText { liveText = newValue }
        }
        .onDisappear {
            Task { await model.notes?.flush(slot.id) }
        }
        .sheet(isPresented: $showingHistory) {
            NoteHistorySheet(sessionID: slot.id, losers: losers)
                .environment(model)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: scale(10)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.title)
                    .sbType(SBType.section)
                    .fontWeight(.semibold)
                    .foregroundStyle(SBColor.textPrimary)
                HStack(spacing: scale(8)) {
                    Text(RelativeDate.absolute(slot.day.date, relativeTo: model.now()))
                    ForEach(model.modules(forCodes: slot.moduleCodes)) { module in
                        ModuleChip(module)
                    }
                }
                .sbFont(12)
                .foregroundStyle(SBColor.textSecondary)
            }
            Spacer(minLength: 0)
            if let session, !session.countsAsAttended {
                Btn.secondary("Mark attended", size: .small) {
                    Task { await model.notes?.markAttended(slot.id) }
                }
            }
            Btn.secondary("History", size: .small) { showingHistory = true }
        }
        .padding(.vertical, scale(12))
        .padding(.horizontal, scale(SBSpacing.rowHorizontal))
        .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }
    }

    /// §16: a failed save is a banner that stays, on the note, with the text still in the editor.
    private func saveFailureBanner(_ message: String) -> some View {
        HStack(spacing: scale(10)) {
            Image(systemName: "exclamationmark.triangle.fill")
                .sbFont(13, weight: .medium)
            Text(message)
                .sbFont(13, weight: .medium)
            Text("The text is still here and still yours. Free some disk space, then try again.")
                .sbFont(12)
                .foregroundStyle(SBColor.textSecondary)
            Spacer(minLength: 0)
            Btn.secondary("Try again", size: .small) {
                Task { await model.notes?.retrySave(slot.id) }
            }
        }
        .foregroundStyle(SBColor.danger)
        .padding(.vertical, scale(10))
        .padding(.horizontal, scale(SBSpacing.rowHorizontal))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColor.canvas)
        .overlay(alignment: .bottom) { SBColor.danger.frame(height: 1) }
        .accessibilityLabel("\(message) The text is still here.")
    }

    /// §3.4: "An older version of this note was replaced. View it."
    private var replacedNotice: some View {
        HStack(spacing: 4) {
            Text("An older version of this note was replaced.")
                .foregroundStyle(SBColor.textSecondary)
            Button("View it") { showingHistory = true }
                .buttonStyle(.plain)
                .foregroundStyle(SBColor.accent)
        }
        .sbFont(12)
        .padding(.vertical, scale(8))
        .padding(.horizontal, scale(SBSpacing.rowHorizontal))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColor.canvas)
        .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }
    }

    // MARK: Live pane

    private var livePane: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneTitle("Live notes")
            ZStack(alignment: .topLeading) {
                LiveNotesEditor(text: $liveText, scale: scale) { newValue in
                    liveText = newValue
                    model.notes?.updateLiveNotes(slot.id, text: newValue)
                }
                if liveText.isEmpty {
                    Text("Type. Sort it out later.")
                        .sbFont(SBType.liveNotesSize)
                        .foregroundStyle(SBColor.textTertiary)
                        .padding(.horizontal, scale(SBSpacing.liveNotesInset + 5))
                        .padding(.top, scale(20))
                        .allowsHitTesting(false)
                }
            }
            .frame(
                maxWidth: scale(
                    SBType.liveNotesSize * 0.55 * SBType.liveNotesMeasure + 2 * SBSpacing.liveNotesInset),
                alignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: scale(160))
            questions
            transcript
        }
    }

    @ViewBuilder
    private var questions: some View {
        let list = model.notes?.questions(in: [slot.id]) ?? []
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: scale(6)) {
                paneTitle("Questions to ask", count: list.count)
                ForEach(list) { question in
                    HStack(alignment: .firstTextBaseline, spacing: scale(8)) {
                        Text("?").sbFont(12, weight: .semibold).foregroundStyle(SBColor.accent)
                        Text(question.text).sbFont(13).foregroundStyle(SBColor.textPrimary)
                    }
                    .padding(.horizontal, scale(SBSpacing.rowHorizontal))
                }
            }
            .padding(.bottom, scale(12))
        }
    }

    /// Paste-only for now (§6.3); `.vtt` and `.srt` import arrive with the importers.
    private var transcript: some View {
        VStack(alignment: .leading, spacing: scale(6)) {
            paneTitle("Transcript")
            TextEditor(text: $transcriptText)
                .sbFont(13)
                .scrollContentBackground(.hidden)
                .frame(minHeight: scale(72), maxHeight: scale(160))
                .padding(.horizontal, scale(SBSpacing.rowHorizontal) - 5)
                .overlay(alignment: .topLeading) {
                    if transcriptText.isEmpty {
                        Text("Paste the transcript here.")
                            .sbFont(13)
                            .foregroundStyle(SBColor.textTertiary)
                            .padding(.horizontal, scale(SBSpacing.rowHorizontal))
                            .padding(.top, 1)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: transcriptText) { _, newValue in
                    model.notes?.updateTranscript(slot.id, text: newValue)
                }
        }
        .padding(.bottom, scale(12))
    }

    // MARK: Structured pane

    private var structuredPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneTitle("Structured")
            if let structured = session?.structuredNotes, !structured.isEmpty {
                ScrollView {
                    Text(structured)
                        .sbFont(SBType.longFormSize, design: .serif)
                        .lineSpacing(scale(SBType.longFormLineSpacing))
                        .foregroundStyle(SBColor.textPrimary)
                        .frame(
                            maxWidth: scale(SBType.longFormSize * 0.5 * SBType.longFormMeasure),
                            alignment: .leading
                        )
                        .padding(scale(SBSpacing.liveNotesInset))
                }
            } else {
                Text(
                    "Nothing structured yet. Structure these notes writes here; your live notes are untouched either way."
                )
                .sbFont(13)
                .foregroundStyle(SBColor.textTertiary)
                .padding(scale(SBSpacing.liveNotesInset))
                Spacer(minLength: 0)
            }
        }
        .background(SBColor.canvas)
    }

    /// §6.3's two AI actions. `sparkles` means "this costs tokens" (§9). Live notes are read,
    /// never written; the structured pane is where the answer lands.
    private var footer: some View {
        let ai = model.ai
        let available = ai?.isAvailable == true
        let structuring = ai?.running.contains(.structureNotes) == true
        let carding = ai?.running.contains(.makeFlashcards) == true
        return HStack(spacing: scale(8)) {
            Btn.primary(
                structuring ? "Structuring…" : "Structure these notes", icon: "sparkles", size: .small
            ) {
                Task { await structure() }
            }
            .disabled(!available || structuring || session?.hasNotes != true)
            Btn.secondary(carding ? "Making flashcards…" : "Make flashcards", size: .small) {
                Task { await makeFlashcards() }
            }
            .disabled(!available || carding || (session?.structuredNotes ?? "").isEmpty)
            if let error = ai?.lastError, aiStatus == nil {
                Text(error).sbFont(11.5).foregroundStyle(SBColor.danger).lineLimit(2)
            } else if let aiStatus {
                Text(aiStatus).sbFont(11.5).foregroundStyle(SBColor.textSecondary)
            } else if !available {
                Text("AI needs the server. Pair this Mac in Settings → Sync; notes work without it.")
                    .sbFont(11.5).foregroundStyle(SBColor.textTertiary)
            } else if let budget = ai?.budget, budget.isWarning {
                Text(
                    "\(AIBudget.pounds(budget.spentPence)) of \(AIBudget.pounds(budget.capPence)) used this month."
                )
                .sbFont(11.5).foregroundStyle(SBColor.statusDrafting)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, scale(10))
        .padding(.horizontal, scale(SBSpacing.rowHorizontal))
        .overlay(alignment: .top) { SBColor.border.frame(height: 1) }
    }

    /// The session's module when the calendar names exactly one.
    private var module: Module? {
        let matches = model.modules(forCodes: slot.moduleCodes)
        return matches.count == 1 ? matches.first : nil
    }

    private func structure() async {
        guard let ai = model.ai, let notes = model.notes, let session else { return }
        aiStatus = nil
        if await ai.structureNotes(session: session, module: module, notes: notes) != nil {
            aiStatus = "Structured. Your live notes are untouched."
        }
    }

    private func makeFlashcards() async {
        guard let ai = model.ai, let session else { return }
        aiStatus = nil
        if let count = await ai.makeFlashcards(session: session, module: module) {
            aiStatus = "\(count) cards made. They are in Revision."
        }
    }

    private func paneTitle(_ title: String, count: Int? = nil) -> some View {
        HStack(spacing: scale(6)) {
            Text(title).sbFont(12, weight: .semibold).foregroundStyle(SBColor.textSecondary)
            if let count {
                Text("\(count)").sbFont(12).foregroundStyle(SBColor.textTertiary).monospacedDigit()
            }
        }
        .padding(.top, scale(14))
        .padding(.bottom, scale(4))
        .padding(.horizontal, scale(SBSpacing.rowHorizontal))
    }
}

/// Older versions of a note: the losers of a sync race first, then the idle snapshots.
/// Restore puts one back as the live notes; the current text is snapshotted first.
private struct NoteHistorySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sbScale) private var scale
    let sessionID: UUID
    let losers: [ConflictLoser]
    @State private var revisions: [NoteRevision] = []

    var body: some View {
        VStack(alignment: .leading, spacing: scale(12)) {
            HStack {
                Text("Older versions").sbType(SBType.section).fontWeight(.semibold)
                Spacer()
                Btn.secondary("Done", size: .small) { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: scale(10)) {
                    ForEach(losers) { loser in
                        version(
                            title: "Replaced by the other Mac",
                            when: loser.record.updatedAt,
                            body: loser.record.fields["liveNotes"]?.stringValue ?? "")
                    }
                    ForEach(revisions) { revision in
                        version(
                            title: label(for: revision.reason), when: revision.capturedAt, body: revision.body
                        )
                    }
                    if losers.isEmpty && revisions.isEmpty {
                        Text("No older versions yet. A copy is kept every 30 seconds while you type.")
                            .sbFont(13).foregroundStyle(SBColor.textSecondary)
                    }
                }
            }
        }
        .padding(SBSpacing.region)
        .frame(minWidth: 520, minHeight: 420)
        .task { revisions = await model.notes?.revisions(for: sessionID) ?? [] }
    }

    private func version(title: String, when: Date, body: String) -> some View {
        VStack(alignment: .leading, spacing: scale(6)) {
            HStack {
                Text(
                    "\(title) · \(RelativeDate.absolute(when, relativeTo: model.now())) \(RelativeDate.time(when))"
                )
                .sbFont(12).foregroundStyle(SBColor.textSecondary)
                Spacer()
                Btn.secondary("Restore this version", size: .small) {
                    Task {
                        await model.notes?.restore(body: body, into: sessionID)
                        dismiss()
                    }
                }
            }
            Text(body.isEmpty ? "(empty)" : body)
                .sbFont(13)
                .foregroundStyle(SBColor.textPrimary)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(scale(10))
                .sbCard()
        }
    }

    private func label(for reason: RevisionReason) -> String {
        switch reason {
        case .idleSnapshot: "Saved while typing"
        case .preSync: "Kept before a restore"
        case .conflictLoser: "Replaced by the other Mac"
        }
    }
}
