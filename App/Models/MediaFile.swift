import Foundation

public struct MediaFile: Identifiable, Hashable, Sendable {
    public let id: UUID = UUID()
    public let url: URL
    public let displayName: String
    public let size: Int64?
    public let tracks: [MediaTrack]?
    public let chapters: [Chapter]?
    public let containerFormat: ContainerFormat?

    public init(url: URL, size: Int64? = nil, tracks: [MediaTrack]? = nil, chapters: [Chapter]? = nil, containerFormat: ContainerFormat? = nil) {
        self.url = url
        self.displayName = url.deletingPathExtension().lastPathComponent
        self.size = size
        self.tracks = tracks
        self.chapters = chapters
        self.containerFormat = containerFormat ?? ContainerImporter.detectFormat(url: url)
    }
}

public struct MediaTrack: Identifiable, Hashable, Sendable, Codable {
    public enum Kind: String, Codable, Sendable {
        case video, audio, subtitle, timecode, metadata, unknown
    }

    public let id: UUID
    public let kind: Kind
    public let codec: String?
    public let language: String?
    public let bitrate: Int?
    public let isDefault: Bool
    public let isForced: Bool
    public let resolution: String?
    public let hdr: Bool

    public init(
        id: UUID = UUID(),
        kind: Kind,
        codec: String? = nil,
        language: String? = nil,
        bitrate: Int? = nil,
        isDefault: Bool = false,
        isForced: Bool = false,
        resolution: String? = nil,
        hdr: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.codec = codec
        self.language = language
        self.bitrate = bitrate
        self.isDefault = isDefault
        self.isForced = isForced
        self.resolution = resolution
        self.hdr = hdr
    }
}

public struct Chapter: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let title: String
    public let startSeconds: Double

    public init(id: UUID = UUID(), title: String, startSeconds: Double) {
        self.id = id
        self.title = title
        self.startSeconds = startSeconds
    }
}

