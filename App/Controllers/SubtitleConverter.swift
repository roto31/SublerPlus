import Foundation
import CoreMedia

/// Converts various subtitle formats to TX3G-compatible samples
public enum SubtitleConverter {
    
    /// Convert subtitle file to TX3G samples
    public static func convertToTX3GSamples(
        from url: URL,
        language: String = "eng"
    ) async throws -> [TX3GSample] {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "srt":
            let data = try Data(contentsOf: url)
            return try TX3GEncoder.parseSRT(data)
            
        case "vtt", "webvtt":
            let data = try Data(contentsOf: url)
            return try TX3GEncoder.parseWebVTT(data)
            
        case "ass", "ssa":
            let data = try Data(contentsOf: url)
            return try parseASS(data)
            
        default:
            throw SubtitleConversionError.unsupportedFormat(ext)
        }
    }
    
    /// Parse ASS/SSA subtitle format
    private static func parseASS(_ data: Data) throws -> [TX3GSample] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw SubtitleConversionError.invalidEncoding
        }
        
        var samples: [TX3GSample] = []
        let lines = content.components(separatedBy: .newlines)
        
        // Find [Events] section
        var inEventsSection = false
        var formatLine: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "[Events]" {
                inEventsSection = true
                continue
            }
            
            if inEventsSection {
                if trimmed.hasPrefix("Format:") {
                    formatLine = trimmed
                    continue
                }
                
                if trimmed.hasPrefix("Dialogue:") || trimmed.hasPrefix("Comment:") {
                    if let sample = parseASSDialogue(trimmed, formatLine: formatLine) {
                        samples.append(sample)
                    }
                }
                
                // Stop at next section
                if trimmed.hasPrefix("[") && trimmed != "[Events]" {
                    break
                }
            }
        }
        
        return samples.sorted { $0.startTime.seconds < $1.startTime.seconds }
    }
    
    /// Parse ASS/SSA dialogue line
    private static func parseASSDialogue(_ line: String, formatLine: String?) -> TX3GSample? {
        // ASS format: Dialogue: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        // SSA format: Dialogue: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        
        let parts = line.components(separatedBy: ",")
        guard parts.count >= 10 else { return nil }
        
        // Extract start and end times (indices depend on format)
        // For ASS: Start is index 1, End is index 2
        // For SSA: Start is index 1, End is index 2 (same)
        let startTimeStr = parts[1].trimmingCharacters(in: .whitespaces)
        let endTimeStr = parts[2].trimmingCharacters(in: .whitespaces)
        
        // ASS/SSA time format: H:MM:SS.cc (centiseconds) or H:MM:SS.mmm (milliseconds)
        guard let startTime = parseASSTime(startTimeStr),
              let endTime = parseASSTime(endTimeStr) else {
            return nil
        }
        
        // Extract text (everything after the 9th comma)
        let textParts = parts.dropFirst(9)
        var text = textParts.joined(separator: ",").trimmingCharacters(in: .whitespaces)
        
        // Remove ASS/SSA formatting tags
        text = removeASSFormatting(text)
        
        guard !text.isEmpty else { return nil }
        
        let duration = CMTimeSubtract(endTime, startTime)
        return TX3GSample(startTime: startTime, duration: duration, text: text)
    }
    
    /// Parse ASS/SSA time format (H:MM:SS.cc or H:MM:SS.mmm)
    private static func parseASSTime(_ timeStr: String) -> CMTime? {
        // Format: H:MM:SS.cc or H:MM:SS.mmm
        let components = timeStr.components(separatedBy: ":")
        guard components.count == 3 else { return nil }
        
        guard let hours = Int(components[0]),
              let minutes = Int(components[1]) else {
            return nil
        }
        
        let secondsParts = components[2].components(separatedBy: ".")
        guard let seconds = Int(secondsParts[0]) else { return nil }
        
        // Handle centiseconds or milliseconds
        let fractional: Double
        if secondsParts.count > 1, let frac = Int(secondsParts[1]) {
            // Determine if centiseconds (2 digits) or milliseconds (3 digits)
            if secondsParts[1].count == 2 {
                fractional = Double(frac) / 100.0 // Centiseconds
            } else {
                fractional = Double(frac) / 1000.0 // Milliseconds
            }
        } else {
            fractional = 0.0
        }
        
        let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds) + fractional
        return CMTime(seconds: totalSeconds, preferredTimescale: 600)
    }
    
    /// Remove ASS/SSA formatting tags from text
    private static func removeASSFormatting(_ text: String) -> String {
        var cleaned = text
        
        // Remove ASS override tags: {\...}
        let overrideRegex = try! NSRegularExpression(pattern: #"\{[^}]*\}"#, options: [])
        cleaned = overrideRegex.stringByReplacingMatches(
            in: cleaned,
            options: [],
            range: NSRange(location: 0, length: cleaned.utf16.count),
            withTemplate: ""
        )
        
        // Remove common ASS tags: \N (newline), \n (newline), \h (hard space)
        cleaned = cleaned.replacingOccurrences(of: "\\N", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\\h", with: " ")
        
        // Remove other common tags
        cleaned = cleaned.replacingOccurrences(of: "\\r", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\\t", with: " ")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum SubtitleConversionError: Error, Equatable {
    case unsupportedFormat(String)
    case invalidEncoding
    case parseFailed(String)
}

