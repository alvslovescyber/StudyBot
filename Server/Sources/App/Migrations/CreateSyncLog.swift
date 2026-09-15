import Fluent

struct CreateSyncLog: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(SyncLogRow.schema)
            .field("seq", .int, .identifier(auto: false))
            .field("record_id", .uuid, .required)
            .field("record_type", .string, .required)
            .field("device_id", .string, .required)
            .field("at", .double, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(SyncLogRow.schema).delete()
    }
}
