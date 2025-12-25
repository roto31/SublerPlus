import Foundation

public struct AmbiguityResolutionKey: Hashable, Codable {
    public let title: String
    public let year: Int?
    public let studio: String?

    public init(title: String, year: Int?, studio: String?) {
        self.title = title
        self.year = year
        self.studio = studio
    }
}

