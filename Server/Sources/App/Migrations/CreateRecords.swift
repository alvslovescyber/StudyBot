import Fluent

struct CreateRecords: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(RecordRow.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("record_type", .string, .required)
            .field("version", .int, .required)
            .field("seq", .int, .required)
            .field("updated_at", .double, .required)
            .field("deleted_at", .double)
            .field("device_id", .string, .required)
            .field("fields", .string, .required)
            .field("replaced_archive_id", .string)
            .unique(on: "seq")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(RecordRow.schema).delete()
    }
}
