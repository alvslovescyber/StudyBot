/// A `BEGIN:…`/`END:…` block: the calendar itself, a `VEVENT`, a `VALARM`, and so on.
public struct ICSComponent: Hashable, Sendable {
    /// Upper-cased component name, e.g. `VEVENT`.
    public var name: String
    public var properties: [ICSProperty]
    public var children: [ICSComponent]

    public init(name: String, properties: [ICSProperty] = [], children: [ICSComponent] = []) {
        self.name = name
        self.properties = properties
        self.children = children
    }

    /// The first property with this name, case-insensitively.
    public func property(_ name: String) -> ICSProperty? {
        let wanted = name.uppercased()
        return properties.first { $0.name == wanted }
    }

    /// Every property with this name, in file order.
    public func properties(named name: String) -> [ICSProperty] {
        let wanted = name.uppercased()
        return properties.filter { $0.name == wanted }
    }

    /// Direct children with this name, in file order.
    public func children(named name: String) -> [ICSComponent] {
        let wanted = name.uppercased()
        return children.filter { $0.name == wanted }
    }

    /// Every `VEVENT` directly inside this component.
    public var events: [ICSComponent] { children(named: "VEVENT") }
}
