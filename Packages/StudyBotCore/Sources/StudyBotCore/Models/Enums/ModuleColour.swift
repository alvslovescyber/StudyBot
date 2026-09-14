/// One of eight fixed module colours (spec §4 Supporting types), all desaturated so no
/// module visually dominates. Assigned round-robin on import; user-changeable.
public enum ModuleColour: String, Codable, CaseIterable, Hashable, Sendable {
    case indigo
    case green
    case amber
    case clay
    case violet
    case teal
    case brown
    case slate

    /// The exact hex value from the spec. Rendering lives in StudyBotUI; this is the token.
    public var hex: String {
        switch self {
        case .indigo: "#5E6AD2"
        case .green: "#4A9E6B"
        case .amber: "#D9A441"
        case .clay: "#B4695E"
        case .violet: "#7B6BA8"
        case .teal: "#3E8E9E"
        case .brown: "#9A7B5E"
        case .slate: "#6B7280"
        }
    }

    /// The colour for the `index`-th module when assigning round-robin on import.
    public static func roundRobin(_ index: Int) -> ModuleColour {
        let cases = allCases
        let wrapped = ((index % cases.count) + cases.count) % cases.count
        return cases[wrapped]
    }
}
