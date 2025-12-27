import Foundation

public struct SubtitleCandidate: Identifiable, Sendable, Codable, Hashable {
    public let id: String
    public let title: String
    public let language: String
    public let score: Double?
    public let downloadURL: URL
    public let releaseYear: Int?
    public init(id: String, title: String, language: String, score: Double? = nil, downloadURL: URL, releaseYear: Int? = nil) {
        self.id = id
        self.title = title
        self.language = language
        self.score = score
        self.downloadURL = downloadURL
        self.releaseYear = releaseYear
    }
}

public final class OpenSubtitlesProvider: @unchecked Sendable {
    private let apiKey: String
    private let host = "opensubtitle.p.rapidapi.com"
    private let base = URL(string: "https://opensubtitle.p.rapidapi.com")!
    private let session: URLSession
    private let maxBytes: Int

    public init?(apiKey: String?, session: URLSession = .shared, maxBytes: Int = 5 * 1024 * 1024) {
        guard let key = apiKey, !key.isEmpty else { return nil }
        self.apiKey = key
        self.session = session
        self.maxBytes = maxBytes
    }

    public func search(title: String, year: Int?, language: String) async throws -> [SubtitleCandidate] {
        // OpenSubtitles RapidAPI has limited docs; use a simple endpoint if available.
        // Here we approximate using a fictional /search endpoint; adjust as per actual API.
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        var components = URLComponents(url: base.appendingPathComponent("subtitles"), resolvingAgainstBaseURL: false)!
        var query: [URLQueryItem] = [
            URLQueryItem(name: "query", value: encodedTitle),
            URLQueryItem(name: "languages", value: language)
        ]
        if let year { query.append(URLQueryItem(name: "year", value: "\(year)")) }
        components.queryItems = query
        guard let url = components.url else { return [] }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.addValue(host, forHTTPHeaderField: "x-rapidapi-host")
        req.addValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "OpenSubtitles", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Search failed"])
        }
        struct APIResponse: Decodable {
            struct Item: Decodable {
                let id: String
                let attributes: Attributes
            }
            struct Attributes: Decodable {
                let language: String?
                let title: String?
                let download_url: String?
                let hearing_impaired: Bool?
                let fps: Double?
                let release: String?
                let year: Int?
                let rating: Double?
            }
            let data: [Item]
        }
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        return decoded.data.compactMap { item in
            guard let lang = item.attributes.language,
                  let title = item.attributes.title,
                  let urlString = item.attributes.download_url,
                  let url = URL(string: urlString)
            else { return nil }
            return SubtitleCandidate(
                id: item.id,
                title: title,
                language: lang,
                score: item.attributes.rating,
                downloadURL: url,
                releaseYear: item.attributes.year
            )
        }
    }

    public func downloadSubtitle(from url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "OpenSubtitles", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Download failed"])
        }
        guard data.count <= maxBytes else {
            throw NSError(domain: "OpenSubtitles", code: -2, userInfo: [NSLocalizedDescriptionKey: "Subtitle too large"])
        }
        return data
    }
}

