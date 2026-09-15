import Foundation
import StudyBotCore

/// `POST /v1/auth/pair` from the Mac's side (§3.6, §6.0 "Server pairing"). Errors are
/// already plain language, because §6.0 says the message names the likely cause rather than
/// saying "failed".
public protocol PairingClient: Sendable {
    func pair(_ request: PairRequest, at baseURL: URL) async throws -> PairResponse
}

public enum PairingError: Error, Equatable, Sendable {
    case badAddress(String)
    case unreachable(URL, String)
    case refused(String)
    case server(Int)

    /// What Settings shows.
    public var message: String {
        switch self {
        case .badAddress(let text):
            return "\"\(text)\" is not a server address. It looks like https://studybot.example.com."
        case .unreachable(let url, _):
            return "Couldn't reach \(url.absoluteString). Check the address, and that the server is running."
        case .refused(let reason):
            return reason
        case .server(let status):
            return "The server answered with HTTP \(status). Check its logs."
        }
    }
}

public struct HTTPPairingClient: PairingClient {
    private let session: URLSession

    public init(session: URLSession = HTTPSyncTransport.makeSession()) {
        self.session = session
    }

    public func pair(_ request: PairRequest, at baseURL: URL) async throws -> PairResponse {
        var urlRequest = URLRequest(url: baseURL.appending(path: "v1/auth/pair"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try SyncCoding.encode(request)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw PairingError.unreachable(baseURL, error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            do {
                return try SyncCoding.decode(PairResponse.self, from: data)
            } catch {
                throw PairingError.server(status)
            }
        case 400, 401:
            throw PairingError.refused(
                ServerReason.parse(data)
                    ?? "That pairing code is not valid. Run studybotctl pair for a new one.")
        default:
            throw PairingError.server(status)
        }
    }

    /// Normalises what the user typed into a base URL: scheme added if missing, trailing slash dropped.
    public static func baseURL(from text: String) throws -> URL {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if !trimmed.contains("://") { trimmed = "https://" + trimmed }
        guard let url = URL(string: trimmed), let host = url.host(), !host.isEmpty else {
            throw PairingError.badAddress(text)
        }
        return url
    }
}

/// Vapor's error body: `{"error": true, "reason": "..."}`.
enum ServerReason {
    private struct Body: Decodable {
        let reason: String
    }

    static func parse(_ data: Data) -> String? {
        try? JSONDecoder().decode(Body.self, from: data).reason
    }
}
