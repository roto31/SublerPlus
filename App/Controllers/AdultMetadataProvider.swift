import Foundation

public struct TPDBPerformer: Codable, Sendable {
    public let name: String
    public let image: URL?
}

public struct TPDBScene: Codable, Sendable {
    public let id: Int
    public let title: String
    public let date: String?
    public let description: String?
    public let studio: String?
    public let tags: [String]
    public let performers: [TPDBPerformer]
    public let poster: URL?
    public let background: URL?
    public let rating: Double?
}

public final class TPDBClient: @unchecked Sendable {
    private let session: URLSession
    private let apiKey: String
    private let circuitBreaker = CircuitBreaker()

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func searchScenes(query: String) async throws -> [TPDBScene] {
        let req = makeSearchRequest(query: query)
        let data = try await fetchWithRetry(request: req)
        struct SearchResult: Codable { let data: [TPDBScene] }
        return try JSONDecoder().decode(SearchResult.self, from: data).data
    }

    public func fetchScene(id: Int) async throws -> TPDBScene {
        let url = URL(string: "https://api.theporndb.net/scene/\(id)")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let data = try await fetchWithRetry(request: req)
        struct SceneResponse: Codable { let data: TPDBScene }
        return try JSONDecoder().decode(SceneResponse.self, from: data).data
    }

    private func makeSearchRequest(query: String) -> URLRequest {
        var req = URLRequest(url: URL(string: "https://api.theporndb.net/search/scene")!)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["query": query])
        return req
    }

    internal func fetchWithRetry(request: URLRequest, attempts: Int = 3) async throws -> Data {
        var lastError: Error?
        var delay: UInt64 = 200_000_000
        for _ in 0..<attempts {
            guard circuitBreaker.allow() else { throw NSError(domain: "TPDB", code: 429, userInfo: [NSLocalizedDescriptionKey: "Circuit open"]) }
            do {
                let (data, resp) = try await session.data(for: request)
                guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw NSError(domain: "TPDB", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "TPDB request failed (\((resp as? HTTPURLResponse)?.statusCode ?? -1))"])
                }
                circuitBreaker.recordSuccess()
                return data
            } catch {
                lastError = error
                circuitBreaker.recordFailure()
                try? await Task.sleep(nanoseconds: delay)
                delay *= 2
            }
        }
        throw lastError ?? URLError(.badServerResponse)
    }
}

public final class ThePornDBProvider: MetadataProvider, @unchecked Sendable {
    public let id = "tpdb"
    public let isAdult = true
    private let client: TPDBClient
    private let minimumConfidence: Double

    public init(client: TPDBClient, minimumConfidence: Double = 0.5) {
        self.client = client
        self.minimumConfidence = minimumConfidence
    }

    public func search(query: String) async throws -> [MetadataResult] {
        let scenes = try await client.searchScenes(query: query)
        return scenes.map { scene in
            MetadataResult(
                id: String(scene.id),
                title: scene.title,
                score: scene.rating,
                year: scene.date.flatMap { Int($0.prefix(4)) }
            )
        }
    }

    public func fetchDetails(for id: String) async throws -> MetadataDetails {
        guard let intId = Int(id) else {
            throw NSError(domain: "TPDB", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid identifier"])
        }
        let scene = try await client.fetchScene(id: intId)
        let releaseDate: Date?
        if let dateStr = scene.date {
            releaseDate = ISO8601DateFormatter().date(from: dateStr)
        } else {
            releaseDate = nil
        }
        return MetadataDetails(
            id: String(scene.id),
            title: scene.title,
            synopsis: scene.description,
            releaseDate: releaseDate,
            studio: scene.studio,
            tags: scene.tags,
            performers: scene.performers.map { $0.name },
            coverURL: scene.poster ?? scene.background,
            rating: scene.rating
        )
    }
}

public final class SearchProviderAdapter: PipelineMetadataProvider, @unchecked Sendable {
    public let id: String
    public let isAdult: Bool
    private let provider: MetadataProvider
    private let selector: @Sendable (_ results: [MetadataResult], _ hint: MetadataHint) -> MetadataResult?
    private let minimumConfidence: Double

    public init(
        provider: MetadataProvider,
        selector: @escaping @Sendable (_ results: [MetadataResult], _ hint: MetadataHint) -> MetadataResult?,
        minimumConfidence: Double = 0.0
    ) {
        self.id = provider.id
        self.isAdult = provider.isAdult
        self.provider = provider
        self.selector = selector
        self.minimumConfidence = minimumConfidence
    }

    public func fetch(for file: URL, hint: MetadataHint) async throws -> MetadataDetails {
        let results = try await provider.search(query: hint.title)
        guard let choice = selector(results, hint) else {
            throw NSError(domain: "Adapter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No suitable match"])
        }
        let details = try await provider.fetchDetails(for: choice.id)
        if let score = choice.score, score < minimumConfidence {
            throw NSError(domain: "Adapter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Low confidence match"])
        }
        return details
    }
}

