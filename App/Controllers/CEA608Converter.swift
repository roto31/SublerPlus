import Foundation
import CoreMedia

/// Converter for CEA-608 closed captions
public final class CEA608Converter: @unchecked Sendable {
    
    public init() {}
    
    /// Convert CEA-608 SCC file to TX3G samples
    public func convertSCC(
        from url: URL,
        frameRate: Double = 29.97
    ) async throws -> [TX3GSample] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw CEA608Error.invalidFile
        }
        
        var samples: [TX3GSample] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // SCC format: HH:MM:SS:FF   [command codes]
            // Example: 00:00:01:00   9420 9420
            let parts = trimmed.components(separatedBy: .whitespaces)
            guard parts.count >= 2 else { continue }
            
            let timeStr = parts[0]
            guard let time = parseSCCTime(timeStr, frameRate: frameRate) else { continue }
            
            // Extract command codes
            let commandCodes = Array(parts.dropFirst())
            
            // Decode CEA-608 commands to text
            let text = decodeCEA608Commands(commandCodes)
            
            if !text.isEmpty {
                // Default duration for CEA-608 captions (typically 2-4 seconds)
                let duration = CMTime(seconds: 2.0, preferredTimescale: 600)
                samples.append(TX3GSample(startTime: time, duration: duration, text: text))
            }
        }
        
        return samples.sorted { $0.startTime.seconds < $1.startTime.seconds }
    }
    
    /// Parse SCC time format (HH:MM:SS:FF where FF is frames)
    private func parseSCCTime(_ timeStr: String, frameRate: Double) -> CMTime? {
        let components = timeStr.components(separatedBy: ":")
        guard components.count == 4 else { return nil }
        
        guard let hours = Int(components[0]),
              let minutes = Int(components[1]),
              let seconds = Int(components[2]),
              let frames = Int(components[3]) else {
            return nil
        }
        
        let frameDuration = 1.0 / frameRate
        let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds) + Double(frames) * frameDuration
        
        return CMTime(seconds: totalSeconds, preferredTimescale: 600)
    }
    
    /// Decode CEA-608 command codes to text (simplified)
    /// Full implementation would decode the complete CEA-608 character set and control codes
    private func decodeCEA608Commands(_ codes: [String]) -> String {
        // CEA-608 uses 2-byte command codes
        // This is a placeholder - full implementation would:
        // 1. Parse hex codes
        // 2. Decode character set (Basic, Extended, Special)
        // 3. Handle control codes (positioning, colors, etc.)
        // 4. Convert to plain text
        
        // For now, return placeholder text indicating caption presence
        // Full decoder would require extensive CEA-608 specification implementation
        return codes.joined(separator: " ")
    }
    
    /// Extract CEA-608 from video stream using FFmpeg
    public func extractFromVideo(
        videoURL: URL,
        streamIndex: Int = 0
    ) async throws -> [TX3GSample] {
        guard await FFmpegWrapper.isAvailable() else {
            throw CEA608Error.ffmpegNotAvailable
        }
        
        // Use FFmpeg to extract CEA-608 closed captions
        // ffmpeg -i input.mp4 -map 0:s:0 -c:s srt output.srt
        let tempSRT = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).srt")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = [
            "-i", videoURL.path,
            "-map", "0:s:\(streamIndex)", // Subtitle stream
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
            throw CEA608Error.extractionFailed
        }
        
        // Parse extracted SRT
        let data = try Data(contentsOf: tempSRT)
        let samples = try TX3GEncoder.parseSRT(data)
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempSRT)
        
        return samples
    }
}

public enum CEA608Error: Error, Equatable {
    case invalidFile
    case extractionFailed
    case ffmpegNotAvailable
    case decodeFailed
}

