import Foundation
import MP42Foundation

/// Unified search manager that bridges legacy MetadataService (Subler) with modern MetadataProvider (SublerPlus)
/// This allows both systems to work together seamlessly
@MainActor
public final class UnifiedSearchManager {
    
    // MARK: - Types
    
    public enum SearchType {
        case movie
        case tvShow(season: Int?, episode: Int?)
    }
    
    public struct SearchOptions {
        public let query: String
        public let type: SearchType
        public let language: String?
        public let providerName: String?
        public let yearHint: Int?
        
        public init(query: String, type: SearchType, language: String? = nil, providerName: String? = nil, yearHint: Int? = nil) {
            self.query = query
            self.type = type
            self.language = language
            self.providerName = providerName
            self.yearHint = yearHint
        }
    }
    
    // MARK: - Properties
    
    private let modernProviders: [MetadataProvider]
    private let legacyServices: [String: MetadataService]
    private let includeAdult: Bool
    
    // MARK: - Initialization
    
    public init(modernProviders: [MetadataProvider], includeAdult: Bool = false) {
        self.modernProviders = modernProviders
        self.includeAdult = includeAdult
        
        // Initialize legacy services
        var services: [String: MetadataService] = [:]
        for name in MetadataSearch.movieProviders {
            services[name] = MetadataSearch.service(name: name)
        }
        for name in MetadataSearch.tvProviders {
            if services[name] == nil {
                services[name] = MetadataSearch.service(name: name)
            }
        }
        self.legacyServices = services
    }
    
    // MARK: - Unified Search
    
    /// Performs a unified search across both modern and legacy providers
    public func search(options: SearchOptions) async throws -> [MetadataResult] {
        var allResults: [MetadataResult] = []
        
        // Search modern providers
        let modernResults = await searchModernProviders(options: options)
        allResults.append(contentsOf: modernResults)
        
        // Search legacy providers
        let legacyResults = await searchLegacyProviders(options: options)
        allResults.append(contentsOf: legacyResults)
        
        // Sort and deduplicate results
        return sortAndDeduplicate(results: allResults, yearHint: options.yearHint)
    }
    
    // MARK: - Modern Provider Search
    
    private func searchModernProviders(options: SearchOptions) async -> [MetadataResult] {
        let filteredProviders = modernProviders.filter { includeAdult || !$0.isAdult }
        
        let tasks = filteredProviders.map { provider in
            Task { () -> [MetadataResult] in
                do {
                    return try await provider.search(query: options.query)
                } catch {
                    return []
                }
            }
        }
        
        var results: [MetadataResult] = []
        for task in tasks {
            let providerResults = await task.value
            results.append(contentsOf: providerResults)
        }
        
        return results
    }
    
    // MARK: - Legacy Provider Search
    
    private func searchLegacyProviders(options: SearchOptions) async -> [MetadataResult] {
        // Determine which service to use
        let service: MetadataService
        if let providerName = options.providerName, let namedService = legacyServices[providerName] {
            service = namedService
        } else {
            // Use default service based on type
            switch options.type {
            case .movie:
                service = MetadataSearch.defaultMovieService
            case .tvShow:
                service = MetadataSearch.defaultTVService
            }
        }
        
        // Determine language
        let language = options.language ?? service.defaultLanguage
        
        // Perform search based on type - wrap legacy callback-based API in async
        return await withCheckedContinuation { continuation in
            let search: MetadataSearch
            switch options.type {
            case .movie:
                search = MetadataSearch.movieSeach(service: service, movie: options.query, language: language)
            case .tvShow(let season, let episode):
                search = MetadataSearch.tvSearch(service: service, tvShow: options.query, season: season, episode: episode, language: language)
            }
            
            // Run the search asynchronously using the legacy Runnable protocol
            let task = search.search { (results: [MetadataResult]) in
                // Convert legacy MetadataResult (class) to modern MetadataResult (struct)
                let converted = results.map { legacyResult in
                    self.convertLegacyResult(legacyResult, providerID: service.name)
                }
                continuation.resume(returning: converted)
            }
            
            // Execute the task asynchronously
            task.runAsync()
        }
    }
    
    // MARK: - Result Conversion
    
    private func convertLegacyResult(_ legacy: MetadataResult, providerID: String) -> MetadataResult {
        // Extract information from legacy MetadataResult
        let title = legacy[.name] as? String ?? ""
        let year = extractYear(from: legacy)
        let score: Double? = nil // Legacy results don't have scores
        
        return MetadataResult(
            id: legacy[.serviceContentID] as? String ?? UUID().uuidString,
            title: title,
            score: score,
            year: year,
            source: providerID
        )
    }
    
