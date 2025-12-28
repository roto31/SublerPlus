#if canImport(MP42Foundation)
import Foundation
import MP42Foundation

/// Extension to MetadataSearch to register new providers (TPDB, TVDB, TMDB)
/// This extends Subler's MetadataSearch enum without modifying the original
extension MetadataSearch {
    
    /// Factory function to create a MetadataService from provider instances
    /// This allows us to inject modern providers into Subler's system
    public static func createService(
        name: String,
        tpdbProvider: ThePornDBProvider? = nil,
        tvdbProvider: TVDBProvider? = nil,
        tmdbProvider: StandardMetadataProvider? = nil
    ) -> MetadataService? {
        switch name {
        case "ThePornDB", "TPDB":
            if let provider = tpdbProvider {
                return TPDBMetadataService(provider: provider)
            }
        case "TheTVDB", "TVDB":
            if let provider = tvdbProvider {
                return TVDBMetadataService(provider: provider)
            }
        case "TheMovieDB", "TMDB":
            if let provider = tmdbProvider {
                return TMDBMetadataService(provider: provider)
            }
        default:
            // Fall back to Subler's original service factory
            return MetadataSearch.service(name: name)
        }
        return nil
    }
    
    /// Extended service factory that includes new providers
    /// This should be used instead of the original service(name:) when new providers are available
    public static func extendedService(
        name: String?,
        tpdbProvider: ThePornDBProvider? = nil,
        tvdbProvider: TVDBProvider? = nil,
        tmdbProvider: StandardMetadataProvider? = nil
    ) -> MetadataService {
        guard let name = name else {
            return MetadataSearch.defaultMovieService
        }
        
        // Try new providers first
        if let service = createService(name: name, tpdbProvider: tpdbProvider, tvdbProvider: tvdbProvider, tmdbProvider: tmdbProvider) {
            return service
        }
        
        // Fall back to original Subler providers
        return MetadataSearch.service(name: name)
    }
    
    /// Extended movie providers list including new providers
    public static func extendedMovieProviders(
        includeTPDB: Bool = false,
        includeTMDB: Bool = true
    ) -> [String] {
        var providers = MetadataSearch.movieProviders
        
        // Add new providers in priority order
        if includeTMDB {
            providers.insert("TheMovieDB", at: 1) // After AppleTV, before iTunesStore
        }
        if includeTPDB {
            providers.append("ThePornDB") // At the end
        }
        
        return providers
    }
    
    /// Extended TV providers list including new providers
    public static func extendedTVProviders(
        includeTPDB: Bool = false,
        includeTVDB: Bool = true,
        includeTMDB: Bool = false
    ) -> [String] {
        var providers = MetadataSearch.tvProviders
        
        // Add new providers in priority order
        if includeTVDB {
            // Insert after TheMovieDB if present, otherwise after AppleTV
            if let tmdbIndex = providers.firstIndex(of: "TheMovieDB") {
                providers.insert("TheTVDB", at: tmdbIndex + 1)
            } else {
                providers.insert("TheTVDB", at: 1)
            }
        }
        if includeTMDB {
            // TMDB is primarily for movies, but can be used for TV
            if !providers.contains("TheMovieDB") {
                providers.insert("TheMovieDB", at: 1)
            }
        }
        if includeTPDB {
            providers.append("ThePornDB") // At the end
        }
        
        return providers
    }
}


#endif
