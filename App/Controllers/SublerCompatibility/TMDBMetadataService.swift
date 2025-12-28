#if canImport(MP42Foundation)
import Foundation
import MP42Foundation

/// TMDB provider wrapped as Subler MetadataService
public struct TMDBMetadataService: MetadataService {
    
    private let provider: StandardMetadataProvider
    
    public init(provider: StandardMetadataProvider) {
        self.provider = provider
    }
    
    // MARK: - MetadataService Protocol
    
    public var languageType: LanguageType {
        return .ISO
    }
    
    public var languages: [String] {
        return MP42Languages.defaultManager.iso_639_1Languages
    }
    
    public var defaultLanguage: String {
        return "en"
    }
    
    public var name: String {
        return "TheMovieDB"
    }
    
    // MARK: - Movie Search
    
    public func search(movie: String, language: String) -> [MetadataResult] {
        let adapter = SublerMetadataServiceAdapter(provider: provider, languageType: .ISO, defaultLanguage: "en")
        return adapter.search(movie: movie, language: language)
    }
    
    public func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        let adapter = SublerMetadataServiceAdapter(provider: provider, languageType: .ISO, defaultLanguage: "en")
        return adapter.loadMovieMetadata(metadata, language: language)
    }
    
    // MARK: - TV Show Search
    
    public func search(tvShow: String, language: String) -> [String] {
        // Return the query itself (TMDB doesn't have separate name search in this implementation)
        return [tvShow]
    }
    
    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        // TMDB StandardMetadataProvider is movie-only, return empty for TV
        // In a full implementation, we'd need a TV-specific TMDB provider
        return []
    }
    
    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        // TMDB StandardMetadataProvider is movie-only
        return metadata
    }
}


#endif
