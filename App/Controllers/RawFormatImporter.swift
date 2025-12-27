import Foundation
import AVFoundation
import CoreMedia

public enum RawFormatType: String, Sendable {
    case h264 = "h264"
    case aac = "aac"
    case ac3 = "ac3"
    case scc = "scc"
    case idx = "idx"
    case unknown
}

public enum RawFormatError: Error, Equatable {
    case unsupportedFormat
    case invalidFile
    case parseFailed
}

public protocol RawFormatImporter: Sendable {
    var formatType: RawFormatType { get }
    func canImport(url: URL) -> Bool
    func extractTrackInfo(from url: URL) async throws -> MediaTrack
}

public final class RawFormatHandler: @unchecked Sendable {
    
    public static func detectFormat(url: URL) -> RawFormatType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "h264", "264":
            return .h264
        case "aac":
            return .aac
        case "ac3":
            return .ac3
        case "scc":
            return .scc
        case "idx":
            return .idx
        default:
            return detectFormatBySignature(url: url)
        }
    }
    
    private static func detectFormatBySignature(url: URL) -> RawFormatType {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return .unknown
        }
        defer { try? fileHandle.close() }
        
        guard let data = try? fileHandle.read(upToCount: 8) else {
            return .unknown
        }
        
        // H.264: Start with NAL unit (0x00 0x00 0x00 0x01 or 0x00 0x00 0x01)
        if data.count >= 4 {
            let bytes = [UInt8](data[0..<4])
            if bytes == [0x00, 0x00, 0x00, 0x01] || bytes == [0x00, 0x00, 0x01] {
                // Check for SPS NAL unit (type 7)
                if data.count >= 5 {
                    let nalType = data[4] & 0x1F
                    if nalType == 7 {
                        return .h264
                    }
                }
            }
        }
        
        // AAC: ADTS header starts with 0xFF 0xF1-0xF9
        if data.count >= 2 {
            let bytes = [UInt8](data[0..<2])
            if bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0 {
                return .aac
            }
        }
        
        // AC3: Sync word 0x0B77
        if data.count >= 2 {
            let bytes = [UInt8](data[0..<2])
            if bytes == [0x0B, 0x77] || bytes == [0x77, 0x0B] {
                return .ac3
            }
        }
        
        return .unknown
    }
    
    public static func createImporter(for url: URL) -> RawFormatImporter? {
        let format = detectFormat(url: url)
        switch format {
        case .h264:
            return H264Importer()
        case .aac:
            return AACImporter()
        case .ac3:
            return AC3Importer()
        case .scc:
            return SubtitleRawImporter(format: .scc)
        case .idx:
            return SubtitleRawImporter(format: .idx)
        case .unknown:
            return nil
        }
    }
}

