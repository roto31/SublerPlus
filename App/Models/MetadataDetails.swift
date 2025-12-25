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
        source: String? = nil
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
            source: source
        )
    }
}

