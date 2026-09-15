import Foundation

/// Body of `POST /v1/auth/pair` (spec §3.6): the six-word code `studybotctl pair` printed,
/// and the name this Mac wants to be known by in Settings ("MacBook Pro", "Mac mini").
public struct PairRequest: Codable, Hashable, Sendable {
    public var code: String
    public var deviceName: String

    public init(code: String, deviceName: String) {
        self.code = code
        self.deviceName = deviceName
    }
}
