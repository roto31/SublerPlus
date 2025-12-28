import Foundation
import AVFoundation
import CoreMedia

public final class H264Importer: RawFormatImporter {
    public let formatType: RawFormatType = .h264
    
    public func canImport(url: URL) -> Bool {
        RawFormatHandler.detectFormat(url: url) == .h264
    }
    
    public func extractTrackInfo(from url: URL) async throws -> MediaTrack {
        guard let data = try? Data(contentsOf: url) else {
            throw RawFormatError.invalidFile
        }
        
        // Parse H.264 NAL units to find SPS/PPS
        var sps: Data?
        var width: Int?
        var height: Int?
        
        var offset = 0
        while offset < data.count - 4 {
            // Find NAL unit start code (0x00 0x00 0x00 0x01 or 0x00 0x00 0x01)
            var startCodeLength = 0
            if offset + 4 <= data.count && data[offset] == 0x00 && data[offset + 1] == 0x00 && data[offset + 2] == 0x00 && data[offset + 3] == 0x01 {
                startCodeLength = 4
            } else if offset + 3 <= data.count && data[offset] == 0x00 && data[offset + 1] == 0x00 && data[offset + 2] == 0x01 {
                startCodeLength = 3
            }
            
            if startCodeLength > 0 {
                let nalStart = offset + startCodeLength
                if nalStart < data.count {
                    let nalType = data[nalStart] & 0x1F
                    
                    // Find next NAL unit
                    var nextStart = -1
                    for i in (nalStart + 1)..<min(data.count - 3, nalStart + 1000) {
                        if i + 3 < data.count && data[i] == 0x00 && data[i + 1] == 0x00 && data[i + 2] == 0x01 {
                            nextStart = i
                            break
                        }
                        if i + 4 < data.count && data[i] == 0x00 && data[i + 1] == 0x00 && data[i + 2] == 0x00 && data[i + 3] == 0x01 {
                            nextStart = i
                            break
                        }
                    }
                    
                    let nalEnd = nextStart > 0 ? nextStart : data.count
                    let nalData = data[nalStart..<nalEnd]
                    
                    if nalType == 7 { // SPS
                        sps = Data(nalData)
                        if let dimensions = parseSPSDimensions(data: nalData) {
                            width = dimensions.width
                            height = dimensions.height
                        }
                    } else if nalType == 8 { // PPS
                        _ = Data(nalData) // PPS not used in current implementation
                    }
                    
                    offset = nalEnd
                } else {
                    break
                }
            } else {
                offset += 1
            }
        }
        
        guard sps != nil else {
            throw RawFormatError.parseFailed
        }
        
        let resolution = (width != nil && height != nil) ? "\(width!)x\(height!)" : nil
        
        return MediaTrack(
            kind: .video,
            codec: "avc1",
            language: nil,
            bitrate: nil,
            isDefault: true,
            isForced: false,
            resolution: resolution,
            hdr: false
        )
    }
    
    private func parseSPSDimensions(data: Data) -> (width: Int, height: Int)? {
        // Simplified SPS parsing - extract width/height from SPS
        // This is a basic implementation; full SPS parsing is complex
        guard data.count > 10 else { return nil }
        
        // Skip NAL header and profile/level
        _ = 1
        
        // Parse SPS syntax (simplified)
        // In real implementation, would use proper Exp-Golomb decoding
        // For now, return nil and let AVFoundation handle it
        return nil
    }
}

