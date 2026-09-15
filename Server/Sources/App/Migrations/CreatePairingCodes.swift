import Fluent

struct CreatePairingCodes: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(PairingCode.schema)
            .id()
            .field("code_hash", .string, .required)
            .field("created_at", .double, .required)
            .field("expires_at", .double, .required)
            .field("used_at", .double)
            .unique(on: "code_hash")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(PairingCode.schema).delete()
    }
}
