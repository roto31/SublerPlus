import Foundation

public struct MetadataResult: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let score: Double?
    public let year: Int?
    public let source: String?

    public init(id: String, title: String, score: Double? = nil, year: Int? = nil, source: String? = nil) {
        self.id = id
        self.title = title
        self.score = score
        self.year = year
        self.source = source
    }
}

