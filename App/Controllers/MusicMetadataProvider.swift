import Foundation

public enum MusicMetadataError: Error, Equatable {
    case invalidResponse
    case networkError(String)
    case noResults
    case invalidAlbumID
}

// MARK: - iTunes Music API Response Models

private struct iTunesMusicResult: Codable {
    let trackId: Int?
    let collectionId: Int?
    let trackName: String?
    let collectionName: String?
    let artistName: String?
    let artworkUrl60: String?
    let artworkUrl100: String?
    let previewUrl: String?
    let trackTimeMillis: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let primaryGenreName: String?
    let releaseDate: String?
}

private struct iTunesMusicSearchResponse: Codable {
    let results: [iTunesMusicResult]
}

public final class MusicMetadataProvider: MetadataProvider {
    public let id = "iTunesMusic"
    public let name = "iTunes Music"
    public let isAdult = false
    
    private let baseURL = "https://itunes.apple.com"
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - MetadataProvider Conformance
    
    public func search(query: String) async throws -> [MetadataResult] {
        let albums = try await searchAlbum(query: query)
        return albums.map { album in
            MetadataResult(
                id: String(album.albumID),
                title: album.title,
                score: nil,
                year: album.releaseDate.map { Calendar.current.component(.year, from: $0) },
                source: self.id,
                coverURL: album.artworkURLHighRes ?? album.artworkURL,
                language: nil,
                isSubtitle: false
            )
        }
    }
    
    public func fetchDetails(for id: String) async throws -> MetadataDetails {
        guard let albumID = Int(id) else {
            throw MusicMetadataError.invalidAlbumID
        }
        let album = try await getAlbumDetails(albumID: albumID)
        
        return MetadataDetails(
            id: id,
            title: album.title,
            synopsis: nil,
            releaseDate: album.releaseDate,
            studio: nil,
            tags: album.genre.map { [$0] } ?? [],
            performers: [album.artist],
            coverURL: album.artworkURLHighRes ?? album.artworkURL,
            rating: nil,
            source: self.id
        )
    }
    
    /// Search for albums using iTunes Search API
    public func searchAlbum(query: String, country: String = "us", limit: Int = 50) async throws -> [AlbumMetadata] {
        guard !query.isEmpty else { return [] }
        
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components.url else {
            throw MusicMetadataError.invalidResponse
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw MusicMetadataError.networkError("HTTP \(response)")
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(iTunesMusicSearchResponse.self, from: data)
            
            return searchResponse.results.compactMap { result in
                guard let collectionId = result.collectionId,
                      let collectionName = result.collectionName,
                      let artistName = result.artistName else {
                    return nil
                }
                
                let artworkURL = result.artworkUrl100.flatMap { URL(string: $0) }
                let highResURL: URL? = {
                    if let url100 = result.artworkUrl100 {
                        let highResString = url100.replacingOccurrences(of: "100x100", with: "1000x1000")
                        return URL(string: highResString)
                    }
                    return nil
                }()
                
                let releaseDate: Date? = {
                    if let dateString = result.releaseDate {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        return formatter.date(from: dateString) ?? formatter.date(from: dateString.replacingOccurrences(of: "Z", with: "+00:00"))
                    }
                    return nil
                }()
                
                return AlbumMetadata(
                    id: collectionId,
                    albumID: collectionId,
                    title: collectionName,
                    artist: artistName,
                    releaseDate: releaseDate,
                    genre: result.primaryGenreName,
                    artworkURL: artworkURL,
                    artworkURLHighRes: highResURL,
                    tracks: [], // Will be populated by getAlbumDetails
                    country: country
                )
            }
        } catch let error as MusicMetadataError {
            throw error
        } catch {
            throw MusicMetadataError.networkError(error.localizedDescription)
        }
    }
    
