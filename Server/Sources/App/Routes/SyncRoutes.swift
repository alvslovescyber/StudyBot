import StudyBotCore
import Vapor

/// `GET /v1/sync`, `POST /v1/sync` and `GET /v1/sync/archive/:id` (§3.5), behind the device
/// token. Logs say how many records moved, never what they contained (§3.10).
struct SyncRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let sync = routes.grouped("sync")

        sync.get { req async throws -> Response in
            let since = req.query[Int.self, at: "since"] ?? 0
            let limit = req.query[Int.self, at: "limit"] ?? SyncPullResponse.pageSize
            guard let header = req.headers.first(name: SyncSchema.header), let schemaVersion = Int(header)
            else {
                throw Abort(
                    .badRequest, reason: "Send the schema version in the \(SyncSchema.header) header.")
            }
            do {
                try SchemaGuard.check(schemaVersion)
            } catch let refused as SchemaRefusedError {
                return try SyncContentEncoder.response(refused.refusal, status: .conflict)
            }
            let response = try await SyncService(db: req.db, now: Date()).pull(since: since, limit: limit)
            req.logger.info("pull: \(response.changes.count) change(s) since \(since)")
            return try SyncContentEncoder.response(response, status: .ok)
        }

        sync.post { req async throws -> Response in
            let body = try req.content.decode(SyncPushRequest.self, using: SyncContentDecoder())
            guard body.records.count <= SyncPullResponse.pageSize else {
                throw Abort(
                    .payloadTooLarge, reason: "Push at most \(SyncPullResponse.pageSize) records at a time.")
            }
            do {
                let response = try await SyncService(db: req.db, now: Date()).push(body)
                req.logger.info(
                    "push: \(response.accepted.count) accepted, \(response.conflicts.count) conflict(s), \(response.changes.count) change(s)"
                )
                return try SyncContentEncoder.response(response, status: .ok)
            } catch let refused as SchemaRefusedError {
                return try SyncContentEncoder.response(refused.refusal, status: .conflict)
            }
        }

        sync.get("archive", ":id") { req async throws -> Response in
            let id = req.parameters.get("id") ?? ""
            guard let archived = try await SyncService(db: req.db, now: Date()).archived(id) else {
                throw Abort(.notFound, reason: "No archived version named \(id).")
            }
            return try SyncContentEncoder.response(archived, status: .ok)
        }
    }
}

/// Bodies go through `SyncCoding`, the one wire configuration, not Vapor's default JSON coder.
struct SyncContentDecoder: ContentDecoder {
    func decode<D: Decodable>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D {
        try SyncCoding.decode(D.self, from: Data(body.readableBytesView))
    }

    func decode<D: Decodable>(
        _ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders,
        userInfo: [CodingUserInfoKey: any Sendable]
    ) throws -> D {
        try decode(decodable, from: body, headers: headers)
    }
}

enum SyncContentEncoder {
    static func response<T: Encodable>(_ value: T, status: HTTPResponseStatus) throws -> Response {
        let response = Response(status: status)
        response.headers.contentType = .json
        response.body = .init(data: try SyncCoding.encode(value))
        return response
    }
}
