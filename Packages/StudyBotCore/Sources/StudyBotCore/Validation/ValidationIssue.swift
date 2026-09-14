/// One thing wrong with a record, named by field, in words the UI can show as-is
/// (spec §9 "Errors say what happened and what fixes it").
public struct ValidationIssue: Hashable, Sendable, CustomStringConvertible {
    /// The model property at fault, e.g. `"title"`.
    public let field: String
    /// Plain English, sentence case, no full stop needed by the caller.
    public let message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }

    public var description: String { "\(field): \(message)" }
}

/// Thrown when a record fails validation. Carries every issue, not just the first, so a
/// form can mark all of them at once.
public struct ValidationError: Error, Hashable, Sendable {
    public let issues: [ValidationIssue]

    public init(issues: [ValidationIssue]) {
        self.issues = issues
    }
}
