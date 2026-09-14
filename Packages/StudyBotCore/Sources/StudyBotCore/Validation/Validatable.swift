/// One set of rules, both sides (spec §3.2 `Validation/`). The client validates before
/// saving; the server validates the same way before accepting a push.
public protocol Validatable {
    /// Every problem with the record. Empty means valid.
    func validationIssues() -> [ValidationIssue]
}

extension Validatable {
    /// Whether the record has no issues.
    public var isValid: Bool { validationIssues().isEmpty }

    /// Throws `ValidationError` carrying every issue when the record is invalid.
    public func validate() throws(ValidationError) {
        let issues = validationIssues()
        if !issues.isEmpty {
            throw ValidationError(issues: issues)
        }
    }
}

/// Shared checks so each model's rules read as one line each.
enum Rules {
    static func nonEmpty(_ value: String, field: String) -> ValidationIssue? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ValidationIssue(field: field, message: "Can't be empty") : nil
    }

    static func percentage(_ value: Double?, field: String) -> ValidationIssue? {
        guard let value else { return nil }
        return (0...100).contains(value)
            ? nil : ValidationIssue(field: field, message: "Must be between 0 and 100")
    }

    static func positive(_ value: Int?, field: String) -> ValidationIssue? {
        guard let value else { return nil }
        return value > 0 ? nil : ValidationIssue(field: field, message: "Must be more than 0")
    }

    static func inRange(_ value: Int, _ range: ClosedRange<Int>, field: String) -> ValidationIssue? {
        range.contains(value)
            ? nil
            : ValidationIssue(
                field: field, message: "Must be between \(range.lowerBound) and \(range.upperBound)")
    }
}
