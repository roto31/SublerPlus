import Foundation

// TMDB-backed standard metadata provider (movies). Requires TMDB_API_KEY env.
public final class StandardMetadataProvider: MetadataProvider, @unchecked Sendable {
    public let id = "tmdb"
    public let isAdult = false
    private let apiKey: String
    private let session: URLSession
    private let circuitBreaker = CircuitBreaker()
    private var imageBaseURL: URL = URL(string: "https://image.tmdb.org/t/p/")!
    private var posterSizes: [String] = ["w500"]
    private var configLoaded = false

    public init?(apiKey: String?, session: URLSession = .shared) {
        guard let key = apiKey, !key.isEmpty else { return nil }
        self.apiKey = key
        self.session = session
    }

    public func search(query: String) async throws -> [MetadataResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        try await loadConfigurationIfNeeded()
        let url = URL(string: "https://api.themoviedb.org/3/search/movie?api_key=\(apiKey)&include_adult=false&query=\(encoded)")!
        let data = try await fetchWithRetry(url: url)
        let decoded = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        return decoded.results.map { movie in
            MetadataResult(
                id: String(movie.id),
                title: movie.title,
                score: movie.vote_average,
                year: year(from: movie.release_date)
            )
        }
    }

    public func fetchDetails(for id: String) async throws -> MetadataDetails {
        guard let intId = Int(id) else {
            throw NSError(domain: "TMDB", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid TMDB id"])
        }
        try await loadConfigurationIfNeeded()
        let url = URL(string: "https://api.themoviedb.org/3/movie/\(intId)?api_key=\(apiKey)")!
        let data = try await fetchWithRetry(url: url)
        let movie = try JSONDecoder().decode(MovieDetails.self, from: data)
        let cast = try await fetchCast(for: intId)
        let releaseDate = movie.release_date.flatMap { isoDate($0) }
        let tags = movie.genres.map { $0.name }
        let cover = movie.poster_path.flatMap { posterURL(path: $0) }
        return MetadataDetails(
            id: String(movie.id),
            title: movie.title,
            synopsis: movie.overview,
            releaseDate: releaseDate,
            studio: movie.production_companies.first?.name,
            tags: tags,
            performers: cast,
            coverURL: cover,
            rating: movie.vote_average
        )
    }

    internal func fetchCast(for id: Int) async throws -> [String] {
        let url = URL(string: "https://api.themoviedb.org/3/movie/\(id)/credits?api_key=\(apiKey)")!
        let data = try await fetchWithRetry(url: url)
        let decoded = try JSONDecoder().decode(TMDBCrewResponse.self, from: data)
        return decoded.cast.prefix(10).map { $0.name }
    }

    private func loadConfigurationIfNeeded() async throws {
        guard !configLoaded else { return }
        let url = URL(string: "https://api.themoviedb.org/3/configuration?api_key=\(apiKey)")!
        let data = try await fetchWithRetry(url: url)
        let decoded = try JSONDecoder().decode(TMDBConfigurationResponse.self, from: data)
        if let secure = decoded.images.secure_base_url, let u = URL(string: secure) {
            imageBaseURL = u
        } else if let base = decoded.images.base_url, let u = URL(string: base) {
            imageBaseURL = u
        }
        if !decoded.images.poster_sizes.isEmpty {
            posterSizes = decoded.images.poster_sizes
        }
        configLoaded = true
    }

    private func posterURL(path: String) -> URL? {
        let size = posterSizes.contains("w500") ? "w500" : posterSizes.last ?? "original"
        return imageBaseURL.appendingPathComponent(size).appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    internal func fetchWithRetry(url: URL, attempts: Int = 3) async throws -> Data {
        var lastError: Error?
        var delay: UInt64 = 200_000_000 // 0.2s
        for _ in 0..<attempts {
            guard circuitBreaker.allow() else { throw NSError(domain: "TMDB", code: 429, userInfo: [NSLocalizedDescriptionKey: "Circuit open"]) }
            do {
                let (data, resp) = try await session.data(from: url)
                guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw NSError(domain: "TMDB", code: httpStatus(resp), userInfo: [NSLocalizedDescriptionKey: "TMDB request failed (\((resp as? HTTPURLResponse)?.statusCode ?? -1))"])
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

    private func isoDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: string)
    }

    private func year(from string: String?) -> Int? {
        guard let string, string.count >= 4 else { return nil }
        return Int(string.prefix(4))
    }

    private func httpStatus(_ resp: URLResponse) -> Int {
        (resp as? HTTPURLResponse)?.statusCode ?? -1
    }
}

private struct TMDBSearchResponse: Codable {
    let results: [TMDBMovieSummary]
}

private struct TMDBMovieSummary: Codable {
    let id: Int
    let title: String
    let release_date: String?
    let vote_average: Double?
}

private struct MovieDetails: Codable {
    let id: Int
    let title: String
    let overview: String?
    let release_date: String?
    let genres: [Genre]
    let production_companies: [Company]
    let vote_average: Double?
    let poster_path: String?
}

private struct Genre: Codable { let id: Int; let name: String }
private struct Company: Codable { let id: Int; let name: String }
private struct TMDBCrewResponse: Codable { let cast: [TMDBCast] }
private struct TMDBCast: Codable { let name: String }
private struct TMDBConfigurationResponse: Codable {
    struct Images: Codable {
        let base_url: String?
        let secure_base_url: String?
        let poster_sizes: [String]
    }
    let images: Images
}

