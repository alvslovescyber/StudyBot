import Fluent
import Foundation
import Vapor

/// `device_tokens` (§3.6): one row per paired Mac. The token itself is never stored, only its
/// SHA-256; revoking a row is how a lost laptop is dealt with.
final class DeviceToken: Model, Authenticatable, @unchecked Sendable {
    static let schema = "device_tokens"

    @ID(key: .id) var id: UUID?
    @Field(key: "name") var name: String
    @Field(key: "token_hash") var tokenHash: String
    @Field(key: "created_at") var createdAt: Double
    @OptionalField(key: "last_seen_at") var lastSeenAt: Double?
    @OptionalField(key: "revoked_at") var revokedAt: Double?

    init() {}

    init(name: String, tokenHash: String, createdAt: Date) {
        self.name = name
        self.tokenHash = tokenHash
        self.createdAt = createdAt.timeIntervalSince1970
    }

    var isRevoked: Bool { revokedAt != nil }
}
