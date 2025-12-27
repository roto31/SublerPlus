import Foundation
import AVFoundation
import CoreMedia

/// Handles timecode track extraction and creation
public final class TimecodeHandler: @unchecked Sendable {
    
    public enum TimecodeFormat: String, Sendable {
        case timeCode32 = "tmcd"  // Standard 32-bit timecode
        case timeCode64 = "tc64"  // 64-bit timecode
        case counter32 = "cn32"   // 32-bit counter
        case counter64 = "cn64"   // 64-bit counter
    }
    
    public struct TimecodeInfo: Sendable {
        public let format: TimecodeFormat
        public let frameRate: Double
        public let dropFrame: Bool
        public let startTimecode: String? // HH:MM:SS:FF format
        public let timescale: Int32
        
        public init(format: TimecodeFormat = .timeCode32, frameRate: Double, dropFrame: Bool, startTimecode: String? = nil, timescale: Int32 = 600) {
            self.format = format
            self.frameRate = frameRate
            self.dropFrame = dropFrame
            self.startTimecode = startTimecode
            self.timescale = timescale
        }
    }
    
    public init() {}
    
    /// Extract timecode tracks from asset
    public func extractTimecodeTracks(from asset: AVAsset) async throws -> [TimecodeInfo] {
        var timecodes: [TimecodeInfo] = []
        
        let tracks = try await asset.load(.tracks)
        for track in tracks {
            if track.mediaType == .timecode {
                if let info = try await extractTimecode(from: track) {
                    timecodes.append(info)
                }
            }
        }
        
        return timecodes
    }
    
    /// Extract timecode information from timecode track
    public func extractTimecode(from track: AVAssetTrack) async throws -> TimecodeInfo? {
        guard track.mediaType == .timecode else { return nil }
        
        // Get format descriptions
        guard let formatDescriptions = track.formatDescriptions as? [CMFormatDescription] else {
            return nil
        }
        
        var format: TimecodeFormat = .timeCode32
        var frameRate: Double = 29.97
        var dropFrame: Bool = false
        var startTimecode: String? = nil
        let timescale = try? await track.load(.naturalTimeScale)
        
        // Check format description for timecode format
        for formatDesc in formatDescriptions {
            let fourCC = CMFormatDescriptionGetMediaSubType(formatDesc)
            let fourCCString = String(bytes: [
                UInt8((fourCC >> 24) & 0xFF),
                UInt8((fourCC >> 16) & 0xFF),
                UInt8((fourCC >> 8) & 0xFF),
                UInt8(fourCC & 0xFF)
            ], encoding: .ascii) ?? ""
            
            switch fourCCString {
            case "tmcd": format = .timeCode32
            case "tc64": format = .timeCode64
            case "cn32": format = .counter32
            case "cn64": format = .counter64
            default: break
            }
            
            // Check for timecode in format description extensions
            let extensions = CMFormatDescriptionGetExtensions(formatDesc) as? [String: Any]
            if let timecodeData = extensions?["timecode" as String] as? Data {
                if let parsed = parseTimecodeData(timecodeData) {
                    frameRate = parsed.frameRate
                    dropFrame = parsed.dropFrame
                    startTimecode = parsed.startTimecode
                }
            }
        }
        
        // Try to infer from frame rate if not found
        if let rate = try? await track.load(.nominalFrameRate), rate > 0 {
            frameRate = Double(rate)
            dropFrame = isDropFrame(rate: rate)
        }
        
        return TimecodeInfo(
            format: format,
            frameRate: frameRate,
            dropFrame: dropFrame,
            startTimecode: startTimecode,
            timescale: timescale ?? 600
        )
    }
    
    /// Create timecode track in MP4
    public func createTimecodeTrack(
        in composition: AVMutableComposition,
        timecodeInfo: TimecodeInfo,
        duration: CMTime
    ) throws -> AVMutableCompositionTrack? {
        // Create timecode track
        guard let timecodeTrack = composition.addMutableTrack(
            withMediaType: .timecode,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return nil
        }
        
        // Set track properties
        timecodeTrack.preferredTransform = CGAffineTransform.identity
        timecodeTrack.preferredVolume = 1.0
        
        // Note: AVFoundation has limited support for timecode tracks
        // Full implementation would require:
        // 1. Creating proper timecode samples with correct format (tmcd/tc64/cn32/cn64)
        // 2. Low-level MP4 atom manipulation via AtomCodec
        // 3. Proper sample timing based on frame rate and drop frame flag
        
        return timecodeTrack
    }
    
    /// Parse timecode data from format description or sample buffer
    private func parseTimecodeData(_ data: Data) -> (frameRate: Double, dropFrame: Bool, startTimecode: String?)? {
        // Timecode data format: typically 4-8 bytes
        // Format varies by codec (tmcd, tc64, etc.)
        guard data.count >= 4 else { return nil }
        
        // Extract frame rate and flags (simplified)
        // Real implementation would parse based on format
        let frameRate = 29.97 // Default, would parse from data
        let dropFrame = (data[0] & 0x01) != 0
        
        // Parse start timecode if available (HH:MM:SS:FF format)
        var startTimecode: String? = nil
        if data.count >= 8 {
            // Simplified parsing - real implementation would decode properly
            startTimecode = "00:00:00:00"
        }
        
        return (frameRate, dropFrame, startTimecode)
    }
    
    /// Determine if frame rate uses drop frame
    private func isDropFrame(rate: Float) -> Bool {
        // 29.97 and 59.94 fps typically use drop frame
        return abs(rate - 29.97) < 0.01 || abs(rate - 59.94) < 0.01
    }
    
    /// Convert timecode string to sample data
    public func timecodeStringToData(_ timecode: String, format: TimecodeFormat, frameRate: Double, dropFrame: Bool) -> Data? {
        // Parse HH:MM:SS:FF format
        let components = timecode.split(separator: ":")
        guard components.count == 4,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              let seconds = Int(components[2]),
              let frames = Int(components[3]) else {
            return nil
        }
        
        // Convert to timecode sample data based on format
        // This is a simplified implementation
        var data = Data()
        
        switch format {
        case .timeCode32:
            // 32-bit timecode: flags (1 byte) + hours (1) + minutes (1) + seconds (1) + frames (1) + reserved (3)
            data.append(dropFrame ? 0x01 : 0x00)
            data.append(UInt8(hours))
            data.append(UInt8(minutes))
            data.append(UInt8(seconds))
            data.append(UInt8(frames))
            data.append(contentsOf: [0x00, 0x00, 0x00]) // Reserved
            
        case .timeCode64:
            // 64-bit timecode: extended format
            // Would need full 64-bit encoding
            data.append(dropFrame ? 0x01 : 0x00)
            data.append(UInt8(hours))
            data.append(UInt8(minutes))
            data.append(UInt8(seconds))
            data.append(UInt8(frames))
            data.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]) // Extended
            
        case .counter32, .counter64:
            // Counter formats would encode differently
            // Simplified for now
            let counter = hours * 3600 * Int(frameRate) + minutes * 60 * Int(frameRate) + seconds * Int(frameRate) + frames
            var counterValue = UInt32(counter)
            data.append(contentsOf: withUnsafeBytes(of: &counterValue) { Data($0) })
        }
        
        return data
    }
}

