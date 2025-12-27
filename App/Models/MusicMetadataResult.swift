import Foundation

public struct AlbumMetadata: Sendable, Identifiable {
    public let id: Int
    public let albumID: Int
    public let title: String
    public let artist: String
    public let releaseDate: Date?
    public let genre: String?
    public let artworkURL: URL?
    public let artworkURLHighRes: URL?
    public let tracks: [TrackMetadata]
    public let country: String
    
    public init(id: Int, albumID: Int, title: String, artist: String, releaseDate: Date?, genre: String?, artworkURL: URL?, artworkURLHighRes: URL?, tracks: [TrackMetadata], country: String) {
        self.id = albumID
        self.albumID = albumID
        self.title = title
        self.artist = artist
        self.releaseDate = releaseDate
        self.genre = genre
        self.artworkURL = artworkURL
        self.artworkURLHighRes = artworkURLHighRes
        self.tracks = tracks
        self.country = country
    }
}

public struct TrackMetadata: Sendable, Identifiable {
    public let id: Int
    public let trackID: Int
    public let title: String
    public let artist: String
    public let duration: TimeInterval
    public let trackNumber: Int?
    public let discNumber: Int?
    public let genre: String?
    public let releaseDate: Date?
    public let albumName: String?
    
    public init(id: Int, trackID: Int, title: String, artist: String, duration: TimeInterval, trackNumber: Int?, discNumber: Int?, genre: String?, releaseDate: Date?, albumName: String?) {
        self.id = trackID
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.duration = duration
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.genre = genre
        self.releaseDate = releaseDate
        self.albumName = albumName
    }
}

