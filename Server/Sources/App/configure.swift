import Fluent
import FluentSQLiteDriver
import Vapor

/// Wires the server together. Configuration comes from the environment (§3.10b); nothing
/// here reads a file in the repo. Tests call this with the testing environment, which uses an
/// in-memory database and a fixed pairing secret.
func configure(_ app: Application) async throws {
    let settings = try ServerSettings.fromEnvironment(app.environment)
    app.storage[ServerSettings.Key.self] = settings

    switch settings.databasePath {
    case .some(let path):
        app.databases.use(.sqlite(.file(path)), as: .sqlite)
    case .none:
        app.databases.use(.sqlite(.memory), as: .sqlite)
    }

    app.migrations.add(CreateRecords())
    app.migrations.add(CreateSyncLog())
    app.migrations.add(CreateConflictArchive())
    app.migrations.add(CreateDeviceTokens())
    app.migrations.add(CreatePairingCodes())
    app.migrations.add(CreateAITables())
    try await app.autoMigrate()

    let ai = AISettings.fromEnvironment(app.environment)
    app.storage[AISettings.Key.self] = ai
    app.storage[Application.RateLimitersKey.self] = (
        overall: RateLimiter(perMinute: ai.requestsPerMinute),
        ai: RateLimiter(perMinute: ai.aiRequestsPerMinute)
    )
    if Environment.get("OPENAI_API_KEY") == nil && app.environment != .testing {
        app.logger.warning("OPENAI_API_KEY is not set: AI answers come from the canned provider")
    }

    // §3.10: request bodies capped. A page of 500 records is well under this.
    app.routes.defaultMaxBodySize = "4mb"

    app.asyncCommands.use(PairCommand(), as: "pair")
    app.asyncCommands.use(DevicesCommand(), as: "devices")
    app.asyncCommands.use(RevokeCommand(), as: "revoke")
    app.asyncCommands.use(PurgeTombstonesCommand(), as: "purge-tombstones")

    try routes(app)
}

/// The environment keys the server reads (§3.10b).
struct ServerSettings: Sendable {
    /// Nil means in-memory, which only the testing environment uses.
    let databasePath: String?
    /// Signs pairing codes so the stored hash is useless without it.
    let pairingSecret: String

    struct Key: StorageKey {
        typealias Value = ServerSettings
    }

    static func fromEnvironment(_ environment: Environment) throws -> ServerSettings {
        if environment == .testing {
            return ServerSettings(databasePath: nil, pairingSecret: "testing-secret")
        }
        guard let secret = Environment.get("STUDYBOT_PAIRING_SECRET"), !secret.isEmpty else {
            throw Abort(
                .internalServerError,
                reason: "STUDYBOT_PAIRING_SECRET is not set. Put it in the 0600 env file (see .env.example).")
        }
        guard let path = Environment.get("STUDYBOT_DB_PATH"), !path.isEmpty else {
            throw Abort(.internalServerError, reason: "STUDYBOT_DB_PATH is not set. See .env.example.")
        }
        return ServerSettings(databasePath: path, pairingSecret: secret)
    }
}

extension Application {
    var settings: ServerSettings {
        guard let settings = storage[ServerSettings.Key.self] else {
            // configure() always stores settings before anything reads them.
            return ServerSettings(databasePath: nil, pairingSecret: "")
        }
        return settings
    }
}
