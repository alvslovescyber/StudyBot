import Vapor

/// The §3.5 surface that exists so far: health, pairing and sync. Blobs, AI and ingestion
/// arrive with their milestones.
func routes(_ app: Application) throws {
    app.get("health") { _ in
        HealthResponse(status: "ok")
    }

    let v1 = app.grouped("v1")
    try v1.register(collection: AuthRoutes())

    let authenticated = v1.grouped(DeviceTokenAuthenticator(), DeviceToken.guardMiddleware())
    try authenticated.register(collection: SyncRoutes())
}

struct HealthResponse: Content {
    let status: String
}
