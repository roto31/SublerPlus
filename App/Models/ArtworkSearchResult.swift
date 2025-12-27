import Foundation

public struct ArtworkSearchResult: Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let artist: String?
    public let artworkURL: URL
    public let artworkURLHighRes: URL?
    public let mediaType: iTunesArtworkProvider.MediaType
    public let country: String
    public let previewURL: URL?
    
    public init(from result: iTunesArtworkProvider.ArtworkResult) {
        self.id = result.id
        self.title = result.title
        self.artist = result.artist
        self.artworkURL = result.artworkURL
        self.artworkURLHighRes = result.artworkURLHighRes
        self.mediaType = result.mediaType
        self.country = result.country
        self.previewURL = result.previewURL
    }
}

