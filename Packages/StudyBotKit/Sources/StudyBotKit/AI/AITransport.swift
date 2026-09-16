import Foundation
import StudyBotCore

/// How the client reaches `/v1/ai/*` (§3.7). The HTTP transport is the real one; tests use a
/// fake. Refusals come back typed so the store can show §9's copy for each.
public protocol AITransport: Sendable {
    func run(_ request: AIRunRequest, token: String) async throws -> AIRunResponse
    func budget(token: String) async throws -> AIBudget
}

public enum AITransportError: Error, Equatable, Sendable {
    /// 402, 422, 429 or 502 with the server's reason.
    case refused(AIRefusal)
    case unauthorised
    case unreachable(String)
    case server(status: Int)
}

public struct HTTPAITransport: AITransport {
    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = HTTPAITransport.makeSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    /// AI answers take longer than a sync page; ninety seconds before giving up.
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 90
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    public func run(_ request: AIRunRequest, token: String) async throws -> AIRunResponse {
        var urlRequest = URLRequest(url: baseURL.appending(path: "v1/ai/run"))
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try SyncCoding.encode(request)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(urlRequest, token: token)
    }

    public func budget(token: String) async throws -> AIBudget {
        try await send(URLRequest(url: baseURL.appending(path: "v1/ai/budget")), token: token)
    }

    private func send<Response: Decodable>(_ request: URLRequest, token: String) async throws -> Response {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(String(SyncSchema.current), forHTTPHeaderField: SyncSchema.header)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AITransportError.unreachable(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            do {
                return try SyncCoding.decode(Response.self, from: data)
            } catch {
                throw AITransportError.server(status: status)
            }
        case 401, 403:
            throw AITransportError.unauthorised
        case 402, 422, 429, 502:
            guard let refusal = try? SyncCoding.decode(AIRefusal.self, from: data) else {
                throw AITransportError.server(status: status)
            }
            throw AITransportError.refused(refusal)
        default:
            throw AITransportError.server(status: status)
        }
    }
}
