import Foundation
import StudyBotCore

/// The prompt templates (§7.3a). Part of the product, not glue: changing one is a deliberate
/// act, so each carries a version that becomes part of the server's cache key, and the
/// changelog lives in docs/decisions.md.
public enum PromptTemplates {
    /// Bumped whenever any template text changes.
    public static let version = "2026-09-16.1"

    /// Every prompt opens with this, assembled from real data, never hardcoded module names.
    public static func contextBlock(moduleCode: String?, moduleName: String?) -> String {
        var lines = [
            "You are helping a Level 6 Digital & Technology Solutions degree apprentice",
            "at the University of Exeter, working full time at a technology company.",
        ]
        if let moduleCode, let moduleName {
            lines.append("Module: \(moduleCode) \(moduleName)")
        } else {
            lines.append("Module: not yet known; this is an induction or cross-module session.")
        }
        lines += [
            "This is undergraduate work assessed at degree level. The user is aiming for",
            "a distinction. Write for someone competent who is short of time.",
            "Use British English. Be concise; do not pad.",
            "",
            "No preamble, no closing offer, no emoji, no headings beyond those asked for.",
        ]
        return lines.joined(separator: "\n")
    }

    public static let structureNotes = """
        Structure the live notes and transcript below into markdown with these sections and no
        others, in this order: Summary (exactly 3 bullets), Key concepts, Definitions, Worked
        examples, Exam-relevant points, Open questions.
        Keep the user's own terminology. Do not add material that is not in the notes or the
        transcript; if something is unclear or incomplete, list it under Open questions rather
        than filling the gap. Lines beginning ASK: are the user's own questions and belong under
        Open questions verbatim.
        """

    public static let makeFlashcards = """
        Make between 10 and 20 flashcards from the structured notes below. One idea per card.
        Fronts are questions, not topics. Backs are one or two sentences. No card may be
        answerable with yes or no. sourceLine is the line of the notes the card came from,
        quoted, or an empty string.
        Return only JSON, an array of objects: [{"front": "...", "back": "...", "sourceLine": "..."}]
        """

    public static let explain = """
        Explain the term or question below in plain language for this course, in at most 150
        words, with one worked example if that helps and none if it does not. If the current
        notes shed light on it, use their terminology. Return plain text, no markdown headings.
        """
}
