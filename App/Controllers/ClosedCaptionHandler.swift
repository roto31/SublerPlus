import Foundation
import CoreMedia

/// Handler for closed caption formats (CEA-608, CEA-708, ATSC)
public final class ClosedCaptionHandler: @unchecked Sendable {
    
    public enum CaptionFormat: String, Sendable {
        case cea608 = "cea608"
        case cea708 = "cea708"
        case atsc = "atsc"
        case fairPlayCEA608 = "fairplay_cea608" // FairPlay-encrypted CEA-608
        case unknown
    }
    
    private let fairPlayHandler = FairPlayCCHandler()
    
    public init() {}
    
    /// Check if closed caption codec is FairPlay-encrypted
    public func isFairPlayCC(codec: String) -> Bool {
        return fairPlayHandler.isFairPlayCC(codec: codec)
    }
    
    /// Detect closed caption format from file
    public func detectFormat(at url: URL) -> CaptionFormat {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "scc":
            return .cea608 // Scenarist Closed Caption
        case "mcc":
            return .cea608 // MacCaption
        case "ts", "m2ts", "mts":
            return .atsc // ATSC transport stream
        case "srt":
            // Could be CEA-608 converted to SRT
            return .unknown
        default:
            return .unknown
        }
    }
    
    /// Detect closed caption format from codec string
    public func detectFormat(codec: String) -> CaptionFormat {
        if isFairPlayCC(codec: codec) {
            return .fairPlayCEA608
        }
        
        switch codec.lowercased() {
        case "c608", "cea608": return .cea608
        case "c708", "cea708": return .cea708
        case "atcc", "atsc": return .atsc
        default: return .unknown
        }
    }
    
    /// Convert closed captions to TX3G samples
    public func convertToTX3G(
        from url: URL,
        format: CaptionFormat? = nil
    ) async throws -> [TX3GSample] {
        let detectedFormat = format ?? detectFormat(at: url)
        
        switch detectedFormat {
        case .cea608:
            return try await convertCEA608(from: url)
        case .cea708:
            return try await convertCEA708(from: url)
        case .atsc:
            return try await convertATSC(from: url)
        case .fairPlayCEA608:
            throw ClosedCaptionError.fairPlayEncrypted("FairPlay-encrypted closed captions cannot be converted. Passthrough only.")
        case .unknown:
            throw ClosedCaptionError.unsupportedFormat
        }
    }
    
    /// Convert CEA-608 (SCC format) to TX3G samples
    private func convertCEA608(from url: URL) async throws -> [TX3GSample] {
        let converter = CEA608Converter()
        return try await converter.convertSCC(from: url)
    }
    
    /// Convert CEA-708 to TX3G samples
    private func convertCEA708(from url: URL) async throws -> [TX3GSample] {
        // CEA-708 is typically embedded in video streams
        // Use CEA708Converter to extract from video
        let converter = CEA708Converter()
        return try await converter.convertFromVideo(videoURL: url)
    }
    
    /// Convert ATSC captions to TX3G samples
    private func convertATSC(from url: URL) async throws -> [TX3GSample] {
        // ATSC captions are typically embedded in MPEG transport streams (TS/M2TS files)
        // Use FFmpeg to extract ATSC closed captions from transport stream
        
        guard await FFmpegWrapper.isAvailable() else {
            throw ClosedCaptionError.ffmpegNotAvailable
        }
        
        // Check if file is a transport stream
        let ext = url.pathExtension.lowercased()
        guard ext == "ts" || ext == "m2ts" || ext == "mts" else {
            // Try to extract from video file if it contains ATSC captions
            return try await extractATSCFromVideo(videoURL: url)
        }
        
        // Extract ATSC captions from TS file
        let tempSRT = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).srt")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = [
            "-i", url.path,
            "-map", "0:s?", // Subtitle/CC streams
            "-c:s", "srt",
            "-y", // Overwrite
            tempSRT.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            // Try alternative extraction method
            return try await extractATSCAlternative(url: url)
        }
        
        // Parse extracted SRT
        let data = try Data(contentsOf: tempSRT)
        let samples = try TX3GEncoder.parseSRT(data)
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempSRT)
        
        return samples
    }
    
    /// Extract ATSC captions from video file (if embedded)
    private func extractATSCFromVideo(videoURL: URL) async throws -> [TX3GSample] {
        guard await FFmpegWrapper.isAvailable() else {
            throw ClosedCaptionError.ffmpegNotAvailable
        }
        
        // Use FFmpeg to extract ATSC captions from video
        let tempSRT = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).srt")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = [
            "-i", videoURL.path,
            "-map", "0:s?", // Subtitle/CC streams
            "-c:s", "srt",
            "-y", // Overwrite
            tempSRT.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ClosedCaptionError.extractionFailed
        }
        
        // Parse extracted SRT
        let data = try Data(contentsOf: tempSRT)
        let samples = try TX3GEncoder.parseSRT(data)
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempSRT)
        
        return samples
    }
    
    /// Alternative ATSC extraction method
    private func extractATSCAlternative(url: URL) async throws -> [TX3GSample] {
        // Try using ffmpeg with specific ATSC stream selection
        let tempSRT = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).srt")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = [
            "-i", url.path,
            "-codec:s", "srt",
            "-f", "srt",
            "-y", // Overwrite
            tempSRT.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ClosedCaptionError.extractionFailed
        }
        
        // Parse extracted SRT
        let data = try Data(contentsOf: tempSRT)
        let samples = try TX3GEncoder.parseSRT(data)
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempSRT)
        
        return samples
    }
    
    /// Extract closed captions from video file using FFmpeg
    public func extractFromVideo(
        videoURL: URL,
        format: CaptionFormat = .cea608
    ) async throws -> [TX3GSample] {
        guard await FFmpegWrapper.isAvailable() else {
            throw ClosedCaptionError.ffmpegNotAvailable
        }
        
        // Use FFmpeg to extract closed captions
        // ffmpeg -i input.mp4 -map 0:s:0 -c:s srt output.srt
        let tempSRT = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).srt")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = [
            "-i", videoURL.path,
            "-map", "0:s:0", // First subtitle stream
            "-c:s", "srt",
            "-y", // Overwrite
            tempSRT.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ClosedCaptionError.extractionFailed
        }
        
        // Parse extracted SRT
        let data = try Data(contentsOf: tempSRT)
        let samples = try TX3GEncoder.parseSRT(data)
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempSRT)
        
        return samples
    }
}

public enum ClosedCaptionError: Error, Equatable {
    case unsupportedFormat
    case invalidFile
    case extractionFailed
    case ffmpegNotAvailable
    case fairPlayEncrypted(String)
    case notImplemented(String)
}

