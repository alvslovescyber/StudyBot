import Fluent

struct CreateDeviceTokens: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(DeviceToken.schema)
            .id()
            .field("name", .string, .required)
            .field("token_hash", .string, .required)
            .field("created_at", .double, .required)
            .field("last_seen_at", .double)
            .field("revoked_at", .double)
            .unique(on: "token_hash")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(DeviceToken.schema).delete()
    }
}
