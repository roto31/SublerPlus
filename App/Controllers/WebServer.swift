import Foundation
import Swifter
import UniformTypeIdentifiers

public struct SearchRequest: Codable {
    public let query: String
    public let includeAdult: Bool
}

public struct EnrichRequest: Codable {
    public let path: String
    public let includeAdult: Bool
}

public struct FilesRequest: Codable {
    public let files: [String]
    public let includeAdult: Bool
}

public struct SearchResponse: Codable {
    public let results: [MetadataResult]
}

public struct EnrichResponse: Codable {
    public let details: MetadataDetails
}

public struct StatusEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let message: String
}

public actor StatusStream {
    private var events: [StatusEvent] = []
    private let capacity: Int
    private let logger = AppLog.general

    public init(capacity: Int = 100) {
        self.capacity = capacity
    }

    public func add(_ message: String) {
        let clean = scrubSecrets(message)
        let event = StatusEvent(id: UUID(), timestamp: Date(), message: clean)
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
        AppLog.info(AppLog.webui, "[Status] \(clean)")
    }

    public func recent(limit: Int = 50) -> [StatusEvent] {
        Array(events.suffix(limit))
    }
}

public final class WebServer {
    private let server = HttpServer()
    private let pipeline: MetadataPipeline
    private let registry: ProvidersRegistry
    private let status: StatusStream
    private let authToken: String?
    private let maxBodyBytes: Int
    private let rateLimiter: TokenBucket

    public init(
        pipeline: MetadataPipeline,
        registry: ProvidersRegistry,
        status: StatusStream,
        authToken: String? = nil,
        maxBodyBytes: Int = 512 * 1024,
        rateLimitPerSecond: Double = 5
    ) {
        self.pipeline = pipeline
        self.registry = registry
        self.status = status
        self.authToken = authToken
        self.maxBodyBytes = maxBodyBytes
        self.rateLimiter = TokenBucket(maxTokens: rateLimitPerSecond, refillRate: rateLimitPerSecond)
    }

    public func start(port: UInt16 = 8080) throws {
        server["/health"] = { _ in .ok(.text("ok")) }
        let statusHandler: (HttpRequest) -> HttpResponse = { [weak self] req in
            guard let self else { return .internalServerError }
            guard self.authorized(req) else { return self.errorResponse(401, "Unauthorized") }
            guard self.rateLimiter.allow() else { return self.errorResponse(429, "Rate limited") }
            let recent = self.blocking { await self.status.recent(limit: 50) }
            return self.jsonResponse(recent)
        }
        server["/api/status"] = self.preflightWrapper(statusHandler)

        let searchHandler: (HttpRequest) -> HttpResponse = { [weak self] req in
            guard let self else { return .internalServerError }
            guard self.authorized(req) else { return self.errorResponse(401, "Unauthorized") }
            guard self.rateLimiter.allow() else { return self.errorResponse(429, "Rate limited") }
            guard self.validateContentType(req) else { return self.errorResponse(415, "Unsupported Media Type") }
            guard self.validateBodySize(req) else { return self.errorResponse(413, "Payload too large") }
            let data = Data(req.body)
            guard let search = try? JSONDecoder().decode(SearchRequest.self, from: data) else { return .badRequest(nil) }
            return self.blockingResponse { try await self.handleSearch(search) }
        }
        server["/api/search"] = self.preflightWrapper(searchHandler)

        let enrichHandler: (HttpRequest) -> HttpResponse = { [weak self] req in
            guard let self else { return .internalServerError }
            guard self.authorized(req) else { return self.errorResponse(401, "Unauthorized") }
            guard self.rateLimiter.allow() else { return self.errorResponse(429, "Rate limited") }
            guard self.validateContentType(req) else { return self.errorResponse(415, "Unsupported Media Type") }
            guard self.validateBodySize(req) else { return self.errorResponse(413, "Payload too large") }
            let data = Data(req.body)
            guard let enrich = try? JSONDecoder().decode(EnrichRequest.self, from: data) else { return .badRequest(nil) }
            return self.blockingResponse { try await self.handleEnrich(enrich) }
        }
        server["/api/enrich"] = self.preflightWrapper(enrichHandler)

        let filesHandler: (HttpRequest) -> HttpResponse = { [weak self] req in
            guard let self else { return .internalServerError }
            guard self.authorized(req) else { return self.errorResponse(401, "Unauthorized") }
            guard self.rateLimiter.allow() else { return self.errorResponse(429, "Rate limited") }
            guard self.validateContentType(req) else { return self.errorResponse(415, "Unsupported Media Type") }
            guard self.validateBodySize(req) else { return self.errorResponse(413, "Payload too large") }
            let data = Data(req.body)
            guard let files = try? JSONDecoder().decode(FilesRequest.self, from: data) else { return .badRequest(nil) }
            return self.blockingResponse { try await self.handleFiles(files) }
        }
        server["/api/files"] = self.preflightWrapper(filesHandler)
        server["/assets/:file"] = { req in
            guard let name = req.params.first?.1, !name.contains("..") else { return .forbidden }
            let assetURL = URL(fileURLWithPath: "WebUI/Assets").appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: assetURL.path) else { return .notFound }
            guard let data = try? Data(contentsOf: assetURL) else { return .internalServerError }
            let mime = self.mimeType(for: assetURL)
            return .raw(200, "OK", [
                "Content-Type": mime,
                "Access-Control-Allow-Origin": "http://127.0.0.1:8080",
                "Access-Control-Allow-Methods": "GET",
                "X-Content-Type-Options": "nosniff"
            ]) { writer in
                try writer.write(data)
            }
        }

