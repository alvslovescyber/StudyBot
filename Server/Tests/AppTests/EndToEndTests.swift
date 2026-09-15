import Foundation
import StudyBotCore
import StudyBotKit
import Testing
import VaporTesting

@testable import App

/// The whole stack: the real server listening on a port, two real client stores, the real
/// `SyncEngine` over `HTTPSyncTransport` with tokens from the real pairing flow. If this
/// passes, two Macs on the same network will converge.
@Suite("End to end over HTTP", .serialized)
struct EndToEndTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private struct Client {
        let database: Database
        let engine: SyncEngine
    }

    private func makeClient(_ name: String, baseURL: URL, token: String) async throws -> Client {
        let database = try Database.inMemory()
        var state = SyncState()
        state.serverURL = baseURL
        state.deviceName = name
        try await database.saveSyncState(state)
        let engine = SyncEngine(
            database: database, transport: HTTPSyncTransport(baseURL: baseURL),
            credentials: InMemoryCredentialStore(token: token), deviceID: name, now: { Date() })
        return Client(database: database, engine: engine)
    }

    private func pairOverHTTP(_ app: Application, baseURL: URL, name: String) async throws -> String {
        let code = try await Pairing.issueCode(on: app.db, secret: app.settings.pairingSecret, now: Date())
        var request = URLRequest(url: baseURL.appending(path: "v1/auth/pair"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try SyncCoding.encode(PairRequest(code: code, deviceName: name))
        let (data, response) = try await URLSession.shared.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        return try SyncCoding.decode(PairResponse.self, from: data).token
    }

    @Test("two Macs pair, diverge offline, and converge through the real server")
    func twoMacsConverge() async throws {
        try await withApp(configure: configure) { app in
            app.http.server.configuration.port = 0
            app.http.server.configuration.hostname = "127.0.0.1"
            try await app.server.start()
            var failure: (any Error)?
            do {
                try await exercise(app)
            } catch {
                failure = error
            }
            await app.server.shutdown()
            if let failure { throw failure }
        }
    }

    private func exercise(_ app: Application) async throws {
        do {
            let port = try #require(app.http.server.shared.localAddress?.port)
            let baseURL = try #require(URL(string: "http://127.0.0.1:\(port)"))

            let air = try await makeClient(
                "air", baseURL: baseURL, token: pairOverHTTP(app, baseURL: baseURL, name: "Air"))
            let mini = try await makeClient(
                "mini", baseURL: baseURL, token: pairOverHTTP(app, baseURL: baseURL, name: "Mini"))

            // The Air creates a record and syncs; the Mini receives it.
            let id = UUID()
            var assignment = Assignment(
                sync: .new(id: id, at: t0, deviceID: "air"), title: "Requirements report")
            try await air.database.save(assignment)
            #expect(await air.engine.sync() == .synced(pushed: 1, pulled: 1))
            #expect(await mini.engine.sync() == .synced(pushed: 0, pulled: 1))
            #expect(
                try await mini.database.fetch(Assignment.self, id: id)?.value.title == "Requirements report")

            // Both edit offline at the same millisecond; the lower deviceID wins on both.
            assignment = try #require(try await air.database.fetch(Assignment.self, id: id)).value
            assignment.title = "Air's wording"
            assignment.sync.markEdited(at: t0.addingTimeInterval(100.5), by: "air")
            try await air.database.save(assignment)
            var onMini = try #require(try await mini.database.fetch(Assignment.self, id: id)).value
            onMini.title = "Mini's wording"
            onMini.sync.markEdited(at: t0.addingTimeInterval(100.5), by: "mini")
            try await mini.database.save(onMini)

            _ = await mini.engine.sync()
            _ = await air.engine.sync()
            _ = await mini.engine.sync()

            #expect(try await air.database.fetch(Assignment.self, id: id)?.value.title == "Air's wording")
            #expect(try await mini.database.fetch(Assignment.self, id: id)?.value.title == "Air's wording")
            #expect(try await air.database.dirtyWireRecords().isEmpty)
            #expect(try await mini.database.dirtyWireRecords().isEmpty)

            // The Mini's version is retrievable from the server archive, by the id the client kept.
            let losers = try await mini.database.conflictLosers(for: id)
            #expect(losers.count == 1)
            #expect(losers.first?.record.fields["title"] == "Mini's wording")
            let archiveID = try #require(losers.first?.serverArchiveID)
            let archived = try #require(try await SyncService(db: app.db, now: Date()).archived(archiveID))
            #expect(archived.record.fields["title"] == "Mini's wording")

            // A revoked Mac is told so and keeps its data.
            let devices = try await DeviceToken.query(on: app.db).all()
            for device in devices where device.name == "Mini" {
                device.revokedAt = Date().timeIntervalSince1970
                try await device.save(on: app.db)
            }
            onMini = try #require(try await mini.database.fetch(Assignment.self, id: id)).value
            onMini.title = "Edited after revocation"
            onMini.sync.markEdited(at: t0.addingTimeInterval(500), by: "mini")
            try await mini.database.save(onMini)
            #expect(await mini.engine.sync() == .unauthorised)
            #expect(try await mini.database.dirtyWireRecords().count == 1)
        }
    }
}
