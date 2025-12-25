import Foundation

public struct MediaFile: Identifiable, Hashable, Sendable {
    public let id: UUID = UUID()
    public let url: URL
    public let displayName: String
    public let size: Int64?

    public init(url: URL, size: Int64? = nil) {
        self.url = url
        self.displayName = url.deletingPathExtension().lastPathComponent
        self.size = size
    }
}

