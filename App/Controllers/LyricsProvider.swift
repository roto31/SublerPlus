import Foundation

public enum LyricsError: Error, Equatable {
    case notFound
    case networkError(String)
    case invalidResponse
    case apiKeyRequired
}

public final class LyricsProvider: @unchecked Sendable {
    private let session: URLSession
    private let musixmatchAPIKey: String?
    
    public init(session: URLSession = .shared, musixmatchAPIKey: String? = nil) {
        self.session = session
        self.musixmatchAPIKey = musixmatchAPIKey
    }
    
    /// Get lyrics for a track using track name and artist
    public func getLyrics(track: String, artist: String) async throws -> String? {
        // Try iTunes first (limited availability)
        if let lyrics = try? await getLyricsFromiTunes(track: track, artist: artist) {
            return lyrics
        }
        
        // Fallback to Musixmatch if API key is available
        if let apiKey = musixmatchAPIKey {
            if let lyrics = try? await getLyricsFromMusixmatch(track: track, artist: artist, apiKey: apiKey) {
                return lyrics
            }
        }
        
        throw LyricsError.notFound
    }
    
    /// Get lyrics by iTunes track ID
    public func getLyricsByTrackID(_ trackID: Int, country: String = "us") async throws -> String? {
        // iTunes API doesn't provide lyrics directly by track ID
        // We'd need to lookup the track first, then get lyrics
        // For now, return nil and rely on track/artist lookup
        return nil
    }
    
    // MARK: - Private Methods
    
    private func getLyricsFromiTunes(track: String, artist: String) async throws -> String? {
        // iTunes Search API doesn't directly provide lyrics
        // Lyrics are typically embedded in the track file itself
        // This is a placeholder for future implementation
        // Could potentially use iTunes Store web scraping or other methods
        return nil
    }
    
    private func getLyricsFromMusixmatch(track: String, artist: String, apiKey: String) async throws -> String? {
        guard !apiKey.isEmpty else {
            throw LyricsError.apiKeyRequired
        }
        
        var components = URLComponents(string: "https://api.musixmatch.com/ws/1.1/matcher.lyrics.get")!
        components.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "q_track", value: track),
            URLQueryItem(name: "q_artist", value: artist),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components.url else {
            throw LyricsError.invalidResponse
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw LyricsError.networkError("HTTP \(response)")
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let message = json?["message"] as? [String: Any],
                  let body = message["body"] as? [String: Any],
                  let lyricsObj = body["lyrics"] as? [String: Any],
                  let lyricsBody = lyricsObj["lyrics_body"] as? String else {
                throw LyricsError.notFound
            }
            
            // Musixmatch adds a disclaimer at the end - remove it
            let disclaimer = "******* This Lyrics is NOT for Commercial use *******"
            if lyricsBody.contains(disclaimer) {
                return String(lyricsBody.prefix(upTo: lyricsBody.range(of: disclaimer)?.lowerBound ?? lyricsBody.endIndex))
            }
            
            return lyricsBody.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as LyricsError {
            throw error
        } catch {
            throw LyricsError.networkError(error.localizedDescription)
        }
    }
}

