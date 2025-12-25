import Foundation

public struct MetadataHint: Sendable {
    public let title: String
    public let year: Int?
    public let performers: [String]?

    public init(title: String, year: Int? = nil, performers: [String]? = nil) {
        self.title = title
        self.year = year
        self.performers = performers
    }
}

public protocol MetadataProvider: Sendable {
    var id: String { get }
    var isAdult: Bool { get }
    func search(query: String) async throws -> [MetadataResult]
    func fetchDetails(for id: String) async throws -> MetadataDetails
}

public protocol PipelineMetadataProvider: Sendable {
    var id: String { get }
    var isAdult: Bool { get }
    func fetch(for file: URL, hint: MetadataHint) async throws -> MetadataDetails
}

