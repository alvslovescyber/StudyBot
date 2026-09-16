import Foundation
import StudyBotCore
import Vapor

/// Token buckets per device token (§3.7): 60 requests a minute overall, 10 for AI. Refuses
/// with 429 and Retry-After; the client's Retrier honours it.
actor RateLimiter {
    private var buckets: [String: TokenBucket] = [:]
    private let perMinute: Int

    init(perMinute: Int) {
        self.perMinute = perMinute
    }

    func take(_ key: String, now: Date) -> (allowed: Bool, retryAfter: Int) {
        var bucket = buckets[key] ?? TokenBucket(perMinute: perMinute, now: now)
        let result = bucket.take(at: now)
        buckets[key] = bucket
        return (result.allowed, Int(result.retryAfter.rounded(.up)))
    }
}

struct RateLimitMiddleware: AsyncMiddleware {
    let limiter: RateLimiter
    let scope: String

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let key =
            (request.auth.get(DeviceToken.self)?.id?.uuidString ?? request.remoteAddress?.description
                ?? "anonymous")
        let result = await limiter.take(key, now: Date())
        guard result.allowed else {
            let response = try SyncContentEncoder.response(
                AIRefusal(reason: .rateLimited, retryAfterSeconds: result.retryAfter),
                status: .tooManyRequests)
            response.headers.replaceOrAdd(name: .retryAfter, value: String(result.retryAfter))
            request.logger.info("rate limited (\(scope))")
            return response
        }
        return try await next.respond(to: request)
    }
}

extension Application {
    struct RateLimitersKey: StorageKey {
        typealias Value = (overall: RateLimiter, ai: RateLimiter)
    }
}
