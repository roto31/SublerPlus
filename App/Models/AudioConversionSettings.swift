import Foundation

public struct AudioConversionSettings: Sendable, Codable {
    public enum TargetCodec: String, Codable, Sendable {
        case aac = "aac"
        case ac3 = "ac3"
        case mlp = "mlp" // Meridian Lossless Packing (typically converted to AC3)
        case passthrough = "passthrough" // Don't convert
        
        public var displayName: String {
            switch self {
            case .aac: return "AAC"
            case .ac3: return "AC3"
            case .mlp: return "MLP"
            case .passthrough: return "Passthrough (No Conversion)"
            }
        }
    }
    
    public enum Mixdown: String, Codable, Sendable {
        case mono = "mono"
        case stereo = "stereo"
        case dolby = "dolby"
        case dolbyProLogicII = "dolbyprologic2"
        case auto = "auto" // Keep original
        
        public var displayName: String {
            switch self {
            case .mono: return "Mono"
            case .stereo: return "Stereo"
            case .dolby: return "Dolby"
            case .dolbyProLogicII: return "Dolby Pro Logic II"
            case .auto: return "Auto (Keep Original)"
            }
        }
    }
    
    public var targetCodec: TargetCodec
    public var bitrate: Int? // kbps, nil = auto
    public var mixdown: Mixdown
    public var drc: Double? // Dynamic Range Compression (0.0-1.0), nil = disabled
    public var sampleRate: Int? // Hz, nil = keep original
    
    public init(
        targetCodec: TargetCodec = .aac,
        bitrate: Int? = nil,
        mixdown: Mixdown = .auto,
        drc: Double? = nil,
        sampleRate: Int? = nil
    ) {
        self.targetCodec = targetCodec
        self.bitrate = bitrate
        self.mixdown = mixdown
        self.drc = drc
        self.sampleRate = sampleRate
    }
    
    /// Default settings for high-quality AAC conversion
    public static var defaultAAC: AudioConversionSettings {
        AudioConversionSettings(
            targetCodec: .aac,
            bitrate: 256,
            mixdown: .auto,
            drc: nil,
            sampleRate: nil
        )
    }
    
    /// Default settings for AC3 conversion
    public static var defaultAC3: AudioConversionSettings {
        AudioConversionSettings(
            targetCodec: .ac3,
            bitrate: 640,
            mixdown: .auto,
            drc: nil,
            sampleRate: nil
        )
    }
}

