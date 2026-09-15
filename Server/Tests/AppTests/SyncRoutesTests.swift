import Foundation
import StudyBotCore
import Testing
import VaporTesting

@testable import App

/// §3.12 rows "Auth" and the integration half of "Sync merge": routes against an in-memory
/// SQLite server, through the real HTTP stack.
@Suite("Server routes", .serialized)
struct SyncRoutesTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func withServer(_ body: (Application) async throws -> Void) async throws {
        try await withApp(configure: configure) { app in
            try await body(app)
        }
    }

    /// Pairs a device the way the Mac does and returns its token.
    private func pair(_ app: Application, name: String) async throws -> PairResponse {
        let code = try await Pairing.issueCode(on: app.db, secret: app.settings.pairingSecret, now: Date())
        var paired: PairResponse?
        try await app.testing().test(
            .POST, "v1/auth/pair",
            beforeRequest: { req in
                req.headers.contentType = .json
                req.body = ByteBuffer(data: try SyncCoding.encode(PairRequest(code: code, deviceName: name)))
            },
            afterResponse: { res in
                #expect(res.status == .ok)
                paired = try SyncCoding.decode(PairResponse.self, from: Data(res.body.readableBytesView))
            })
        return try #require(paired)
    }

    private func push(
        _ app: Application, token: String, _ request: SyncPushRequest, expecting status: HTTPStatus = .ok
    ) async throws -> SyncPushResponse? {
        var decoded: SyncPushResponse?
        try await app.testing().test(
            .POST, "v1/sync",
            beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                req.headers.contentType = .json
                req.body = ByteBuffer(data: try SyncCoding.encode(request))
            },
            afterResponse: { res in
                #expect(res.status == status)
                if res.status == .ok {
                    decoded = try SyncCoding.decode(
                        SyncPushResponse.self, from: Data(res.body.readableBytesView))
                }
            })
        return decoded
    }

    private func pull(_ app: Application, token: String, since: Int, schema: Int = SyncSchema.current)
        async throws -> (HTTPStatus, SyncPullResponse?)
    {
        var result: (HTTPStatus, SyncPullResponse?) = (.internalServerError, nil)
        try await app.testing().test(
            .GET, "v1/sync?since=\(since)&limit=500",
            beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                req.headers.replaceOrAdd(name: SyncSchema.header, value: String(schema))
            },
            afterResponse: { res in
                let body =
                    res.status == .ok
                    ? try SyncCoding.decode(SyncPullResponse.self, from: Data(res.body.readableBytesView))
                    : nil
                result = (res.status, body)
            })
        return result
    }

    private func record(_ id: UUID, base: Int, at offset: TimeInterval, title: String) -> SyncRecord {
        SyncRecord(
            type: "assignment", id: id, baseVersion: base, updatedAt: t0.addingTimeInterval(offset),
            fields: ["title": .string(title), "grade": .null])
    }

    @Test("health answers without a token")
    func health() async throws {
        try await withServer { app in
            try await app.testing().test(.GET, "health") { res in
                #expect(res.status == .ok)
                #expect(res.body.string.contains("ok"))
            }
        }
    }

    @Test("a pairing code is single-use, expires after ten minutes, and a wrong code is refused")
    func pairingCodeRules() async throws {
        try await withServer { app in
            let secret = app.settings.pairingSecret
            let code = try await Pairing.issueCode(on: app.db, secret: secret, now: Date())
            #expect(code.split(separator: " ").count == 6)

            func attempt(_ text: String) async throws -> HTTPStatus {
                var status: HTTPStatus = .internalServerError
                try await app.testing().test(
                    .POST, "v1/auth/pair",
                    beforeRequest: { req in
                        req.headers.contentType = .json
                        req.body = ByteBuffer(
                            data: try SyncCoding.encode(PairRequest(code: text, deviceName: "Air")))
                    },
                    afterResponse: { res in status = res.status })
                return status
            }

            #expect(try await attempt("not the right words at all") == .unauthorized)
            #expect(try await attempt(code.uppercased() + "  ") == .ok, "case and spacing do not matter")
            #expect(try await attempt(code) == .unauthorized, "single use")

            // Expiry: a code issued eleven minutes ago.
            let old = try await Pairing.issueCode(
                on: app.db, secret: secret, now: Date().addingTimeInterval(-11 * 60))
            #expect(try await attempt(old) == .unauthorized)
        }
    }

    @Test("two devices hold independent tokens and a revoked token is refused")
    func tokensAreIndependent() async throws {
        try await withServer { app in
            let air = try await pair(app, name: "MacBook Air")
            let mini = try await pair(app, name: "Mac mini")
            #expect(air.token != mini.token)
            #expect(try await pull(app, token: air.token, since: 0).0 == .ok)
            #expect(try await pull(app, token: mini.token, since: 0).0 == .ok)
            #expect(try await pull(app, token: "made-up", since: 0).0 == .unauthorized)

            let device = try #require(try await DeviceToken.find(air.deviceRecordID, on: app.db))
            #expect(device.lastSeenAt != nil, "a successful call records last seen")
            device.revokedAt = Date().timeIntervalSince1970
            try await device.save(on: app.db)
            #expect(try await pull(app, token: air.token, since: 0).0 == .unauthorized)
            #expect(try await pull(app, token: mini.token, since: 0).0 == .ok, "the other Mac is untouched")
        }
    }

    @Test("push assigns version and seq, pull returns the record, a replay is idempotent")
    func pushPullReplay() async throws {
        try await withServer { app in
            let token = try await pair(app, name: "Air").token
            let id = UUID()
            let request = SyncPushRequest(
                deviceID: "air", cursor: 0, records: [record(id, base: 0, at: 1, title: "First")])
            let first = try #require(try await push(app, token: token, request))
            #expect(first.accepted == [SyncAccepted(id: id, version: 1, seq: 1)])
            #expect(first.cursor == 1)
            #expect(first.changes.first?.fields["title"] == "First")
            #expect(first.changes.first?.fields["grade"] == nil, "a null clears rather than stores")
            #expect(first.changes.first?.deviceID == "air")

            let replay = try #require(try await push(app, token: token, request))
            #expect(replay.accepted == [SyncAccepted(id: id, version: 1, seq: 1)])
            #expect(replay.conflicts.isEmpty)
            #expect(try await SyncService(db: app.db, now: Date()).headSeq() == 1)

            let (status, pulled) = try await pull(app, token: token, since: 0)
            #expect(status == .ok)
            #expect(pulled?.changes.count == 1)
            #expect(pulled?.cursor == 1)
            #expect(pulled?.hasMore == false)
        }
    }

    @Test("a conflicting push is refused, the loser is archived and retrievable, the winner is in changes")
    func conflictArchive() async throws {
        try await withServer { app in
            let token = try await pair(app, name: "Air").token
            let id = UUID()
            _ = try await push(
                app, token: token,
                SyncPushRequest(
                    deviceID: "air", cursor: 0, records: [record(id, base: 0, at: 1, title: "Original")]))
            // The Mini edits later and gets in first.
            let mini = try #require(
                try await push(
                    app, token: token,
                    SyncPushRequest(
                        deviceID: "mini", cursor: 1,
                        records: [record(id, base: 1, at: 200, title: "Mini's wording")])))
            #expect(mini.accepted.first?.version == 2)
            // The Air's earlier concurrent edit loses.
            let air = try #require(
                try await push(
                    app, token: token,
                    SyncPushRequest(
                        deviceID: "air", cursor: 1,
                        records: [record(id, base: 1, at: 100, title: "Air's wording")])))
            #expect(air.accepted.isEmpty)
            let conflict = try #require(air.conflicts.first)
            #expect(conflict.serverVersion == 2)
            #expect(conflict.resolution == .serverWins)
            #expect(air.changes.contains { $0.id == id && $0.fields["title"] == "Mini's wording" })

            try await app.testing().test(
                .GET, "v1/sync/archive/\(conflict.archivedAs)",
                beforeRequest: { req in req.headers.bearerAuthorization = .init(token: token) },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    let archived = try SyncCoding.decode(
                        ArchivedRecord.self, from: Data(res.body.readableBytesView))
                    #expect(archived.record.fields["title"] == "Air's wording")
                    #expect(archived.record.deviceID == "air")
                })
            try await app.testing().test(
                .GET, "v1/sync/archive/c_999",
                beforeRequest: { req in req.headers.bearerAuthorization = .init(token: token) },
                afterResponse: { res in #expect(res.status == .notFound) })
        }
    }

    @Test("a client one version behind syncs; two behind gets 409 with the required version")
    func schemaVersions() async throws {
        try await withServer { app in
            let token = try await pair(app, name: "Air").token
            let (okStatus, _) = try await pull(app, token: token, since: 0, schema: SyncSchema.oldestAccepted)
            #expect(okStatus == .ok)
            let (oldStatus, _) = try await pull(app, token: token, since: 0, schema: SyncSchema.current - 2)
            #expect(oldStatus == .conflict)

            var request = SyncPushRequest(deviceID: "air", cursor: 0, records: [])
            request.schemaVersion = SyncSchema.current - 2
            try await app.testing().test(
                .POST, "v1/sync",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = .init(token: token)
                    req.headers.contentType = .json
                    req.body = ByteBuffer(data: try SyncCoding.encode(request))
                },
                afterResponse: { res in
                    #expect(res.status == .conflict)
                    let refusal = try SyncCoding.decode(
                        SyncRefusal.self, from: Data(res.body.readableBytesView))
                    #expect(refusal.requiredVersion == SyncSchema.oldestAccepted)
                    #expect(refusal.serverVersion == SyncSchema.current)
                })
            // Nothing was written by the refused push.
            #expect(try await SyncService(db: app.db, now: Date()).headSeq() == 0)
        }
    }

    @Test("pull paginates past 500 and the cursor walks the pages")
    func pagination() async throws {
        try await withServer { app in
            let token = try await pair(app, name: "Air").token
            for batch in 0..<3 {
                let records = (0..<400).map { index in
                    record(UUID(), base: 0, at: Double(batch * 400 + index), title: "r\(batch * 400 + index)")
                }
                let response = try #require(
                    try await push(
                        app, token: token, SyncPushRequest(deviceID: "air", cursor: 1_200, records: records)))
                #expect(response.accepted.count == 400)
            }
            let (_, page1) = try await pull(app, token: token, since: 0)
            #expect(page1?.changes.count == 500)
            #expect(page1?.hasMore == true)
            #expect(page1?.cursor == 500)
            let (_, page2) = try await pull(app, token: token, since: 500)
            #expect(page2?.changes.count == 500)
            #expect(page2?.hasMore == true)
            let (_, page3) = try await pull(app, token: token, since: 1_000)
            #expect(page3?.changes.count == 200)
            #expect(page3?.hasMore == false)
            #expect(page3?.cursor == 1_200)
            // A client ahead of the server (restored from backup) sees the cursor come back.
            let (_, ahead) = try await pull(app, token: token, since: 5_000)
            #expect(ahead?.changes.isEmpty == true)
            #expect(ahead?.cursor == 1_200)
        }
    }

    @Test("tombstones older than 90 days are purged and seqs keep counting")
    func purge() async throws {
        try await withServer { app in
            let token = try await pair(app, name: "Air").token
            let id = UUID()
            var deletion = record(id, base: 0, at: -100 * 86_400, title: "old")
            deletion.deletedAt = t0.addingTimeInterval(-100 * 86_400)
            _ = try await push(
                app, token: token, SyncPushRequest(deviceID: "air", cursor: 0, records: [deletion]))
            let service = SyncService(db: app.db, now: t0)
            #expect(try await service.purgeTombstones() == 1)
            #expect(try await RecordRow.find(id, on: app.db) == nil)
            #expect(try await service.headSeq() == 1, "the log keeps the seq")
        }
    }
}