    /// Get full album details including track listings
    public func getAlbumDetails(albumID: Int, country: String = "us") async throws -> AlbumMetadata {
        var components = URLComponents(string: "\(baseURL)/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(albumID)),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "country", value: country)
        ]
        
        guard let url = components.url else {
            throw MusicMetadataError.invalidResponse
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw MusicMetadataError.networkError("HTTP \(response)")
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(iTunesMusicSearchResponse.self, from: data)
            
            guard let albumResult = searchResponse.results.first(where: { $0.collectionId == albumID }),
                  let collectionName = albumResult.collectionName,
                  let artistName = albumResult.artistName else {
                throw MusicMetadataError.invalidAlbumID
            }
            
            // Get all tracks for this album
            let tracks = searchResponse.results
                .filter { $0.collectionId == albumID && $0.trackId != nil }
                .sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }
                .compactMap { result -> TrackMetadata? in
                    guard let trackId = result.trackId,
                          let trackName = result.trackName else {
                        return nil
                    }
                    
                    let releaseDate: Date? = {
                        if let dateString = result.releaseDate {
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            return formatter.date(from: dateString) ?? formatter.date(from: dateString.replacingOccurrences(of: "Z", with: "+00:00"))
                        }
                        return nil
                    }()
                    
                    return TrackMetadata(
                        id: trackId,
                        trackID: trackId,
                        title: trackName,
                        artist: result.artistName ?? artistName,
                        duration: TimeInterval(result.trackTimeMillis ?? 0) / 1000.0,
                        trackNumber: result.trackNumber,
                        discNumber: result.discNumber,
                        genre: result.primaryGenreName ?? albumResult.primaryGenreName,
                        releaseDate: releaseDate,
                        albumName: collectionName
                    )
                }
            
            let artworkURL = albumResult.artworkUrl100.flatMap { URL(string: $0) }
            let highResURL: URL? = {
                if let url100 = albumResult.artworkUrl100 {
                    let highResString = url100.replacingOccurrences(of: "100x100", with: "1000x1000")
                    return URL(string: highResString)
                }
                return nil
            }()
            
            let releaseDate: Date? = {
                if let dateString = albumResult.releaseDate {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter.date(from: dateString) ?? formatter.date(from: dateString.replacingOccurrences(of: "Z", with: "+00:00"))
                }
                return nil
            }()
            
            return AlbumMetadata(
                id: albumID,
                albumID: albumID,
                title: collectionName,
                artist: artistName,
                releaseDate: releaseDate,
                genre: albumResult.primaryGenreName,
                artworkURL: artworkURL,
                artworkURLHighRes: highResURL,
                tracks: tracks,
                country: country
            )
        } catch let error as MusicMetadataError {
            throw error
        } catch {
            throw MusicMetadataError.networkError(error.localizedDescription)
        }
    }
    
    /// Get track details
    public func getTrackDetails(trackID: Int, country: String = "us") async throws -> TrackMetadata {
        var components = URLComponents(string: "\(baseURL)/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(trackID)),
            URLQueryItem(name: "country", value: country)
        ]
        
        guard let url = components.url else {
            throw MusicMetadataError.invalidResponse
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw MusicMetadataError.networkError("HTTP \(response)")
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(iTunesMusicSearchResponse.self, from: data)
            
            guard let result = searchResponse.results.first,
                  let trackId = result.trackId ?? result.collectionId,
                  let trackName = result.trackName ?? result.collectionName,
                  let artistName = result.artistName else {
                throw MusicMetadataError.noResults
            }
            
            let releaseDate: Date? = {
                if let dateString = result.releaseDate {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter.date(from: dateString) ?? formatter.date(from: dateString.replacingOccurrences(of: "Z", with: "+00:00"))
                }
                return nil
            }()
            
            return TrackMetadata(
                id: trackId,
                trackID: trackId,
                title: trackName,
                artist: artistName,
                duration: TimeInterval(result.trackTimeMillis ?? 0) / 1000.0,
                trackNumber: result.trackNumber,
                discNumber: result.discNumber,
                genre: result.primaryGenreName,
                releaseDate: releaseDate,
                albumName: result.collectionName
            )
        } catch let error as MusicMetadataError {
            throw error
        } catch {
            throw MusicMetadataError.networkError(error.localizedDescription)
        }
    }
}

