import Foundation

/// Muxing preset configuration
public struct Preset: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var videoSettings: VideoPresetSettings?
    public var audioSettings: AudioPresetSettings?
    public var subtitleSettings: SubtitlePresetSettings?
    public var outputFormat: MP4BrandHandler.OutputFormat
    public var optimize: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        videoSettings: VideoPresetSettings? = nil,
        audioSettings: AudioPresetSettings? = nil,
        subtitleSettings: SubtitlePresetSettings? = nil,
        outputFormat: MP4BrandHandler.OutputFormat = .mp4,
        optimize: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.videoSettings = videoSettings
        self.audioSettings = audioSettings
        self.subtitleSettings = subtitleSettings
        self.outputFormat = outputFormat
        self.optimize = optimize
    }
}

public struct VideoPresetSettings: Codable, Sendable {
    public var keepAllTracks: Bool
    public var preferredCodec: String?
    public var maxResolution: String? // e.g., "1920x1080"
    public var preserveHDR: Bool
    
    public init(
        keepAllTracks: Bool = true,
        preferredCodec: String? = nil,
        maxResolution: String? = nil,
        preserveHDR: Bool = true
    ) {
        self.keepAllTracks = keepAllTracks
        self.preferredCodec = preferredCodec
        self.maxResolution = maxResolution
        self.preserveHDR = preserveHDR
    }
}

public struct AudioPresetSettings: Codable, Sendable {
    public var keepAllTracks: Bool
    public var conversionSettings: AudioConversionSettings?
    public var preferredLanguage: String?
    public var maxChannels: Int? // e.g., 2 for stereo, 6 for 5.1
    
    public init(
        keepAllTracks: Bool = true,
        conversionSettings: AudioConversionSettings? = nil,
        preferredLanguage: String? = nil,
        maxChannels: Int? = nil
    ) {
        self.keepAllTracks = keepAllTracks
        self.conversionSettings = conversionSettings
        self.preferredLanguage = preferredLanguage
        self.maxChannels = maxChannels
    }
}

public struct SubtitlePresetSettings: Codable, Sendable {
    public var keepAllTracks: Bool
    public var preferredLanguage: String?
    public var convertToTX3G: Bool
    public var removeForced: Bool
    
    public init(
        keepAllTracks: Bool = true,
        preferredLanguage: String? = nil,
        convertToTX3G: Bool = true,
        removeForced: Bool = false
    ) {
        self.keepAllTracks = keepAllTracks
        self.preferredLanguage = preferredLanguage
        self.convertToTX3G = convertToTX3G
        self.removeForced = removeForced
    }
}

/// Built-in presets matching Subler's common use cases
public enum BuiltInPreset: String, CaseIterable, Identifiable {
    case passthrough = "Passthrough"
    case appleTV = "Apple TV"
    case iphone = "iPhone"
    case ipad = "iPad"
    case audioOnly = "Audio Only"
    case audiobook = "Audiobook"
    
    public var id: String { rawValue }
    
    public func createPreset() -> Preset {
        switch self {
        case .passthrough:
            return Preset(
                name: "Passthrough",
                description: "Copy all tracks without conversion",
                outputFormat: .mp4,
                optimize: false
            )
            
        case .appleTV:
            return Preset(
                name: "Apple TV",
                description: "Optimized for Apple TV playback",
                videoSettings: VideoPresetSettings(
                    keepAllTracks: true,
                    preserveHDR: true
                ),
                audioSettings: AudioPresetSettings(
                    keepAllTracks: true,
                    preferredLanguage: "eng"
                ),
                subtitleSettings: SubtitlePresetSettings(
                    keepAllTracks: true,
                    preferredLanguage: "eng",
                    convertToTX3G: true
                ),
                outputFormat: .m4v,
                optimize: true
            )
            
        case .iphone:
            return Preset(
                name: "iPhone",
                description: "Optimized for iPhone playback",
                videoSettings: VideoPresetSettings(
                    keepAllTracks: false,
                    maxResolution: "1920x1080",
                    preserveHDR: false
                ),
                audioSettings: AudioPresetSettings(
                    keepAllTracks: false,
                    conversionSettings: AudioConversionSettings.defaultAAC,
                    preferredLanguage: "eng",
                    maxChannels: 2
                ),
                subtitleSettings: SubtitlePresetSettings(
                    keepAllTracks: true,
                    preferredLanguage: "eng",
                    convertToTX3G: true
                ),
                outputFormat: .m4v,
                optimize: true
            )
            
        case .ipad:
            return Preset(
                name: "iPad",
                description: "Optimized for iPad playback",
                videoSettings: VideoPresetSettings(
                    keepAllTracks: true,
                    preserveHDR: true
                ),
                audioSettings: AudioPresetSettings(
                    keepAllTracks: true,
                    preferredLanguage: "eng"
                ),
                subtitleSettings: SubtitlePresetSettings(
                    keepAllTracks: true,
                    preferredLanguage: "eng",
                    convertToTX3G: true
                ),
                outputFormat: .m4v,
                optimize: true
            )
            
        case .audioOnly:
            return Preset(
                name: "Audio Only",
                description: "Extract audio tracks only",
                videoSettings: nil,
                audioSettings: AudioPresetSettings(
                    keepAllTracks: true
                ),
                subtitleSettings: nil,
                outputFormat: .m4a,
                optimize: false
            )
            
        case .audiobook:
            return Preset(
                name: "Audiobook",
                description: "Optimized for audiobook playback",
                videoSettings: nil,
                audioSettings: AudioPresetSettings(
                    keepAllTracks: false,
                    conversionSettings: AudioConversionSettings(
                        targetCodec: .aac,
                        bitrate: 128,
                        mixdown: .stereo
                    ),
                    preferredLanguage: "eng"
                ),
                subtitleSettings: nil,
                outputFormat: .m4b,
                optimize: false
            )
        }
    }
}

