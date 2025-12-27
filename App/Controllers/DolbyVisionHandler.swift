import Foundation
import AVFoundation
import CoreMedia

/// Handles Dolby Vision metadata extraction and preservation
public final class DolbyVisionHandler: @unchecked Sendable {
    
    public struct DolbyVisionMetadata: Sendable {
        public let versionMajor: UInt8?
        public let versionMinor: UInt8?
        public let profile: Int?
        public let level: Int?
        public let rpuPresentFlag: Bool
        public let elPresentFlag: Bool
        public let blPresentFlag: Bool
        public let blSignalCompatibilityId: UInt8?
        public let rpuData: Data? // Reference Processing Unit data
        public let elConfiguration: Data? // Enhancement Layer configuration (hvcE/avcE)
        public let blData: Data? // Base Layer data
        
        public init(
            versionMajor: UInt8? = nil,
            versionMinor: UInt8? = nil,
            profile: Int? = nil,
            level: Int? = nil,
            rpuPresentFlag: Bool = false,
            elPresentFlag: Bool = false,
            blPresentFlag: Bool = false,
            blSignalCompatibilityId: UInt8? = nil,
            rpuData: Data? = nil,
            elConfiguration: Data? = nil,
            blData: Data? = nil
        ) {
            self.versionMajor = versionMajor
            self.versionMinor = versionMinor
            self.profile = profile
            self.level = level
            self.rpuPresentFlag = rpuPresentFlag
            self.elPresentFlag = elPresentFlag
            self.blPresentFlag = blPresentFlag
            self.blSignalCompatibilityId = blSignalCompatibilityId
            self.rpuData = rpuData
            self.elConfiguration = elConfiguration
            self.blData = blData
        }
    }
    
    public init() {}
    
    /// Extract Dolby Vision metadata from video track
    public func extractDolbyVisionMetadata(from track: AVAssetTrack) async throws -> DolbyVisionMetadata {
        guard let formatDescriptions = track.formatDescriptions as? [CMFormatDescription] else {
            throw DolbyVisionError.noFormatDescription
        }
        
        // Dolby Vision metadata is stored in dvcC, dvvC, or dvwC atoms
        // Check format description extensions for Dolby Vision configuration
        
        var versionMajor: UInt8? = nil
        var versionMinor: UInt8? = nil
        var profile: Int? = nil
        var level: Int? = nil
        var rpuPresentFlag = false
        var elPresentFlag = false
        var blPresentFlag = false
        var blSignalCompatibilityId: UInt8? = nil
        var rpuData: Data? = nil
        var elConfiguration: Data? = nil
        
        for formatDesc in formatDescriptions {
            let extensions = CMFormatDescriptionGetExtensions(formatDesc) as? [String: Any]
            
            // Check for Dolby Vision configuration atoms (dvcC, dvvC, dvwC)
            if let atoms = extensions?[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String] as? [String: Any] {
                // Try dvcC first (Dolby Vision H.264)
                if let dvcC = atoms["dvcC" as String] as? Data, dvcC.count >= 24 {
                    let parsed = parseDolbyVisionConfiguration(dvcC)
                    versionMajor = parsed.versionMajor
                    versionMinor = parsed.versionMinor
                    profile = parsed.profile
                    level = parsed.level
                    rpuPresentFlag = parsed.rpuPresentFlag
                    elPresentFlag = parsed.elPresentFlag
                    blPresentFlag = parsed.blPresentFlag
                    blSignalCompatibilityId = parsed.blSignalCompatibilityId
                    rpuData = dvcC // Store full configuration as RPU data
                }
                // Try dvvC (Dolby Vision HEVC)
                else if let dvvC = atoms["dvvC" as String] as? Data, dvvC.count >= 24 {
                    let parsed = parseDolbyVisionConfiguration(dvvC)
                    versionMajor = parsed.versionMajor
                    versionMinor = parsed.versionMinor
                    profile = parsed.profile
                    level = parsed.level
                    rpuPresentFlag = parsed.rpuPresentFlag
                    elPresentFlag = parsed.elPresentFlag
                    blPresentFlag = parsed.blPresentFlag
                    blSignalCompatibilityId = parsed.blSignalCompatibilityId
                    rpuData = dvvC
                }
                // Try dvwC (Dolby Vision Web)
                else if let dvwC = atoms["dvwC" as String] as? Data, dvwC.count >= 24 {
                    let parsed = parseDolbyVisionConfiguration(dvwC)
                    versionMajor = parsed.versionMajor
                    versionMinor = parsed.versionMinor
                    profile = parsed.profile
                    level = parsed.level
                    rpuPresentFlag = parsed.rpuPresentFlag
                    elPresentFlag = parsed.elPresentFlag
                    blPresentFlag = parsed.blPresentFlag
                    blSignalCompatibilityId = parsed.blSignalCompatibilityId
                    rpuData = dvwC
                }
                
                // Check for enhancement layer configuration (hvcE or avcE)
                if let hvcE = atoms["hvcE" as String] as? Data {
                    elConfiguration = hvcE
                } else if let avcE = atoms["avcE" as String] as? Data {
                    elConfiguration = avcE
                }
            }
        }
        
        return DolbyVisionMetadata(
            versionMajor: versionMajor,
            versionMinor: versionMinor,
            profile: profile,
            level: level,
            rpuPresentFlag: rpuPresentFlag,
            elPresentFlag: elPresentFlag,
            blPresentFlag: blPresentFlag,
            blSignalCompatibilityId: blSignalCompatibilityId,
            rpuData: rpuData,
            elConfiguration: elConfiguration,
            blData: nil  // Base layer is the main video track
        )
    }
    
