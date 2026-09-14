import Foundation

// Validation rules for the models that accept user input. Calendar-derived records
// (ProgrammeEvent, Term) are produced by the importer and are not validated here.

extension Assignment: Validatable {
    public func validationIssues() -> [ValidationIssue] {
        [
            Rules.nonEmpty(title, field: "title"),
            Rules.percentage(targetGrade, field: "targetGrade"),
            Rules.percentage(grade, field: "grade"),
            Rules.percentage(weighting, field: "weighting"),
            Rules.positive(wordLimit, field: "wordLimit"),
        ].compactMap { $0 }
    }
}

extension Module: Validatable {
    public func validationIssues() -> [ValidationIssue] {
        var issues = [
            Rules.nonEmpty(name, field: "name"),
            Rules.nonEmpty(code, field: "code"),
            Rules.inRange(year, 1...3, field: "year"),
            Rules.percentage(weighting, field: "weighting"),
            Rules.positive(credits, field: "credits"),
        ].compactMap { $0 }
        if let termNumber, !(1...3).contains(termNumber) {
            issues.append(ValidationIssue(field: "termNumber", message: "Must be 1, 2 or 3"))
        }
        if spansYear && termNumber != nil {
            issues.append(
                ValidationIssue(field: "termNumber", message: "A module that spans the year has no term"))
        }
        return issues
    }
}

extension Session: Validatable {
    public func validationIssues() -> [ValidationIssue] {
        [Rules.nonEmpty(title, field: "title")].compactMap { $0 }
    }
}

extension Card: Validatable {
    public func validationIssues() -> [ValidationIssue] {
        [
            Rules.nonEmpty(front, field: "front"),
            Rules.nonEmpty(back, field: "back"),
            Rules.inRange(box, 1...Card.intervals.count, field: "box"),
            lapses >= 0 ? nil : ValidationIssue(field: "lapses", message: "Can't be negative"),
        ].compactMap { $0 }
    }
}

extension KSB: Validatable {
    public func validationIssues() -> [ValidationIssue] {
        [
            Rules.nonEmpty(code, field: "code"),
            Rules.nonEmpty(text, field: "text"),
        ].compactMap { $0 }
    }
}

extension Evidence: Validatable {
    public func validationIssues() -> [ValidationIssue] {
        [
            Rules.nonEmpty(title, field: "title"),
            Rules.nonEmpty(summary, field: "summary"),
        ].compactMap { $0 }
    }
}

extension OTJEntry: Validatable {
    public func validationIssues() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if !(hours > 0) {
            issues.append(ValidationIssue(field: "hours", message: "Must be more than 0"))
        } else if hours > 24 {
            issues.append(ValidationIssue(field: "hours", message: "Can't be more than 24 in a day"))
        }
        return issues
    }
}

extension Settings: Validatable {
    public func validationIssues() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if !(targetOTJHoursPerWeek > 0) {
            issues.append(ValidationIssue(field: "targetOTJHoursPerWeek", message: "Must be more than 0"))
        }
        if monthlyAIBudgetPence < 0 {
            issues.append(ValidationIssue(field: "monthlyAIBudgetPence", message: "Can't be negative"))
        }
        if gradeBands.isEmpty {
            issues.append(ValidationIssue(field: "gradeBands", message: "Needs at least one band"))
        }
        for band in gradeBands {
            if let issue = Rules.percentage(band.minimum, field: "gradeBands") {
                issues.append(issue)
                break
            }
        }
        let orders = otjExportMapping.map(\.order)
        if Set(orders).count != orders.count {
            issues.append(
                ValidationIssue(field: "otjExportMapping", message: "Two columns share the same position"))
        }
        return issues
    }
}

extension Proposal: Validatable {
    public func validationIssues() -> [ValidationIssue] {
        var issues = [
            Rules.nonEmpty(sourceRef, field: "sourceRef"),
            Rules.nonEmpty(title, field: "title"),
        ].compactMap { $0 }
        if state == .dismissed, dismissedReason?.isEmpty ?? true {
            // Optional by design: dismissing never asks why (§6.1). Recorded when known.
            _ = issues.count
        }
        if state != .pending, resolvedAt == nil {
            issues.append(
                ValidationIssue(field: "resolvedAt", message: "A resolved proposal needs a resolution time"))
        }
        return issues
    }
}
