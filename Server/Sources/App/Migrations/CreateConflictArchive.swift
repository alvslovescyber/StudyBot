import Fluent

struct CreateConflictArchive: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(ConflictArchiveRow.schema)
            .field("id", .int, .identifier(auto: true))
            .field("record_id", .uuid, .required)
            .field("record_type", .string, .required)
            .field("body", .string, .required)
            .field("losing_updated_at", .double, .required)
            .field("archived_at", .double, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ConflictArchiveRow.schema).delete()
    }
}
