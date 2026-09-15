import Foundation
import StudyBotCore

/// The real transport: `GET` and `POST /v1/sync` over URLSession with a bearer token (§3.5,
/// §3.6). Bodies are Core DTOs through `SyncCoding`, so the client cannot disagree with the
/// server about shape. Every call has a timeout; a failure is classified, never swallowed.
public struct HTTPSyncTransport: SyncTransport {
    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = HTTPSyncTransport.makeSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Thirty seconds per request: long enough for a 500-record page, short enough that a
    /// dead server does not hold the engine for minutes.
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    public func push(_ request: SyncPushRequest, token: String) async throws -> SyncPushResponse {
        var urlRequest = URLRequest(url: baseURL.appending(path: "v1/sync"))
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try SyncCoding.encode(request)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(urlRequest, token: token, schemaVersion: request.schemaVersion)
    }

    public func pull(since: Int, limit: Int, schemaVersion: Int, token: String) async throws
        -> SyncPullResponse
    {
        var components = URLComponents(
            url: baseURL.appending(path: "v1/sync"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "since", value: String(since)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components?.url else { throw SyncTransportError.unreachable("Bad server address") }
        return try await send(URLRequest(url: url), token: token, schemaVersion: schemaVersion)
    }

    private func send<Response: Decodable>(_ request: URLRequest, token: String, schemaVersion: Int)
        async throws
        -> Response
    {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(String(schemaVersion), forHTTPHeaderField: SyncSchema.header)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SyncTransportError.unreachable(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw SyncTransportError.server(status: 0, detail: "Not an HTTP response")
        }
        switch http.statusCode {
        case 200..<300:
            do {
                return try SyncCoding.decode(Response.self, from: data)
            } catch {
                throw SyncTransportError.server(status: http.statusCode, detail: "Unreadable response")
            }
        case 401, 403:
            throw SyncTransportError.unauthorised
        case 409:
            guard let refusal = try? SyncCoding.decode(SyncRefusal.self, from: data) else {
                throw SyncTransportError.server(status: 409, detail: "Conflict without a schema refusal")
            }
            throw SyncTransportError.schemaRefused(refusal)
        default:
            throw SyncTransportError.server(status: http.statusCode, detail: "HTTP \(http.statusCode)")
        }
    }
}
