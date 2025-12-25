import Foundation

public final class SublerProvider: PipelineMetadataProvider, @unchecked Sendable {
    public let id = "subler"
    public let isAdult = false
    private let mp4Handler: MP4Handler

    public init(mp4Handler: MP4Handler) {
        self.mp4Handler = mp4Handler
    }

    public func fetch(for file: URL, hint: MetadataHint) async throws -> MetadataDetails {
        // Leverage the MP4 handler to read embedded tags.
        let read = try mp4Handler.readMetadata(at: file)
        return MetadataDetails(
            id: UUID().uuidString,
            title: read.title,
            synopsis: nil,
            releaseDate: nil,
            studio: nil,
            tags: [],
            performers: read.performers ?? [],
            coverURL: nil,
            rating: nil
        )
    }
}

