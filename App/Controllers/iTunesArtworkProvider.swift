import Foundation

public enum iTunesArtworkError: Error, Equatable {
    case invalidResponse
    case networkError(String)
    case noResults
}

public final class iTunesArtworkProvider: @unchecked Sendable {
    
    public enum MediaType: String, CaseIterable, Sendable {
        case tvShow = "tvShow"
        case movie = "movie"
        case album = "music"
        case app = "software"
        case iBook = "ebook"
        case audiobook = "audiobook"
        case podcast = "podcast"
        case musicVideo = "musicVideo"
        
        public var displayName: String {
            switch self {
            case .tvShow: return "TV Show"
            case .movie: return "Movie"
            case .album: return "Album"
            case .app: return "App"
            case .iBook: return "iBook"
            case .audiobook: return "Audiobook"
            case .podcast: return "Podcast"
            case .musicVideo: return "Music Video"
            }
        }
        
        public var iTunesEntity: String {
            switch self {
            case .tvShow: return "tvEpisode"
            case .movie: return "movie"
            case .album: return "album"
            case .app: return "software"
            case .iBook: return "ebook"
            case .audiobook: return "audiobook"
            case .podcast: return "podcast"
            case .musicVideo: return "musicVideo"
            }
        }
    }
    
    public struct ArtworkResult: Identifiable, Sendable {
        public let id: Int
        public let title: String
        public let artist: String?
        public let artworkURL: URL
        public let artworkURLHighRes: URL?
        public let mediaType: MediaType
        public let country: String
        public let previewURL: URL?
        
        public init(id: Int, title: String, artist: String?, artworkURL: URL, artworkURLHighRes: URL?, mediaType: MediaType, country: String, previewURL: URL?) {
            self.id = id
            self.title = title
            self.artist = artist
            self.artworkURL = artworkURL
            self.artworkURLHighRes = artworkURLHighRes
            self.mediaType = mediaType
            self.country = country
            self.previewURL = previewURL
        }
    }
    
    private let baseURL = "https://itunes.apple.com"
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Search for artwork using iTunes Search API
    public func search(query: String, mediaType: MediaType, country: String = "us", limit: Int = 50) async throws -> [ArtworkResult] {
        guard !query.isEmpty else { return [] }
        
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: mediaType.rawValue),
            URLQueryItem(name: "entity", value: mediaType.iTunesEntity),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components.url else {
            throw iTunesArtworkError.invalidResponse
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw iTunesArtworkError.networkError("HTTP \(response)")
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(iTunesSearchResponse.self, from: data)
            
            return searchResponse.results.compactMap { result in
                guard let artworkURLString = result.artworkUrl100 ?? result.artworkUrl60,
                      let artworkURL = URL(string: artworkURLString) else {
                    return nil
                }
                
                // Generate high-res URL (replace size parameter)
                let highResURL: URL? = {
                    if let url100 = result.artworkUrl100 {
                        // Try to get higher resolution (1000x1000 for movies, 800x800 for TV shows)
                        let size = mediaType == .tvShow ? "800x800" : "1000x1000"
                        let highResString = url100.replacingOccurrences(of: "100x100", with: size)
                        return URL(string: highResString)
                    }
                    return nil
                }()
                
                return ArtworkResult(
                    id: result.trackId ?? result.collectionId ?? 0,
                    title: result.trackName ?? result.collectionName ?? result.artistName ?? "Unknown",
                    artist: result.artistName,
                    artworkURL: artworkURL,
                    artworkURLHighRes: highResURL,
                    mediaType: mediaType,
                    country: country,
                    previewURL: result.previewUrl.flatMap { URL(string: $0) }
                )
            }
        } catch let error as iTunesArtworkError {
            throw error
        } catch {
            throw iTunesArtworkError.networkError(error.localizedDescription)
        }
    }
    
    /// Search by Apple ID for direct lookup
    public func searchByAppleID(_ id: Int, mediaType: MediaType, country: String = "us") async throws -> ArtworkResult? {
        var components = URLComponents(string: "\(baseURL)/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(id)),
            URLQueryItem(name: "country", value: country)
        ]
        
        guard let url = components.url else {
            throw iTunesArtworkError.invalidResponse
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw iTunesArtworkError.networkError("HTTP \(response)")
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(iTunesSearchResponse.self, from: data)
            
            guard let result = searchResponse.results.first,
                  let artworkURLString = result.artworkUrl100 ?? result.artworkUrl60,
                  let artworkURL = URL(string: artworkURLString) else {
                return nil
            }
            
            let highResURL: URL? = {
                if let url100 = result.artworkUrl100 {
                    let size = mediaType == .tvShow ? "800x800" : "1000x1000"
                    let highResString = url100.replacingOccurrences(of: "100x100", with: size)
                    return URL(string: highResString)
                }
                return nil
            }()
            
            return ArtworkResult(
                id: result.trackId ?? result.collectionId ?? id,
                title: result.trackName ?? result.collectionName ?? result.artistName ?? "Unknown",
                artist: result.artistName,
                artworkURL: artworkURL,
                artworkURLHighRes: highResURL,
                mediaType: mediaType,
                country: country,
                previewURL: result.previewUrl.flatMap { URL(string: $0) }
            )
        } catch let error as iTunesArtworkError {
            throw error
        } catch {
            throw iTunesArtworkError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - iTunes API Response Models

private struct iTunesSearchResponse: Codable {
    let results: [iTunesResult]
}

private struct iTunesResult: Codable {
    let trackId: Int?
    let collectionId: Int?
    let trackName: String?
    let collectionName: String?
    let artistName: String?
    let artworkUrl60: String?
    let artworkUrl100: String?
    let previewUrl: String?
}

