import Foundation
import CoreMedia

/// OCR-based conversion for bitmap subtitle formats (PGS, VobSub)
public final class SubtitleOCR: @unchecked Sendable {
    
    public enum OCRMethod: String, Sendable {
        case tesseract
        case ffmpeg
        case auto // Try FFmpeg first, fallback to Tesseract
    }
    
    public init() {}
    
    /// Convert bitmap subtitle to TX3G samples using OCR
    public func convertBitmapSubtitle(
        from url: URL,
        method: OCRMethod = .auto,
        language: String = "eng"
    ) async throws -> [TX3GSample] {
        // Detect subtitle format
        let format = detectFormat(at: url)
        
        switch format {
        case .pgs:
            return try await convertPGS(from: url, method: method, language: language)
        case .vobsub:
            return try await convertVobSub(from: url, method: method, language: language)
        case .unknown:
            throw SubtitleOCRError.unsupportedFormat
        }
    }
    
    /// Detect bitmap subtitle format
    private func detectFormat(at url: URL) -> BitmapSubtitleFormat {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "sup", "pgs":
            return .pgs // PGS (Presentation Graphic Stream)
        case "idx":
            // VobSub uses .idx + .sub pair
            return .vobsub
        case "sub":
            // Check if corresponding .idx exists
            let idxURL = url.deletingPathExtension().appendingPathExtension("idx")
            if FileManager.default.fileExists(atPath: idxURL.path) {
                return .vobsub
            }
            return .unknown
        default:
            return .unknown
        }
    }
    
    /// Convert PGS subtitle using OCR
    private func convertPGS(
        from url: URL,
        method: OCRMethod,
        language: String
    ) async throws -> [TX3GSample] {
        // PGS is a bitmap format embedded in video streams or as .sup files
        // We'll use FFmpeg to extract frames and OCR them
        
        switch method {
        case .ffmpeg, .auto:
            if await FFmpegWrapper.isAvailable() {
                return try await convertPGSWithFFmpeg(from: url, language: language)
            }
            if method == .auto {
                // Fallback to Tesseract
                return try await convertPGSWithTesseract(from: url, language: language)
            }
            throw SubtitleOCRError.ffmpegNotAvailable
            
        case .tesseract:
            return try await convertPGSWithTesseract(from: url, language: language)
        }
    }
    
    /// Convert VobSub subtitle using OCR
    private func convertVobSub(
        from url: URL,
        method: OCRMethod,
        language: String
    ) async throws -> [TX3GSample] {
        // VobSub uses .idx (index) + .sub (bitmap data) pair
        let idxURL: URL
        let subURL: URL
        
        if url.pathExtension.lowercased() == "idx" {
            idxURL = url
            subURL = url.deletingPathExtension().appendingPathExtension("sub")
        } else {
            subURL = url
            idxURL = url.deletingPathExtension().appendingPathExtension("idx")
        }
        
        guard FileManager.default.fileExists(atPath: idxURL.path),
              FileManager.default.fileExists(atPath: subURL.path) else {
            throw SubtitleOCRError.missingFiles
        }
        
        // Parse .idx file to get timing information
        let timingInfo = try await parseVobSubIndex(idxURL)
        
        switch method {
        case .ffmpeg, .auto:
            if await FFmpegWrapper.isAvailable() {
                return try await convertVobSubWithFFmpeg(idxURL: idxURL, subURL: subURL, timingInfo: timingInfo, language: language)
            }
            if method == .auto {
                return try await convertVobSubWithTesseract(idxURL: idxURL, subURL: subURL, timingInfo: timingInfo, language: language)
            }
            throw SubtitleOCRError.ffmpegNotAvailable
            
        case .tesseract:
            return try await convertVobSubWithTesseract(idxURL: idxURL, subURL: subURL, timingInfo: timingInfo, language: language)
        }
    }
    
    /// Convert PGS using FFmpeg's built-in OCR
    private func convertPGSWithFFmpeg(from url: URL, language: String) async throws -> [TX3GSample] {
        // FFmpeg can extract PGS subtitles and convert to SRT
        let tempSRT = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).srt")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = [
            "-i", url.path,
            "-map", "0:s:0", // First subtitle stream
            "-c:s", "srt",
            "-y",
            tempSRT.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "FFmpeg conversion failed"
            throw SubtitleOCRError.conversionFailed(errorMsg)
        }
        
        // Parse extracted SRT
        let data = try Data(contentsOf: tempSRT)
        let samples = try TX3GEncoder.parseSRT(data)
        
        try? FileManager.default.removeItem(at: tempSRT)
        
        return samples
    }
    
    /// Convert PGS using Tesseract OCR
    private func convertPGSWithTesseract(from url: URL, language: String) async throws -> [TX3GSample] {
        // Check if Tesseract is available
        guard await DependencyChecker.shared.checkDependency(
            DependencyChecker.allDependencies.first(where: { $0.id == "tesseract" })!
        ).status == .installed else {
            throw SubtitleOCRError.tesseractNotAvailable
        }
        
        // Extract frames from PGS using FFmpeg (if available) or parse directly
        // Then OCR each frame with Tesseract
        // This is a simplified implementation - full version would:
        // 1. Extract bitmap frames from PGS
        // 2. OCR each frame with Tesseract
        // 3. Combine OCR results with timing info
        
        throw SubtitleOCRError.notImplemented("Tesseract OCR for PGS not yet fully implemented")
    }
    
    /// Convert VobSub using FFmpeg
    private func convertVobSubWithFFmpeg(
        idxURL: URL,
        subURL: URL,
        timingInfo: [VobSubTiming],
        language: String
    ) async throws -> [TX3GSample] {
        // FFmpeg can handle VobSub conversion
        // Create a temporary video file with embedded VobSub for FFmpeg to process
        let tempSRT = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).srt")
        
        // Use FFmpeg to convert VobSub to SRT
        // Note: This requires the VobSub to be embedded in a video or container
        // For standalone .idx/.sub files, we'd need to create a minimal container
        
        throw SubtitleOCRError.notImplemented("Standalone VobSub conversion requires container creation")
    }
    
    /// Convert VobSub using Tesseract OCR
    private func convertVobSubWithTesseract(
        idxURL: URL,
        subURL: URL,
        timingInfo: [VobSubTiming],
        language: String
    ) async throws -> [TX3GSample] {
        guard await DependencyChecker.shared.checkDependency(
            DependencyChecker.allDependencies.first(where: { $0.id == "tesseract" })! 
        ).status == .installed else {
            throw SubtitleOCRError.tesseractNotAvailable
        }
        
        // Read .sub file and extract bitmap frames
        // OCR each frame with Tesseract
        // Match OCR results with timing info from .idx
        
        throw SubtitleOCRError.notImplemented("Tesseract OCR for VobSub not yet fully implemented")
    }
    
    /// Parse VobSub .idx file to extract timing information
    private func parseVobSubIndex(_ idxURL: URL) async throws -> [VobSubTiming] {
        guard let content = try? String(contentsOf: idxURL, encoding: .utf8) else {
            throw SubtitleOCRError.invalidFile
        }
        
        var timings: [VobSubTiming] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentTime: CMTime?
        var currentDuration: CMTime?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // VobSub index format: timestamp: filepos, filepos
            // Example: timestamp: 00:00:01:000, filepos: 000000000
            if trimmed.hasPrefix("timestamp:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    let timeStr = parts[1].components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
                    currentTime = parseVobSubTime(timeStr)
                }
            } else if trimmed.hasPrefix("duration:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    let durationStr = parts[1].trimmingCharacters(in: .whitespaces)
                    currentDuration = parseVobSubTime(durationStr)
                }
            }
            
            if let time = currentTime, let duration = currentDuration {
                timings.append(VobSubTiming(startTime: time, duration: duration))
                currentTime = nil
                currentDuration = nil
            }
        }
        
        return timings
    }
    
    /// Parse VobSub time format (HH:MM:SS:mmm)
    private func parseVobSubTime(_ timeStr: String) -> CMTime? {
        let components = timeStr.components(separatedBy: ":")
        guard components.count == 4 else { return nil }
        
        guard let hours = Int(components[0]),
              let minutes = Int(components[1]),
              let seconds = Int(components[2]),
              let milliseconds = Int(components[3]) else {
            return nil
        }
        
        let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds) + Double(milliseconds) / 1000.0
        return CMTime(seconds: totalSeconds, preferredTimescale: 600)
    }
}

private enum BitmapSubtitleFormat {
    case pgs
    case vobsub
    case unknown
}

private struct VobSubTiming {
    let startTime: CMTime
    let duration: CMTime
}

public enum SubtitleOCRError: Error, Equatable {
    case unsupportedFormat
    case missingFiles
    case invalidFile
    case ffmpegNotAvailable
    case tesseractNotAvailable
    case conversionFailed(String)
    case notImplemented(String)
}

