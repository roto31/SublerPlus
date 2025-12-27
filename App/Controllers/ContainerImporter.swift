import Foundation
import AVFoundation

public enum ContainerFormat: String, Sendable {
    case mp4
    case m4v
    case m4a
    case mov
    case mkv
    case unknown
}

public enum ContainerImportError: Error, Equatable {
    case unsupportedFormat
    case fileReadFailed
    case trackExtractionFailed
}

public final class ContainerImporter: @unchecked Sendable {
    
    /// Detect container format from file extension and/or file signature
    public static func detectFormat(url: URL) -> ContainerFormat {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "m4v", "m4a":
            return .mp4
        case "mov", "qt":
            return .mov
        case "mkv", "mka", "mks":
            return .mkv
        default:
            // Try to detect by file signature
            return detectFormatBySignature(url: url)
        }
    }
    
    /// Detect format by reading file signature (magic bytes)
    private static func detectFormatBySignature(url: URL) -> ContainerFormat {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return .unknown
        }
        defer { try? fileHandle.close() }
        
        guard let data = try? fileHandle.read(upToCount: 12) else {
            return .unknown
        }
        
        // MP4/MOV: ftyp atom at offset 4
        if data.count >= 8 {
            let ftyp = String(data: data[4..<8], encoding: .ascii) ?? ""
            if ftyp == "ftyp" {
                // Check brand
                if data.count >= 12 {
                    let brand = String(data: data[8..<12], encoding: .ascii) ?? ""
                    if brand.contains("qt") || brand.contains("moov") {
                        return .mov
                    }
                    if brand.contains("mp4") || brand.contains("isom") || brand.contains("M4V") {
                        return .mp4
                    }
                }
                return .mp4 // Default to MP4 for ftyp
            }
        }
        
        // MKV: starts with 0x1A 0x45 0xDF 0xA3
        if data.count >= 4 {
            let bytes = [UInt8](data[0..<4])
            if bytes == [0x1A, 0x45, 0xDF, 0xA3] {
                return .mkv
            }
        }
        
        return .unknown
    }
    
    /// Extract tracks from container using AVFoundation, with FFmpeg fallback for advanced codecs
    public static func extractTracks(from url: URL) async throws -> [MediaTrack] {
        let format = detectFormat(url: url)
        
        // Try FFmpeg detection first for advanced codecs
        if await FFmpegWrapper.isAvailable() {
            do {
                let detector = FFmpegCodecDetector()
                let codecInfos = try await detector.detectCodecs(at: url)
                if !codecInfos.isEmpty {
                    return try await convertCodecInfosToMediaTracks(codecInfos: codecInfos, url: url)
                }
            } catch {
                // Fall back to AVFoundation if FFmpeg fails
            }
        }
        
        switch format {
        case .mp4, .m4v, .m4a, .mov:
            return try await extractTracksAVFoundation(url: url)
        case .mkv:
            // AVFoundation has limited MKV support, try it first
            do {
                return try await extractTracksAVFoundation(url: url)
            } catch {
                // If AVFoundation fails, we'll need external library support
                throw ContainerImportError.unsupportedFormat
            }
        case .unknown:
            throw ContainerImportError.unsupportedFormat
        }
    }
    
    /// Extract tracks using AVFoundation (works for MP4, MOV, and some MKV)
    private static func extractTracksAVFoundation(url: URL) async throws -> [MediaTrack] {
        let asset = AVURLAsset(url: url)
        
        // Load tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let subtitleTracks = try await asset.loadTracks(withMediaType: .subtitle)
        
        var allTracks: [MediaTrack] = []
        
        // Process video tracks
        for track in videoTracks {
            let codec = extractCodec(from: track)
            let language = try? await track.load(.languageCode)
            let bitrate = try? await track.load(.estimatedDataRate)
            let isDefault = (try? await track.load(.isEnabled)) ?? false
            let resolution = try? await extractResolution(from: track)
            let hdr = detectHDR(from: track)
            
            allTracks.append(MediaTrack(
                kind: .video,
                codec: codec,
                language: language,
                bitrate: bitrate.map { Int($0) },
                isDefault: isDefault,
                isForced: false,
                resolution: resolution,
                hdr: hdr
            ))
        }
        
        // Process audio tracks
        for track in audioTracks {
            let codec = extractCodec(from: track)
            let language = try? await track.load(.languageCode)
            let bitrate = try? await track.load(.estimatedDataRate)
            let isDefault = (try? await track.load(.isEnabled)) ?? false
            let isForced = false // Audio tracks don't typically have forced flag
            
            allTracks.append(MediaTrack(
                kind: .audio,
                codec: codec,
                language: language,
                bitrate: bitrate.map { Int($0) },
                isDefault: isDefault,
                isForced: isForced,
                resolution: nil,
                hdr: false
            ))
        }
        
        // Process subtitle tracks
        for track in subtitleTracks {
            let codec = extractCodec(from: track)
            let language = try? await track.load(.languageCode)
            let isDefault = (try? await track.load(.isEnabled)) ?? false
            let isForced = detectForcedSubtitle(from: track)
            
            allTracks.append(MediaTrack(
                kind: .subtitle,
                codec: codec,
                language: language,
                bitrate: nil,
                isDefault: isDefault,
                isForced: isForced,
                resolution: nil,
                hdr: false
            ))
        }
        
        return allTracks
    }
    
    private static func extractCodec(from track: AVAssetTrack) -> String? {
        guard let formatDescriptions = track.formatDescriptions as? [CMFormatDescription] else {
            return nil
        }
        
        guard let firstDesc = formatDescriptions.first else {
            return nil
        }
        
        let mediaType = CMFormatDescriptionGetMediaType(firstDesc)
        let codecType = CMFormatDescriptionGetMediaSubType(firstDesc)
        
        switch mediaType {
        case kCMMediaType_Video:
            return fourCCToString(codecType)
        case kCMMediaType_Audio:
            return fourCCToString(codecType)
        case kCMMediaType_Subtitle:
            return fourCCToString(codecType)
        default:
            return nil
        }
    }
    
    private static func extractResolution(from track: AVAssetTrack) async -> String? {
        do {
            let naturalSize = try await track.load(.naturalSize)
            return "\(Int(naturalSize.width))x\(Int(naturalSize.height))"
        } catch {
            return nil
        }
    }
    
    private static func detectHDR(from track: AVAssetTrack) -> Bool {
        guard let formatDescriptions = track.formatDescriptions as? [CMFormatDescription],
              let firstDesc = formatDescriptions.first else {
            return false
        }
        
        let extensions = CMFormatDescriptionGetExtensions(firstDesc) as? [String: Any]
        
        // Check for HDR-related keys
        if let colorPrimaries = extensions?[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String {
            if colorPrimaries.contains("2020") || colorPrimaries.contains("P3") {
                return true
            }
        }
        
        if let transferFunction = extensions?[kCMFormatDescriptionExtension_TransferFunction as String] as? String {
            if transferFunction.contains("HLG") || transferFunction.contains("PQ") || transferFunction.contains("SMPTE_ST_2084") {
                return true
            }
        }
        
        return false
    }
    
    private static func detectForcedSubtitle(from track: AVAssetTrack) -> Bool {
        // Check track metadata for forced subtitle flag
        // This is typically in the track's metadata
        return false // Default to false, can be enhanced with actual metadata reading
    }
    
    private static func fourCCToString(_ fourCC: FourCharCode) -> String {
        let bytes = [
            UInt8((fourCC >> 24) & 0xFF),
            UInt8((fourCC >> 16) & 0xFF),
            UInt8((fourCC >> 8) & 0xFF),
            UInt8(fourCC & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "unknown"
    }
    
    /// Convert FFmpeg codec info to MediaTrack
    private static func convertCodecInfosToMediaTracks(codecInfos: [TrackCodecInfo], url: URL) async throws -> [MediaTrack] {
        var tracks: [MediaTrack] = []
        
        for info in codecInfos {
            let kind: MediaTrack.Kind
            switch info.trackType {
            case .video: kind = .video
            case .audio: kind = .audio
            case .subtitle: kind = .subtitle
            }
            
            let resolution: String? = {
                if let w = info.width, let h = info.height {
                    return "\(w)x\(h)"
                }
                return nil
            }()
            
            // Map FFmpeg codec names to standard names
            let codec = mapFFmpegCodecToStandard(info.codec)
            
            // Use FourCC if available, otherwise use standard codec name
            let displayCodec = info.fourCC ?? codec
            
            tracks.append(MediaTrack(
                kind: kind,
                codec: displayCodec,
                language: nil, // Language would need to be extracted separately
                bitrate: info.bitrate,
                isDefault: false,
                isForced: false,
                resolution: resolution,
                hdr: isHDRCodec(info.codec)
            ))
        }
        
        return tracks
    }
    
    /// Map FFmpeg codec names to standard codec identifiers
    private static func mapFFmpegCodecToStandard(_ ffmpegCodec: String) -> String {
        switch ffmpegCodec.lowercased() {
        // Video codecs
        case "h264", "libx264": return "h264"
        case "hevc", "h265", "libx265": return "hevc"
        case "av1", "libaom-av1": return "av1"
        case "vvc", "h266": return "vvc"
        case "vp8": return "vp8"
        case "vp9": return "vp9"
        case "mpeg1video": return "mpeg1"
        case "mpeg2video": return "mpeg2"
        case "mpeg4", "mpeg4video": return "mpeg4"
        case "theora": return "theora"
        case "prores", "prores_ks", "prores_aw": return "prores"
        case "dvvideo", "dvvideo_pal", "dvvideo_50", "dvvideo_50_ntsc": return "dv"
        case "xavc": return "xavc"
        case "mjpeg", "jpeg": return "jpeg"
        case "png": return "png"
        
        // Audio codecs
        case "aac", "libfdk_aac": return "aac"
        case "ac3": return "ac3"
        case "eac3", "eac-3": return "eac3"
        case "dts": return "dts"
        case "opus": return "opus"
        case "vorbis": return "vorbis"
        case "flac": return "flac"
        case "truehd": return "truehd"
        case "mlp": return "mlp"
        case "mp3", "libmp3lame": return "mp3"
        case "mp2": return "mp2"
        case "mp1": return "mp1"
        case "pcm_s16le", "pcm_s24le", "pcm_s32le", "pcm_s16be", "pcm_s24be", "pcm_s32be": return "pcm"
        case "pcm_f32le", "pcm_f64le": return "pcm"
        case "alac": return "alac"
        
        // Subtitle codecs
        case "srt", "subrip": return "srt"
        case "webvtt": return "webvtt"
        case "ass", "ssa": return "ass"
        case "dvd_subtitle", "vobsub": return "vobsub"
        case "hdmv_pgs_subtitle", "pgs": return "pgs"
        
        default: return ffmpegCodec
        }
    }
    
    /// Check if codec is HDR-capable
    private static func isHDRCodec(_ codec: String) -> Bool {
        let hdrCodecs = ["hevc", "h265", "av1", "vp9"]
        return hdrCodecs.contains(codec.lowercased())
    }
}

