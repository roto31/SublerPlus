import Foundation

public struct MuxingOptions: Sendable {
    public var outputURL: URL?
    public var selectedTracks: Set<UUID> // Track IDs to include
    public var optimize: Bool = false
    public var use64BitData: Bool = false
    public var use64BitTime: Bool = false
    public var defaultAudioSettings: AudioConversionSettings?
    
    public init(
        outputURL: URL? = nil,
        selectedTracks: Set<UUID> = [],
        optimize: Bool = false,
        use64BitData: Bool = false,
        use64BitTime: Bool = false,
        defaultAudioSettings: AudioConversionSettings? = nil
    ) {
        self.outputURL = outputURL
        self.selectedTracks = selectedTracks
        self.optimize = optimize
        self.use64BitData = use64BitData
        self.use64BitTime = use64BitTime
        self.defaultAudioSettings = defaultAudioSettings
    }
}

public struct TrackSelection: Identifiable, Sendable {
    public let id: UUID
    public let track: MediaTrack
    public let sourceURL: URL
    public var selected: Bool
    public var conversionSettings: AudioConversionSettings? // For audio tracks that need conversion
    
    public init(
        id: UUID = UUID(),
        track: MediaTrack,
        sourceURL: URL,
        selected: Bool = true,
        conversionSettings: AudioConversionSettings? = nil
    ) {
        self.id = id
        self.track = track
        self.sourceURL = sourceURL
        self.selected = selected
        self.conversionSettings = conversionSettings
    }
}

