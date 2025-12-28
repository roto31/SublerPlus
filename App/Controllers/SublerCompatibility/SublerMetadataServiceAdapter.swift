#if canImport(MP42Foundation)
import Foundation
import MP42Foundation

/// Adapter that wraps modern MetadataProvider (async/await) to conform to Subler's MetadataService (synchronous)
/// This allows modern providers to work with Subler's search architecture
public final class SublerMetadataServiceAdapter: MetadataService {
    
    private let provider: MetadataProvider
    private let languageType: LanguageType
    private let languages: [String]
    private let defaultLanguage: String
    
    public init(provider: MetadataProvider, languageType: LanguageType = .ISO, languages: [String] = [], defaultLanguage: String = "en") {
        self.provider = provider
        self.languageType = languageType
        self.languages = languages.isEmpty ? ["en"] : languages
        self.defaultLanguage = defaultLanguage
    }
    
    // MARK: - MetadataService Protocol
    
    var name: String {
        return provider.id
    }
    
    // MARK: - Movie Search
    
    func search(movie: String, language: String) -> [MetadataResult] {
        // Convert async to sync using semaphore (matching Subler's pattern)
        let semaphore = DispatchSemaphore(value: 0)
        var results: [MetadataResult] = []
        
        Task {
            do {
                let modernResults = try await provider.search(query: movie)
                // Convert modern MetadataResult struct to Subler's MetadataResult class
                results = modernResults.map { convertToSublerResult($0, mediaKind: .movie) }
            } catch {
                // On error, return empty array (matching Subler's behavior)
                results = []
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return results
    }
    
    func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        let semaphore = DispatchSemaphore(value: 0)
        var result: MetadataResult?
        
        Task {
            do {
                // Extract ID from Subler's MetadataResult
                let id = metadata[.serviceContentID] as? String ?? metadata[.name] as? String ?? ""
                let details = try await provider.fetchDetails(for: id)
                result = convertDetailsToSublerResult(details, mediaKind: .movie)
            } catch {
                // On error, return original metadata
                result = metadata
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result ?? metadata
    }
    
    // MARK: - TV Show Search
    
    func search(tvShow: String, language: String) -> [String] {
        // For TV name search, return the query itself (providers don't have name search)
        // This matches Subler's behavior where some providers return empty arrays
        return [tvShow]
    }
    
    func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        let semaphore = DispatchSemaphore(value: 0)
        var results: [MetadataResult] = []
        
        Task {
            do {
                let modernResults = try await provider.search(query: tvShow)
                // Convert to Subler results and filter by season/episode if provided
                let converted = modernResults.map { convertToSublerResult($0, mediaKind: .tvShow, season: season, episode: episode) }
                results = converted
            } catch {
                results = []
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return results
    }
    
    func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        let semaphore = DispatchSemaphore(value: 0)
        var result: MetadataResult?
        
        Task {
            do {
                let id = metadata[.serviceContentID] as? String ?? metadata[.serviceEpisodeID] as? String ?? ""
                let details = try await provider.fetchDetails(for: id)
                result = convertDetailsToSublerResult(details, mediaKind: .tvShow)
            } catch {
                result = metadata
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result ?? metadata
    }
    
    // MARK: - Conversion Helpers
    
    private func convertToSublerResult(_ modern: App.Models.MetadataResult, mediaKind: MediaKind, season: Int? = nil, episode: Int? = nil) -> MetadataResult {
        let result = MetadataResult()
        result.mediaKind = mediaKind
        
        // Map fields
        result[.serviceContentID] = modern.id
        result[.name] = modern.title
        
        if let year = modern.year {
            // Create a date from year
            var components = DateComponents()
            components.year = year
            components.month = 1
            components.day = 1
            result[.releaseDate] = Calendar.current.date(from: components)
        }
        
        if let score = modern.score {
            result[.rating] = score
        }
        
        // TV show specific
        if mediaKind == .tvShow {
            if let season = season {
                result[.season] = season
            }
            if let episode = episode {
                result[.episodeNumber] = episode
                result[.trackNumber] = episode
            }
        }
        
        return result
    }
    
    private func convertDetailsToSublerResult(_ details: MetadataDetails, mediaKind: MediaKind) -> MetadataResult {
        let result = MetadataResult()
        result.mediaKind = mediaKind
        
        // Map all fields from MetadataDetails to Subler's MetadataResult
        result[.serviceContentID] = details.id
        result[.name] = details.title
        
        if let releaseDate = details.releaseDate {
            result[.releaseDate] = releaseDate
        }
        
        if let synopsis = details.synopsis {
            result[.longDescription] = synopsis
            result[.description] = synopsis
        }
        
        if let studio = details.studio {
            result[.studio] = studio
        }
        
        if !details.tags.isEmpty {
            result[.genre] = details.tags.joined(separator: ", ")
        }
        
        if !details.performers.isEmpty {
            result[.cast] = details.performers.joined(separator: ", ")
        }
        
        if let rating = details.rating {
            result[.rating] = rating
        }
        
        // TV show specific
        if mediaKind == .tvShow {
            if let show = details.show {
                result[.seriesName] = show
            }
            if let season = details.seasonNumber {
                result[.season] = season
            }
            if let episode = details.episodeNumber {
                result[.episodeNumber] = episode
                result[.trackNumber] = episode
                result[.episodeID] = details.episodeID
            }
        }
        
        // Handle artwork if available
        if let coverURL = details.coverURL {
            let artwork = Artwork(
                url: coverURL,
                thumbURL: coverURL,
                service: details.source ?? provider.id,
                type: mediaKind == .movie ? .poster : .episode,
                size: .standard
            )
            result.remoteArtworks = [artwork]
        }
        
        return result
    }
}


#endif
