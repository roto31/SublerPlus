import Foundation
import AVFoundation

/// Handler for FairPlay-encrypted closed captions (CEA-608)
public final class FairPlayCCHandler: @unchecked Sendable {
    
    public init() {}
    
    /// Detect if track contains FairPlay-encrypted CEA-608 closed captions
    public func isFairPlayCC(track: AVAssetTrack) -> Bool {
        guard let formatDescriptions = track.formatDescriptions as? [CMFormatDescription],
              let firstDesc = formatDescriptions.first else {
            return false
        }
        
        let codecType = CMFormatDescriptionGetMediaSubType(firstDesc)
        
        // FairPlay CEA-608 codec: 'p608'
        return codecType == fourCCToCode("p608")
    }
    
    /// Detect FairPlay closed captions from codec string
    public func isFairPlayCC(codec: String) -> Bool {
        return codec.lowercased() == "p608" || codec.lowercased().contains("fairplay")
    }
    
    /// Handle FairPlay closed caption track
    /// Returns error message if passthrough is not possible
    public func handleFairPlayCC(track: AVAssetTrack) throws -> String {
        // FairPlay-encrypted closed captions cannot be converted or modified
        // They can only be passthrough if the source file supports it
        throw FairPlayCCError.encryptedContent("FairPlay-encrypted closed captions cannot be converted. Passthrough only.")
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

public enum FairPlayCCError: Error, Equatable {
    case encryptedContent(String)
    case unsupportedOperation
}

