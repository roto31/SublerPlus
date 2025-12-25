import Foundation

public struct MetadataResult: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let score: Double?
    public let year: Int?

    public init(id: String, title: String, score: Double? = nil, year: Int? = nil) {
        self.id = id
        self.title = title
        self.score = score
        self.year = year
    }
}