        try server.start(port, forceIPv4: true)
        Task { await status.add("WebUI started on http://127.0.0.1:\(port)") }
    }

    public func stop() {
        server.stop()
    }

    // MARK: - Handlers

    private func handleSearch(_ req: SearchRequest) async throws -> HttpResponse {
        await status.add("Search: \(req.query)")
        let providers = registry.all(includeAdult: req.includeAdult)
        let hint = MetadataHint(title: req.query)
        let tasks = providers.map { provider in
            Task { try? await provider.fetch(for: URL(fileURLWithPath: "/dev/null"), hint: hint) }
        }
        var results: [MetadataDetails] = []
        for task in tasks {
            if let value = await task.value {
                results.append(value)
            }
        }
        let mapped = results.map {
            MetadataResult(id: $0.id, title: $0.title, score: $0.rating, year: $0.releaseDate?.yearComponent)
        }
        return jsonResponse(SearchResponse(results: mapped))
    }

    private func handleEnrich(_ req: EnrichRequest) async throws -> HttpResponse {
        let fileURL = URL(fileURLWithPath: req.path)
        guard isSupportedMedia(fileURL) else { return errorResponse(415, "Unsupported Media Type") }
        await status.add("Enrich start: \(fileURL.lastPathComponent)")
        do {
            let details = try await pipeline.enrich(file: fileURL, includeAdult: req.includeAdult)
            if let details {
                await status.add("Enrich complete: \(details.title)")
                return jsonResponse(EnrichResponse(details: details))
            } else {
                await status.add("Enrich deferred: \(fileURL.lastPathComponent) awaiting user choice")
                return .accepted
            }
        } catch {
            await status.add("Enrich failed: \(fileURL.lastPathComponent) - \(error.localizedDescription)")
            return .internalServerError
        }
    }

    private func handleFiles(_ req: FilesRequest) async throws -> HttpResponse {
        // For drag/drop files, just echo names and kick off background searches by basename
        let safeFiles = req.files.compactMap { path -> URL? in
            let url = URL(fileURLWithPath: path)
            guard isSupportedMedia(url) else { return nil }
            return url
        }
        let titles = safeFiles.map { $0.deletingPathExtension().lastPathComponent }
        for title in titles {
            await status.add("Queued search for \(title)")
        }
        let mapped = titles.map { MetadataResult(id: UUID().uuidString, title: $0, score: nil, year: nil) }
        return jsonResponse(SearchResponse(results: mapped))
    }

    // MARK: - Helpers

    private func jsonResponse<T: Encodable>(_ value: T) -> HttpResponse {
        do {
            let data = try JSONEncoder().encode(value)
            return .raw(200, "OK", ["Content-Type": "application/json", "Access-Control-Allow-Origin": "http://127.0.0.1:8080"]) { writer in
                try writer.write(data)
            }
        } catch {
            return .internalServerError
        }
    }

    private func blocking<T>(_ body: @escaping () async -> T) -> T {
        let sema = DispatchSemaphore(value: 0)
        var result: T!
        Task {
            result = await body()
            sema.signal()
        }
        sema.wait()
        return result
    }

    private func blockingResponse(_ body: @escaping () async throws -> HttpResponse) -> HttpResponse {
        let sema = DispatchSemaphore(value: 0)
        var response: HttpResponse = .internalServerError
        Task {
            response = (try? await body()) ?? .internalServerError
            sema.signal()
        }
        sema.wait()
        return response
    }

    internal func corsPreflightResponse() -> HttpResponse {
        return .raw(200, "OK", [
            "Access-Control-Allow-Origin": "http://127.0.0.1:8080",
            "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Max-Age": "600"
        ]) { _ in }
    }

    private func preflightWrapper(_ handler: @escaping (HttpRequest) -> HttpResponse) -> (HttpRequest) -> HttpResponse {
        return { req in
            if req.method.uppercased() == "OPTIONS" {
                return self.corsPreflightResponse()
            }
            return handler(req)
        }
    }

    internal func authorized(_ req: HttpRequest) -> Bool {
        authorized(headers: req.headers)
    }

    internal func authorized(headers: [String: String]) -> Bool {
        guard let token = authToken, !token.isEmpty else { return true }
        return headers["x-auth-token"] == token
    }

    internal func validateContentType(_ req: HttpRequest) -> Bool {
        validateContentType(headers: req.headers)
    }

    internal func validateContentType(headers: [String: String]) -> Bool {
        guard let type = headers["content-type"]?.lowercased() else { return false }
        return type.contains("application/json")
    }

    internal func validateBodySize(_ req: HttpRequest) -> Bool {
        validateBodySize(length: req.body.count)
    }

    internal func validateBodySize(length: Int) -> Bool {
        return length <= maxBodyBytes
    }

    private func errorResponse(_ status: Int, _ message: String) -> HttpResponse {
        let headers = [
            "Content-Type": "text/plain",
            "Access-Control-Allow-Origin": "http://127.0.0.1:8080"
        ]
        return .raw(status, message, headers) { writer in
            try writer.write(Array(message.utf8))
        }
    }

    private func isSupportedMedia(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "m4v", "mov"].contains(ext)
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "js": return "application/javascript"
        case "css": return "text/css"
        case "html", "htm": return "text/html"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }
}

private final class TokenBucket {
    private let maxTokens: Double
    private let refillRate: Double
    private var tokens: Double
    private var lastRefill: Date
    private let lock = DispatchQueue(label: "com.sublerplus.tokenbucket")

    init(maxTokens: Double, refillRate: Double) {
        self.maxTokens = maxTokens
        self.refillRate = refillRate
        self.tokens = maxTokens
        self.lastRefill = Date()
    }

    func allow() -> Bool {
        var allowed = false
        lock.sync {
            let now = Date()
            let delta = now.timeIntervalSince(lastRefill)
            tokens = min(maxTokens, tokens + delta * refillRate)
            lastRefill = now
            if tokens >= 1 {
                tokens -= 1
                allowed = true
            }
        }
        return allowed
    }
}

private extension Date {
    var yearComponent: Int? {
        Calendar.current.dateComponents([.year], from: self).year
    }
}