    /// Check if track contains Dolby Vision
    public func isDolbyVision(track: AVAssetTrack) -> Bool {
        guard let formatDescriptions = track.formatDescriptions as? [CMFormatDescription] else {
            return false
        }
        
        for formatDesc in formatDescriptions {
            let extensions = CMFormatDescriptionGetExtensions(formatDesc) as? [String: Any]
            
            // Check for Dolby Vision indicators
            if extensions?["dovi" as String] != nil {
                return true
            }
            
            // Check codec name
            let codecType = CMFormatDescriptionGetMediaSubType(formatDesc)
            if codecType == kCMVideoCodecType_HEVC {
                // HEVC can contain Dolby Vision
                // Check for Dolby Vision in HEVC extensions
                if let hevcExtensions = extensions?[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String] as? [String: Any] {
                    if hevcExtensions["dovi" as String] != nil {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Preserve Dolby Vision metadata in output
    /// Note: Full Dolby Vision preservation requires maintaining RPU data and enhancement layers
    public func preserveDolbyVisionMetadata(
        metadata: DolbyVisionMetadata,
        in composition: AVMutableComposition,
        for track: AVMutableCompositionTrack
    ) throws {
        // Dolby Vision preservation is complex and typically handled by AVFoundation
        // when using passthrough export with HEVC tracks
        
        // For explicit preservation, we would need to:
        // 1. Maintain RPU data in sample buffers
        // 2. Preserve enhancement layer track if present
        // 3. Ensure proper track grouping
        
        // AVFoundation's passthrough mode should preserve this automatically
        // Full implementation would require low-level sample buffer manipulation
    }
    
    /// Parse Dolby Vision configuration from dvcC/dvvC/dvwC atom
    /// Format: 24+ bytes containing version, profile, level, flags
    private func parseDolbyVisionConfiguration(_ data: Data) -> (
        versionMajor: UInt8,
        versionMinor: UInt8,
        profile: Int,
        level: Int,
        rpuPresentFlag: Bool,
        elPresentFlag: Bool,
        blPresentFlag: Bool,
        blSignalCompatibilityId: UInt8
    ) {
        guard data.count >= 24 else {
            // Return defaults if data is too short
            return (0, 0, 0, 0, false, false, false, 0)
        }
        
        let buffer = [UInt8](data.prefix(24))
        
        // Parse according to Dolby Vision configuration structure
        // Byte 0: version_major
        let versionMajor = buffer[0]
        
        // Byte 1: version_minor
        let versionMinor = buffer[1]
        
        // Byte 2: profile (bits 7-1) and level MSB (bit 0)
        let profile = Int((buffer[2] & 0xFE) >> 1)
        let levelMSB = Int(buffer[2] & 0x01)
        
        // Byte 3: level LSB (bits 7-3), rpu_present_flag (bit 2), el_present_flag (bit 1), bl_present_flag (bit 0)
        let levelLSB = Int((buffer[3] & 0xF8) >> 3)
        let level = (levelMSB << 7) | levelLSB
        let rpuPresentFlag = (buffer[3] & 0x04) != 0
        let elPresentFlag = (buffer[3] & 0x02) != 0
        let blPresentFlag = (buffer[3] & 0x01) != 0
        
        // Byte 4: bl_signal_compatibility_id (bits 7-4)
        let blSignalCompatibilityId = (buffer[4] & 0xF0) >> 4
        
        return (
            versionMajor: versionMajor,
            versionMinor: versionMinor,
            profile: profile,
            level: level,
            rpuPresentFlag: rpuPresentFlag,
            elPresentFlag: elPresentFlag,
            blPresentFlag: blPresentFlag,
            blSignalCompatibilityId: blSignalCompatibilityId
        )
    }
    
    /// Extract RPU data from sample buffers
    /// RPU data is embedded in SEI messages in HEVC/H.264 streams
    public func extractRPUFromSamples(track: AVAssetTrack) async throws -> [Data] {
        // Extract RPU data from sample buffers
        // This requires reading sample buffers and parsing SEI messages
        // For now, return empty array - full implementation would require
        // low-level sample buffer parsing
        
        // Full implementation would:
        // 1. Read sample buffers from track
        // 2. Parse HEVC/H.264 NAL units
        // 3. Extract SEI messages containing RPU data
        // 4. Return array of RPU data packets
        
        return []
    }
    
    /// Preserve enhancement layer track
    /// Enhancement layers are separate video tracks that need to be grouped with base layer
    public func preserveEnhancementLayer(
        elTrack: AVAssetTrack,
        in composition: AVMutableComposition,
        groupedWith baseTrack: AVMutableCompositionTrack,
        duration: CMTime
    ) throws -> AVMutableCompositionTrack? {
        // Create enhancement layer track in composition
        guard let elCompTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return nil
        }
        
        // Copy samples from enhancement layer track
        try elCompTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: elTrack,
            at: .zero
        )
        
        // Set alternate group to link with base layer
        // Enhancement layers typically use alternate_group = 1
        // This would require low-level MP4 atom manipulation
        
        return elCompTrack
    }
}

public enum DolbyVisionError: Error, Equatable {
    case noFormatDescription
    case extractionFailed
    case preservationFailed
    case unsupportedProfile
}

