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
    private let base = URL(string: "https://api.opensubtitles.com/api/v1")!
    private let session: URLSession
    private let maxBytes: Int
    private var authToken: String?

    public init?(apiKey: String?, session: URLSession = .shared, maxBytes: Int = 5 * 1024 * 1024) {
        guard let key = apiKey, !key.isEmpty else { return nil }
        self.apiKey = key
        self.session = session
        self.maxBytes = maxBytes
    }

    // Authenticate with OpenSubtitles API
    private func authenticate() async throws -> String {
        if let token = authToken {
            return token
        }
        
        let loginURL = base.appendingPathComponent("login")
        var req = URLRequest(url: loginURL)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("SublerPlus/1.0", forHTTPHeaderField: "User-Agent")
        
        let loginBody: [String: Any] = [
            "username": "",
            "password": ""
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: loginBody)
        
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "OpenSubtitles", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
        }
        
        struct LoginResponse: Decodable {
            let token: String?
            let status: Int?
        }
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        guard let token = loginResponse.token else {
            throw NSError(domain: "OpenSubtitles", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token in authentication response"])
        }
        
        authToken = token
        return token
    }

    public func search(title: String, year: Int?, language: String) async throws -> [SubtitleCandidate] {
        // Authenticate first
        let token = try await authenticate()
        
        // Build search request
        let searchURL = base.appendingPathComponent("subtitles")
        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)!
        var query: [URLQueryItem] = [
            URLQueryItem(name: "query", value: title),
            URLQueryItem(name: "languages", value: language)
        ]
        if let year {
            query.append(URLQueryItem(name: "year", value: "\(year)"))
        }
        components.queryItems = query
        guard let url = components.url else { return [] }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        req.addValue("SublerPlus/1.0", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "OpenSubtitles", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Search failed"])
        }
        
        // Parse official API response structure
        struct APIResponse: Decodable {
            struct Subtitle: Decodable {
                let id: String
                let attributes: Attributes
            }
            struct Attributes: Decodable {
                let language: String?
                let release: String?
                let feature_details: FeatureDetails?
                let files: [File]?
                let download_count: Int?
                let ratings: Double?
            }
            struct FeatureDetails: Decodable {
                let feature_id: Int?
                let feature_type: String?
                let year: Int?
                let title: String?
                let movie_name: String?
                let imdb_id: Int?
                let tmdb_id: Int?
            }
            struct File: Decodable {
                let file_id: Int
                let file_name: String?
            }
            let data: [Subtitle]
        }
        
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        return decoded.data.compactMap { subtitle in
            guard let lang = subtitle.attributes.language,
                  let fileId = subtitle.attributes.files?.first?.file_id,
                  let title = subtitle.attributes.feature_details?.title ?? subtitle.attributes.feature_details?.movie_name
            else { return nil }
            
            // Build download URL using file_id
            let downloadURL = base.appendingPathComponent("download").appendingPathComponent("\(fileId)")
            
            return SubtitleCandidate(
                id: subtitle.id,
                title: title,
                language: lang,
                score: subtitle.attributes.ratings,
                downloadURL: downloadURL,
                releaseYear: subtitle.attributes.feature_details?.year
            )
        }
    }

    public func downloadSubtitle(from url: URL) async throws -> Data {
        // Authenticate first
        let token = try await authenticate()
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        req.addValue("SublerPlus/1.0", forHTTPHeaderField: "User-Agent")
        
        // OpenSubtitles API requires POST with file_id in body
        if let fileId = Int(url.lastPathComponent) {
            let body: [String: Any] = [
                "file_id": fileId
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "OpenSubtitles", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Download failed"])
        }
        
        // Parse download response
        struct DownloadResponse: Decodable {
            let link: String?
            let file_name: String?
        }
        
        let downloadResponse = try JSONDecoder().decode(DownloadResponse.self, from: data)
        
        guard let downloadLink = downloadResponse.link,
              let downloadURL = URL(string: downloadLink) else {
            throw NSError(domain: "OpenSubtitles", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid download link"])
        }
        
        // Download actual subtitle file
        var downloadReq = URLRequest(url: downloadURL)
        downloadReq.httpMethod = "GET"
        let (subtitleData, subtitleResp) = try await session.data(for: downloadReq)
        guard let subtitleHttp = subtitleResp as? HTTPURLResponse, 200..<300 ~= subtitleHttp.statusCode else {
            throw NSError(domain: "OpenSubtitles", code: (subtitleResp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Subtitle file download failed"])
        }
        
        guard subtitleData.count <= maxBytes else {
            throw NSError(domain: "OpenSubtitles", code: -3, userInfo: [NSLocalizedDescriptionKey: "Subtitle too large"])
        }
        
        return subtitleData
    }
}

