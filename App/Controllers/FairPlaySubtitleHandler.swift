import Foundation
import AVFoundation

/// Handler for FairPlay-encrypted subtitles
public final class FairPlaySubtitleHandler: @unchecked Sendable {
    
    public init() {}
    
    /// Detect if track contains FairPlay-encrypted subtitles
    public func isFairPlaySubtitle(track: AVAssetTrack) -> Bool {
        guard let formatDescriptions = track.formatDescriptions as? [CMFormatDescription],
              let firstDesc = formatDescriptions.first else {
            return false
        }
        
        let codecType = CMFormatDescriptionGetMediaSubType(firstDesc)
        
        // FairPlay subtitle codec: 'drmt'
        return codecType == fourCCToCode("drmt")
    }
    
    /// Detect FairPlay subtitles from codec string
    public func isFairPlaySubtitle(codec: String) -> Bool {
        return codec.lowercased() == "drmt" || codec.lowercased().contains("fairplay")
    }
    
    /// Handle FairPlay subtitle track
    /// Returns error message if passthrough is not possible
    public func handleFairPlaySubtitle(track: AVAssetTrack) throws -> String {
        // FairPlay-encrypted subtitles cannot be converted or modified
        // They can only be passthrough if the source file supports it
        // Return appropriate error message
        throw FairPlayError.encryptedContent("FairPlay-encrypted subtitles cannot be converted. Passthrough only.")
    }
    
    /// Convert FourCC string to FourCharCode
    private func fourCCToCode(_ string: String) -> FourCharCode {
        guard string.count == 4 else { return 0 }
        let bytes = string.utf8.prefix(4)
        var code: FourCharCode = 0
        for (index, byte) in bytes.enumerated() {
            code |= FourCharCode(byte) << (8 * (3 - index))
        }
        return code
    }
}

public enum FairPlayError: Error, Equatable {
    case encryptedContent(String)
    case unsupportedOperation
}

