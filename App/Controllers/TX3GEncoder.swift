import Foundation
import AVFoundation
import CoreMedia

public enum TX3GError: Error, Equatable {
    case invalidInput
    case parseFailed
    case encodingFailed
}

public struct TX3GSample: Sendable {
    public let startTime: CMTime
    public let duration: CMTime
    public let text: String
    
    public init(startTime: CMTime, duration: CMTime, text: String) {
        self.startTime = startTime
        self.duration = duration
        self.text = text
    }
}

public final class TX3GEncoder: @unchecked Sendable {
    
    /// Convert subtitle file to TX3G samples (supports SRT, WebVTT, ASS, SSA)
    public static func parseSubtitle(from url: URL) async throws -> [TX3GSample] {
        return try await SubtitleConverter.convertToTX3GSamples(from: url)
    }
    
    /// Convert SRT data to TX3G samples
    public static func parseSRT(_ data: Data) throws -> [TX3GSample] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw TX3GError.invalidInput
        }
        
        var samples: [TX3GSample] = []
        let blocks = content.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n\n")
        
        let timeRegex = try NSRegularExpression(pattern: #"(\d{2}):(\d{2}):(\d{2}),(\d{3}) --> (\d{2}):(\d{2}):(\d{2}),(\d{3})"#)
        
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
            guard lines.count >= 2 else { continue }
            
            // Skip index line if present
            var timeLineIndex = 0
            if Int(lines[0]) != nil {
                timeLineIndex = 1
            }
            
            guard timeLineIndex < lines.count else { continue }
            let timeLine = lines[timeLineIndex]
            
            // Parse time range
            guard let match = timeRegex.firstMatch(in: timeLine, range: NSRange(location: 0, length: timeLine.utf16.count)) else {
                continue
            }
            
            func extractInt(from range: NSRange) -> Int {
                guard let swiftRange = Range(range, in: timeLine) else { return 0 }
                return Int(String(timeLine[swiftRange])) ?? 0
            }
            
            let startTime = parseTime(
                hours: extractInt(from: match.range(at: 1)),
                minutes: extractInt(from: match.range(at: 2)),
                seconds: extractInt(from: match.range(at: 3)),
                milliseconds: extractInt(from: match.range(at: 4))
            )
            
            let endTime = parseTime(
                hours: extractInt(from: match.range(at: 5)),
                minutes: extractInt(from: match.range(at: 6)),
                seconds: extractInt(from: match.range(at: 7)),
                milliseconds: extractInt(from: match.range(at: 8))
            )
            
            let duration = CMTimeSubtract(endTime, startTime)
            
            // Extract subtitle text (remaining lines)
            let textLines = lines[(timeLineIndex + 1)...]
            let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !text.isEmpty {
                samples.append(TX3GSample(startTime: startTime, duration: duration, text: text))
            }
        }
        
        return samples
    }
    
    /// Convert WebVTT data to TX3G samples
    public static func parseWebVTT(_ data: Data) throws -> [TX3GSample] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw TX3GError.invalidInput
        }
        
        var samples: [TX3GSample] = []
        let lines = content.components(separatedBy: .newlines)
        
        let timeRegex = try NSRegularExpression(pattern: #"(\d{2}):(\d{2}):(\d{2})\.(\d{3}) --> (\d{2}):(\d{2}):(\d{2})\.(\d{3})"#)
        
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Skip WEBVTT header and empty lines
            if line.isEmpty || line == "WEBVTT" || line.hasPrefix("NOTE") || line.hasPrefix("STYLE") {
                i += 1
                continue
            }
            
            // Check for time range
            if let match = timeRegex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
                func extractInt(from range: NSRange) -> Int {
                    guard let swiftRange = Range(range, in: line) else { return 0 }
                    return Int(String(line[swiftRange])) ?? 0
                }
                
                let startTime = parseTime(
                    hours: extractInt(from: match.range(at: 1)),
                    minutes: extractInt(from: match.range(at: 2)),
                    seconds: extractInt(from: match.range(at: 3)),
                    milliseconds: extractInt(from: match.range(at: 4))
                )
                
                let endTime = parseTime(
                    hours: extractInt(from: match.range(at: 5)),
                    minutes: extractInt(from: match.range(at: 6)),
                    seconds: extractInt(from: match.range(at: 7)),
                    milliseconds: extractInt(from: match.range(at: 8))
                )
                
                let duration = CMTimeSubtract(endTime, startTime)
                
                // Collect text lines until empty line or next time range
                var textLines: [String] = []
                i += 1
                while i < lines.count {
                    let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextLine.isEmpty || timeRegex.firstMatch(in: nextLine, range: NSRange(location: 0, length: nextLine.utf16.count)) != nil {
                        break
                    }
                    // Remove WebVTT cue settings if present
                    let text = nextLine.components(separatedBy: " ").filter { !$0.contains(":") || !$0.contains("align") && !$0.contains("position") && !$0.contains("line") }.joined(separator: " ")
                    if !text.isEmpty {
                        textLines.append(text)
                    }
                    i += 1
                }
                
                let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    samples.append(TX3GSample(startTime: startTime, duration: duration, text: text))
                }
            } else {
                i += 1
            }
        }
        
        return samples
    }
    
    private static func parseTime(hours: Int, minutes: Int, seconds: Int, milliseconds: Int) -> CMTime {
        let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds) + Double(milliseconds) / 1000.0
        return CMTime(seconds: totalSeconds, preferredTimescale: 600)
    }
    
    /// Create TX3G track data for embedding in MP4
    public static func createTX3GTrack(
        samples: [TX3GSample],
        language: String = "eng",
        timescale: Int32 = 600
    ) -> Data {
        // TX3G track creation requires low-level MP4 atom manipulation
        // This is a simplified version - full implementation would create proper MP4 atoms
        // For now, return placeholder data structure
        // Full implementation would be integrated with AtomCodec
        
        var trackData = Data()
        
        // In a full implementation, this would create:
        // - tkhd atom (track header)
        // - mdia atom (media)
        //   - mdhd atom (media header)
        //   - hdlr atom (handler, type 'text')
        //   - minf atom (media information)
        //     - nmhd atom (null media header for text)
        //     - dinf atom (data information)
        //     - stbl atom (sample table)
        //       - stsd atom (sample description) with tx3g entry
        //       - stts atom (time-to-sample)
        //       - stsc atom (sample-to-chunk)
        //       - stsz atom (sample size)
        //       - stco atom (chunk offset)
        
        return trackData
    }
}

