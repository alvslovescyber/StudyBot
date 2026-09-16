import Vapor

/// The §3.5 surface that exists so far: health, pairing and sync. Blobs, AI and ingestion
/// arrive with their milestones.
func routes(_ app: Application) throws {
    app.get("health") { _ in
        HealthResponse(status: "ok")
    }

    let v1 = app.grouped("v1")
    try v1.register(collection: AuthRoutes())

    guard let limiters = app.storage[Application.RateLimitersKey.self] else {
        throw Abort(.internalServerError, reason: "rate limiters not configured")
    }
    let authenticated = v1.grouped(
        DeviceTokenAuthenticator(), DeviceToken.guardMiddleware(),
        RateLimitMiddleware(limiter: limiters.overall, scope: "overall"))
    try authenticated.register(collection: SyncRoutes())
    try authenticated.grouped(RateLimitMiddleware(limiter: limiters.ai, scope: "ai")).register(
        collection: AIRoutes())
}

struct HealthResponse: Content {
    let status: String
}