    private func extractYear(from legacy: MetadataResult) -> Int? {
        if let releaseDate = legacy[.releaseDate] as? Date {
            return Calendar.current.component(.year, from: releaseDate)
        } else if let releaseDateString = legacy[.releaseDate] as? String {
            // Try to parse date string
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: releaseDateString) {
                return Calendar.current.component(.year, from: date)
            }
            // Try to extract year from string
            if let year = Int(releaseDateString.prefix(4)) {
                return year
            }
        }
        return nil
    }
    
    // MARK: - Result Sorting and Deduplication
    
    private func sortAndDeduplicate(results: [MetadataResult], yearHint: Int?) -> [MetadataResult] {
        // Deduplicate by ID and title
        var seen: Set<String> = []
        var unique: [MetadataResult] = []
        
        for result in results {
            let key = "\(result.id)-\(result.title)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(result)
            }
        }
        
        // Sort by score, then by year proximity if year hint provided
        return unique.sorted { lhs, rhs in
            let lhsScore = lhs.score ?? 0
            let rhsScore = rhs.score ?? 0
            
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            
            // If scores are equal and year hint provided, prefer closer year
            if let hint = yearHint {
                if let ly = lhs.year, let ry = rhs.year {
                    return abs(hint - ly) < abs(hint - ry)
                }
            }
            
            // Fallback: prefer results with years
            if lhs.year != nil && rhs.year == nil {
                return true
            }
            if lhs.year == nil && rhs.year != nil {
                return false
            }
            
            // Final fallback: alphabetical
            return lhs.title < rhs.title
        }
    }
    
    // MARK: - Fetch Details
    
    /// Fetches detailed metadata for a result, trying modern providers first, then legacy
    public func fetchDetails(for result: MetadataResult) async throws -> MetadataDetails {
        // Try modern providers first
        if let modernProvider = modernProviders.first(where: { $0.id == result.source }) {
            return try await modernProvider.fetchDetails(for: result.id)
        }
        
        // Fall back to legacy service
        if let legacyService = legacyServices[result.source] {
            return try await fetchLegacyDetails(result: result, service: legacyService)
        }
        
        throw SearchError.providerNotFound(result.source)
    }
    
    private func fetchLegacyDetails(result: MetadataResult, service: MetadataService) async throws -> MetadataDetails {
        // Reconstruct legacy MetadataResult (class-based)
        let legacyResult = MetadataResult()
        legacyResult[.serviceContentID] = result.id
        legacyResult[.name] = result.title
        
        // Determine language
        let language = service.defaultLanguage
        
        // Try movie search first (most common)
        // Note: In a production system, you'd want to track the original search type
        // For now, we'll try movie search
        let movieSearch = MetadataSearch.movieSeach(service: service, movie: result.title, language: language)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = movieSearch.loadAdditionalMetadata(legacyResult, language: language) { (loadedResult: MetadataResult) in
                let details = self.convertLegacyToDetails(loadedResult, providerID: service.name)
                continuation.resume(returning: details)
            }
            // Execute asynchronously
            task.runAsync()
        }
    }
    
    private func convertLegacyToDetails(_ legacy: MetadataResult, providerID: String) -> MetadataDetails {
        let title = legacy[.name] as? String ?? ""
        let releaseDate = legacy[.releaseDate] as? Date
        let synopsis = legacy[.longDescription] as? String
        let studio = legacy[.studio] as? String
        let rating = legacy[.rating] as? Double
        
        // Extract performers
        var performers: [String] = []
        if let cast = legacy[.cast] as? [String] {
            performers = cast
        } else if let castString = legacy[.cast] as? String {
            performers = castString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        // Extract directors
        var directors: [String] = []
        if let directorString = legacy[.director] as? String {
            directors = directorString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        // TV show specific
        let show = legacy[.seriesName] as? String
        let seasonNumber = legacy[.season] as? Int
        let episodeNumber = legacy[.episodeNumber] as? Int
        
        return MetadataDetails(
            id: legacy[.serviceContentID] as? String ?? UUID().uuidString,
            title: title,
            releaseDate: releaseDate,
            studio: studio,
            synopsis: synopsis,
            performers: performers,
            directors: directors,
            rating: rating,
            show: show,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            coverURL: nil // Legacy results may have artwork, but URL extraction would need additional work
        )
    }
    
    // MARK: - Available Providers
    
    public var availableProviders: [String] {
        var providers: [String] = []
        providers.append(contentsOf: modernProviders.map { $0.id })
        providers.append(contentsOf: legacyServices.keys)
        return Array(Set(providers)).sorted()
    }
}

// MARK: - Errors

public enum SearchError: LocalizedError {
    case providerNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .providerNotFound(let name):
            return "Search provider '\(name)' not found"
        }
    }
}

