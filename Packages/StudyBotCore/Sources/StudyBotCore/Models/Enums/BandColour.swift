/// Colour of a grade band badge. The spec names `BandColour` in Supporting types without
/// listing cases; the values come from §6.2: "distinction green, merit indigo, pass grey,
/// fail red".
public enum BandColour: String, Codable, CaseIterable, Hashable, Sendable {
    case green
    case indigo
    case grey
    case red
}
