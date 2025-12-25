import Foundation

public struct AmbiguousMatch: Identifiable {
    public let id = UUID()
    public let file: URL
    public let choices: [MetadataDetails]
}

