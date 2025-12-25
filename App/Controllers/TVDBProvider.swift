import Foundation

public final class TVDBProvider: MetadataProvider, @unchecked Sendable {
    public let id = "tvdb"
    public let isAdult = false

    private let apiKey: String
    private let session: URLSession
    private let circuitBreaker = CircuitBreaker()

    public init?(apiKey: String?, session: URLSession = .shared) {
        guard let key = apiKey, !key.isEmpty else { return nil }
        self.apiKey = key
        self.session = session
    }

    public func search(query: String) async throws -> [MetadataResult] {
        // TVDB v4 search
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let data = try await fetchWithRetry(path: "search?query=\(encoded)")
        let decoded = try JSONDecoder().decode(TVDBSearchResponse.self, from: data)
        return decoded.data.map {
            MetadataResult(
                id: String($0.tvdb_id),
                title: $0.name,
                score: $0.score,
                year: year(from: $0.first_air_time)
            )
        }
    }

    public func fetchDetails(for id: String) async throws -> MetadataDetails {
        guard let intId = Int(id) else {
            throw NSError(domain: "TVDB", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid TVDB id"])
        }
        let data = try await fetchWithRetry(path: "series/\(intId)")
        let decoded = try JSONDecoder().decode(TVDBSeriesResponse.self, from: data)
        let series = decoded.data
        let releaseDate = series.firstAired.flatMap { isoDate($0) }
        let cover = series.imageURL.flatMap { URL(string: $0) }
        return MetadataDetails(
            id: id,
            title: series.name,
            synopsis: series.overview,
            releaseDate: releaseDate,
            studio: series.network,
            tags: series.genres ?? [],
            performers: series.actors ?? [],
            coverURL: cover,
            rating: series.score
        )
    }

    private func year(from string: String?) -> Int? {
        guard let string, string.count >= 4 else { return nil }
        return Int(string.prefix(4))
    }

    private func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)
    }

    internal func fetchWithRetry(path: String, attempts: Int = 3) async throws -> Data {
        var lastError: Error?
        var delay: UInt64 = 200_000_000
        let url = URL(string: "https://api4.thetvdb.com/v4/\(path)")!
        for _ in 0..<attempts {
            guard circuitBreaker.allow() else { throw NSError(domain: "TVDB", code: 429, userInfo: [NSLocalizedDescriptionKey: "Circuit open"]) }
            do {
                var req = URLRequest(url: url)
                req.httpMethod = "GET"
                req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw NSError(domain: "TVDB", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "TVDB request failed (\((resp as? HTTPURLResponse)?.statusCode ?? -1))"])
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

private struct TVDBSearchResponse: Codable {
    struct Show: Codable {
        let name: String
        let tvdb_id: Int
        let score: Double?
        let first_air_time: String?
    }
    let data: [Show]
}

private struct TVDBSeriesResponse: Codable {
    struct Series: Codable {
        let name: String
        let overview: String?
        let firstAired: String?
        let network: String?
        let genres: [String]?
        let actors: [String]?
        let score: Double?
        let imageURL: String?
    }
    let data: Series
}

