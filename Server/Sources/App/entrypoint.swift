import Logging
import Vapor

/// `studybotctl`: `serve` (the default) runs the server; `pair`, `devices`, `revoke` and
/// `purge-tombstones` are the operator's commands (§3.6, §3.4).
@main
enum Entrypoint {
    static func main() async throws {
        var environment = try Environment.detect()
        try LoggingSystem.bootstrap(from: &environment)
        let app = try await Application.make(environment)
        do {
            try await configure(app)
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.execute()
        try await app.asyncShutdown()
    }
}
