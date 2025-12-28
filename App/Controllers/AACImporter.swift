import Foundation
import AVFoundation
import CoreMedia

public final class AACImporter: RawFormatImporter {
    public let formatType: RawFormatType = .aac
    
    public func canImport(url: URL) -> Bool {
        RawFormatHandler.detectFormat(url: url) == .aac
    }
    
    public func extractTrackInfo(from url: URL) async throws -> MediaTrack {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            throw RawFormatError.invalidFile
        }
        defer { try? fileHandle.close() }
        
        // Read first ADTS frame to get audio info
        guard let adtsHeader = try? fileHandle.read(upToCount: 7) else {
            throw RawFormatError.parseFailed
        }
        
        guard adtsHeader.count >= 7 else {
            throw RawFormatError.parseFailed
        }
        
        // Parse ADTS header
        // Bits: syncword(12) + ID(1) + layer(2) + protection_absent(1) + profile(2) + sampling_freq_index(4) + private_bit(1) + channel_config(3) + ...
        let bytes = [UInt8](adtsHeader)
        
        // Check syncword (0xFFF)
        guard (bytes[0] & 0xFF) == 0xFF && (bytes[1] & 0xF0) == 0xF0 else {
            throw RawFormatError.parseFailed
        }
        
        // Extract profile (bits 3-4 of byte 2)
        _ = (bytes[2] >> 6) & 0x03
        
        // Extract sampling frequency index (bits 2-5 of byte 2)
        let samplingFreqIndex = (bytes[2] >> 2) & 0x0F
        
        // Extract channel configuration (bits 0-2 of byte 3)
        _ = (bytes[3] >> 6) & 0x07
        
        // Map sampling frequency
        let sampleRates: [Int] = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350]
        _ = samplingFreqIndex < sampleRates.count ? sampleRates[Int(samplingFreqIndex)] : 44100
        
        // Estimate bitrate (rough estimate based on file size and duration if available)
        // For raw streams, we can't determine duration easily without parsing all frames
        let bitrate: Int? = nil
        
        return MediaTrack(
            kind: .audio,
            codec: "aac",
            language: nil,
            bitrate: bitrate,
            isDefault: true,
            isForced: false,
            resolution: nil,
            hdr: false
        )
    }
}

