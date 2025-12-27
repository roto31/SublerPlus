import Foundation

/// Detects codecs using FFmpeg/ffprobe
public final class FFmpegCodecDetector: @unchecked Sendable {
    
    public init() {}
    
    /// Detect all codecs in a media file
    public func detectCodecs(at url: URL) async throws -> [TrackCodecInfo] {
        guard await FFmpegWrapper.isAvailable() else {
            throw FFmpegCodecError.ffmpegNotAvailable
        }
        
        var codecs: [TrackCodecInfo] = []
        
        // Detect video codec
        if let videoCodec = try? await detectVideoCodec(at: url) {
            codecs.append(videoCodec)
        }
        
        // Detect audio codecs
        let audioCodecs = try await detectAudioCodecs(at: url)
        codecs.append(contentsOf: audioCodecs)
        
        // Detect subtitle codecs
        let subtitleCodecs = try await detectSubtitleCodecs(at: url)
        codecs.append(contentsOf: subtitleCodecs)
        
        return codecs
    }
    
    /// Detect video codec
    private func detectVideoCodec(at url: URL) async throws -> TrackCodecInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffprobe")
        process.arguments = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=codec_name,codec_long_name,width,height,pix_fmt",
            "-of", "json",
            url.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            return nil
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streams = json["streams"] as? [[String: Any]],
              let stream = streams.first,
              let codecName = stream["codec_name"] as? String else {
            return nil
        }
        
        let width = stream["width"] as? Int
        let height = stream["height"] as? Int
        
        // Map FFmpeg codec name to FourCC
        let fourCC = mapFFmpegVideoCodecToFourCC(codecName)
        
        return TrackCodecInfo(
            trackType: .video,
            codec: codecName,
            codecLongName: stream["codec_long_name"] as? String,
            width: width,
            height: height,
            bitrate: nil,
            fourCC: fourCC
        )
    }
    
    /// Detect audio codecs
    private func detectAudioCodecs(at url: URL) async throws -> [TrackCodecInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffprobe")
        process.arguments = [
            "-v", "error",
            "-select_streams", "a",
            "-show_entries", "stream=codec_name,codec_long_name,bit_rate,channels,sample_rate",
            "-of", "json",
            url.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            return []
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streams = json["streams"] as? [[String: Any]] else {
            return []
        }
        
        return streams.compactMap { stream in
            guard let codecName = stream["codec_name"] as? String else {
                return nil
            }
            
            let bitrate = (stream["bit_rate"] as? String).flatMap { Int($0) }
            
            // Map FFmpeg codec name to FourCC
            let fourCC = mapFFmpegAudioCodecToFourCC(codecName)
            
            return TrackCodecInfo(
                trackType: .audio,
                codec: codecName,
                codecLongName: stream["codec_long_name"] as? String,
                width: nil,
                height: nil,
                bitrate: bitrate,
                fourCC: fourCC
            )
        }
    }
    
    /// Detect subtitle codecs
    private func detectSubtitleCodecs(at url: URL) async throws -> [TrackCodecInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffprobe")
        process.arguments = [
            "-v", "error",
            "-select_streams", "s",
            "-show_entries", "stream=codec_name,codec_long_name",
            "-of", "json",
            url.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            return []
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streams = json["streams"] as? [[String: Any]] else {
            return []
        }
        
        return streams.compactMap { stream in
            guard let codecName = stream["codec_name"] as? String else {
                return nil
            }
            
            // Map FFmpeg codec name to FourCC
            let fourCC = mapFFmpegSubtitleCodecToFourCC(codecName)
            
            return TrackCodecInfo(
                trackType: .subtitle,
                codec: codecName,
                codecLongName: stream["codec_long_name"] as? String,
                width: nil,
                height: nil,
                bitrate: nil,
                fourCC: fourCC
            )
        }
    }
    
    /// Map FFmpeg video codec name to FourCC code
    private func mapFFmpegVideoCodecToFourCC(_ ffmpegCodec: String) -> String? {
        switch ffmpegCodec.lowercased() {
        // Modern codecs
        case "h264", "libx264": return "avc1"
        case "hevc", "h265", "libx265": return "hvc1"
        case "av1", "libaom-av1": return "av01"
        case "vp8": return "VP8 "
        case "vp9": return "vp09"
        case "vvc", "h266": return "vvc1"
        
        // Legacy MPEG codecs
        case "mpeg1video": return "mp1v"
        case "mpeg2video": return "mp2v"
        case "mpeg4", "mpeg4video": return "mp4v"
        
        // Theora
        case "theora": return "XiTh"
        
        // ProRes variants
        case "prores": return "apcn" // Default to ProRes 422
        case "prores_ks": return "apcn"
        case "prores_aw": return "apcn"
        
        // DV variants
        case "dvvideo": return "dvc " // DV NTSC
        case "dvvideo_pal": return "dvcp" // DV PAL
        case "dvvideo_50": return "dv5p" // DV50 PAL
        case "dvvideo_50_ntsc": return "dv5n" // DV50 NTSC
        
        // XAVC
        case "xavc": return "xalg" // XAVC Long GOP
        
        // Image codecs
        case "mjpeg", "jpeg": return "jpeg"
        case "png": return "png "
        
        default: return nil
        }
    }
    
    /// Map FFmpeg audio codec name to FourCC code
    private func mapFFmpegAudioCodecToFourCC(_ ffmpegCodec: String) -> String? {
        switch ffmpegCodec.lowercased() {
        case "aac", "libfdk_aac": return "aac "
        case "ac3": return "ac-3"
        case "eac3", "eac-3": return "ec-3"
        case "dts": return "DTS "
        case "opus": return "opus"
        case "vorbis": return "XiVs"
        case "flac": return "fLaC"
        case "truehd": return "mlpa"
        case "mlp": return "mlp "
        case "mp3", "libmp3lame", "mp2": return ".mp3"
        case "mp1": return ".mp1"
        case "pcm_s16le", "pcm_s24le", "pcm_s32le", "pcm_s16be", "pcm_s24be", "pcm_s32be": return "twos"
        case "pcm_f32le", "pcm_f64le": return "twos" // Linear PCM
        case "alac": return "alac"
        default: return nil
        }
    }
    
    /// Map FFmpeg subtitle codec name to FourCC code
    private func mapFFmpegSubtitleCodecToFourCC(_ ffmpegCodec: String) -> String? {
        switch ffmpegCodec.lowercased() {
        case "srt", "subrip": return "text"
        case "webvtt": return "wvtt"
        case "ass", "ssa": return "SSA "
        case "dvd_subtitle", "vobsub": return "subp"
        case "hdmv_pgs_subtitle", "pgs": return "PGS "
        default: return nil
        }
    }
}

public struct TrackCodecInfo: Sendable {
    public enum TrackType: String, Sendable {
        case video
        case audio
        case subtitle
    }
    
    public let trackType: TrackType
    public let codec: String
    public let codecLongName: String?
    public let width: Int?
    public let height: Int?
    public let bitrate: Int?
    public let fourCC: String? // FourCC code for MP4 compatibility
    
    public init(trackType: TrackType, codec: String, codecLongName: String?, width: Int?, height: Int?, bitrate: Int?, fourCC: String? = nil) {
        self.trackType = trackType
        self.codec = codec
        self.codecLongName = codecLongName
        self.width = width
        self.height = height
        self.bitrate = bitrate
        self.fourCC = fourCC
        }
    }

public enum FFmpegCodecError: Error, Equatable {
    case ffmpegNotAvailable
    case detectionFailed(String)
}

