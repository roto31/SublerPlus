#if canImport(MP42Foundation)
import Foundation
import MP42Foundation

/// TVDB provider wrapped as Subler MetadataService
public struct TVDBMetadataService: MetadataService {
    
    private let provider: TVDBProvider
    
    public init(provider: TVDBProvider) {
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
        return "TheTVDB"
    }
    
    // MARK: - Movie Search (TVDB is primarily for TV shows)
    
    public func search(movie: String, language: String) -> [MetadataResult] {
        // TVDB is primarily for TV shows, but we can try
        let adapter = SublerMetadataServiceAdapter(provider: provider, languageType: .ISO, defaultLanguage: "en")
        return adapter.search(movie: movie, language: language)
    }
    
    public func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        let adapter = SublerMetadataServiceAdapter(provider: provider, languageType: .ISO, defaultLanguage: "en")
        return adapter.loadMovieMetadata(metadata, language: language)
    }
    
    // MARK: - TV Show Search
    
    public func search(tvShow: String, language: String) -> [String] {
        // Return the query itself (TVDB doesn't have separate name search)
        return [tvShow]
    }
    
    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        let adapter = SublerMetadataServiceAdapter(provider: provider, languageType: .ISO, defaultLanguage: "en")
        return adapter.search(tvShow: tvShow, language: language, season: season, episode: episode)
    }
    
    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        let adapter = SublerMetadataServiceAdapter(provider: provider, languageType: .ISO, defaultLanguage: "en")
        return adapter.loadTVMetadata(metadata, language: language)
    }
}


#endif
