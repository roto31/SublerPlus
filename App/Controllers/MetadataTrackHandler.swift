import Foundation
import AVFoundation
import CoreMedia

/// Handles timed metadata track extraction and creation
public final class MetadataTrackHandler: @unchecked Sendable {
    
    public struct TimedMetadataItem: Sendable {
        public let time: CMTime
        public let key: String
        public let value: String
        
        public init(time: CMTime, key: String, value: String) {
            self.time = time
            self.key = key
            self.value = value
        }
    }
    
    public init() {}
    
    /// Extract timed metadata from track
    public func extractTimedMetadata(from track: AVAssetTrack) async throws -> [TimedMetadataItem] {
        var items: [TimedMetadataItem] = []
        
        // Load metadata track samples
        // AVFoundation provides limited access to timed metadata
        // Full implementation would require parsing sample buffers
        
        // For now, return empty array
        // Full implementation would:
        // 1. Load sample buffers from track
        // 2. Extract metadata items from each sample
        // 3. Parse key-value pairs
        
        return items
    }
    
    /// Create timed metadata track
    public func createTimedMetadataTrack(
        in composition: AVMutableComposition,
        items: [TimedMetadataItem],
        duration: CMTime
    ) throws -> AVMutableCompositionTrack? {
        guard let metadataTrack = composition.addMutableTrack(
            withMediaType: .metadata,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return nil
        }
        
        // Create metadata samples from items
        // This requires creating AVMetadataItem objects and inserting them
        // AVFoundation has limited support for creating timed metadata tracks
        // Full implementation would require low-level sample buffer creation
        
        return metadataTrack
    }
    
    /// Extract chapter markers as timed metadata
    public func extractChaptersAsMetadata(from asset: AVAsset) async throws -> [TimedMetadataItem] {
        // Load available metadata groups
        let availableGroups = try await asset.load(.availableMetadataFormats)
        var items: [TimedMetadataItem] = []
        
        // Look for chapter metadata in available formats
        for format in availableGroups {
            let metadata = try await asset.loadMetadata(for: format)
            for item in metadata {
                if let title = item.stringValue,
                   item.identifier == .commonIdentifierTitle {
                    items.append(TimedMetadataItem(
                        time: item.time,
                        key: "title",
                        value: title
                    ))
                }
            }
        }
        
        return items
    }
}

