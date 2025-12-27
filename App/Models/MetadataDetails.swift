import Foundation

public struct MetadataDetails: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let synopsis: String?
    public let releaseDate: Date?
    public let studio: String?
    public let tags: [String]
    public let performers: [String]
    public let coverURL: URL?
    public let rating: Double?
    public let source: String?
    public let show: String?
    public let episodeID: String?
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let mediaKind: MediaKind?
    public let sortTitle: String?
    public let sortArtist: String?
    public let sortAlbum: String?
    public let trackNumber: Int?
    public let trackTotal: Int?
    public let discNumber: Int?
    public let discTotal: Int?
    public let isHD: Bool?
    public let isHEVC: Bool?
    public let isHDR: Bool?
    public let artworkAlternates: [URL]?
    public let lyrics: String?
    public let contentRating: Int?
    public let isGapless: Bool?
    public let isCompilation: Bool?

    public init(
        id: String,
        title: String,
        synopsis: String? = nil,
        releaseDate: Date? = nil,
        studio: String? = nil,
        tags: [String] = [],
        performers: [String] = [],
        coverURL: URL? = nil,
        rating: Double? = nil,
        source: String? = nil,
        show: String? = nil,
        episodeID: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        mediaKind: MediaKind? = nil,
        sortTitle: String? = nil,
        sortArtist: String? = nil,
        sortAlbum: String? = nil,
        trackNumber: Int? = nil,
        trackTotal: Int? = nil,
        discNumber: Int? = nil,
        discTotal: Int? = nil,
        isHD: Bool? = nil,
        isHEVC: Bool? = nil,
        isHDR: Bool? = nil,
        artworkAlternates: [URL]? = nil,
        lyrics: String? = nil,
        contentRating: Int? = nil,
        isGapless: Bool? = nil,
        isCompilation: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.synopsis = synopsis
        self.releaseDate = releaseDate
        self.studio = studio
        self.tags = tags
        self.performers = performers
        self.coverURL = coverURL
        self.rating = rating
        self.source = source
        self.show = show
        self.episodeID = episodeID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.mediaKind = mediaKind
        self.sortTitle = sortTitle
        self.sortArtist = sortArtist
        self.sortAlbum = sortAlbum
        self.trackNumber = trackNumber
        self.trackTotal = trackTotal
        self.discNumber = discNumber
        self.discTotal = discTotal
        self.isHD = isHD
        self.isHEVC = isHEVC
        self.isHDR = isHDR
        self.artworkAlternates = artworkAlternates
        self.lyrics = lyrics
        self.contentRating = contentRating
        self.isGapless = isGapless
        self.isCompilation = isCompilation
    }
}

public extension MetadataDetails {
    func withSource(_ source: String) -> MetadataDetails {
        MetadataDetails(
            id: id,
            title: title,
            synopsis: synopsis,
            releaseDate: releaseDate,
            studio: studio,
            tags: tags,
            performers: performers,
            coverURL: coverURL,
            rating: rating,
            source: source,
            show: show,
            episodeID: episodeID,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            mediaKind: mediaKind,
            sortTitle: sortTitle,
            sortArtist: sortArtist,
            sortAlbum: sortAlbum,
            trackNumber: trackNumber,
            trackTotal: trackTotal,
            discNumber: discNumber,
            discTotal: discTotal,
            isHD: isHD,
            isHEVC: isHEVC,
            isHDR: isHDR,
            artworkAlternates: artworkAlternates,
            lyrics: lyrics,
            contentRating: contentRating,
            isGapless: isGapless,
            isCompilation: isCompilation
        )
    }

    func withCover(_ cover: URL?) -> MetadataDetails {
        MetadataDetails(
            id: id,
            title: title,
            synopsis: synopsis,
            releaseDate: releaseDate,
            studio: studio,
            tags: tags,
            performers: performers,
            coverURL: cover,
            rating: rating,
            source: source,
            show: show,
            episodeID: episodeID,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            mediaKind: mediaKind,
            sortTitle: sortTitle,
            sortArtist: sortArtist,
            sortAlbum: sortAlbum,
            trackNumber: trackNumber,
            trackTotal: trackTotal,
            discNumber: discNumber,
            discTotal: discTotal,
            isHD: isHD,
            isHEVC: isHEVC,
            isHDR: isHDR,
            artworkAlternates: artworkAlternates,
            lyrics: lyrics,
            contentRating: contentRating,
            isGapless: isGapless,
            isCompilation: isCompilation
        )
    }
}

public enum MediaKind: String, Codable, Sendable {
    case movie
    case tvShow
    case musicVideo
    case podcast
    case audiobook
    case shortFilm
    case ringtone
    case other
    case unknown
}

