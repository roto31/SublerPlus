import Foundation

public struct MetadataResult: Sendable, Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let score: Double?
    public let year: Int?
    public let source: String?
    public let coverURL: URL?
    public let language: String?
    public let isSubtitle: Bool

    public init(id: String, title: String, score: Double? = nil, year: Int? = nil, source: String? = nil, coverURL: URL? = nil, language: String? = nil, isSubtitle: Bool = false) {
        self.id = id
        self.title = title
        self.score = score
        self.year = year
        self.source = source
        self.coverURL = coverURL
        self.language = language
        self.isSubtitle = isSubtitle
    }
}

