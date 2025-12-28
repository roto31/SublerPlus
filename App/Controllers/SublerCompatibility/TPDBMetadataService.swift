#if canImport(MP42Foundation)
import Foundation
import MP42Foundation

/// TPDB provider wrapped as Subler MetadataService
public struct TPDBMetadataService: MetadataService {
    
    private let provider: ThePornDBProvider
    
    public init(provider: ThePornDBProvider) {
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
        return "ThePornDB"
    }
    
    // MARK: - Movie Search (TPDB treats everything as "scenes")
    
    public func search(movie: String, language: String) -> [MetadataResult] {
        let adapter = SublerMetadataServiceAdapter(provider: provider, languageType: .ISO, defaultLanguage: "en")
        return adapter.search(movie: movie, language: language)
    }
    
    public func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        let adapter = SublerMetadataServiceAdapter(provider: provider, languageType: .ISO, defaultLanguage: "en")
        return adapter.loadMovieMetadata(metadata, language: language)
    }
    
    // MARK: - TV Show Search (not supported by TPDB)
    
    public func search(tvShow: String, language: String) -> [String] {
        // TPDB doesn't support TV shows
        return []
    }
    
    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        // TPDB doesn't support TV shows
        return []
    }
    
    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        // TPDB doesn't support TV shows
        return metadata
    }
}


#endif
