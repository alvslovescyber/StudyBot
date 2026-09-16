import Fluent

struct CreateAITables: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(AIRunRow.schema)
            .id()
            .field("capability", .string, .required)
            .field("model", .string, .required)
            .field("input_tokens", .int, .required)
            .field("output_tokens", .int, .required)
            .field("cost_pence", .int, .required)
            .field("cache_hit", .bool, .required)
            .field("created_at", .double, .required)
            .field("related_assignment_id", .uuid)
            .field("device_id", .uuid, .required)
            .create()
        try await database.schema(AICacheRow.schema)
            .field("input_hash", .string, .identifier(auto: false))
            .field("capability", .string, .required)
            .field("model", .string, .required)
            .field("response", .string, .required)
            .field("input_tokens", .int, .required)
            .field("output_tokens", .int, .required)
            .field("created_at", .double, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(AICacheRow.schema).delete()
        try await database.schema(AIRunRow.schema).delete()
    }
}
