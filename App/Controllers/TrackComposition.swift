import Foundation
import AVFoundation

public enum CompositionError: Error, Equatable {
    case noTracksSelected
    case invalidTrack
    case compositionFailed
    case exportFailed
}

public final class TrackComposition: @unchecked Sendable {
    
    /// Create a composition from selected tracks
    public static func createComposition(
        tracks: [TrackSelection],
        options: MuxingOptions
    ) async throws -> AVMutableComposition {
        guard !tracks.isEmpty else {
            throw CompositionError.noTracksSelected
        }
        
        let composition = AVMutableComposition()
        var videoDuration: CMTime = .zero
        var audioDuration: CMTime = .zero
        
        // Group tracks by source URL for efficient loading
        let tracksBySource = Dictionary(grouping: tracks) { $0.sourceURL }
        
        for (sourceURL, sourceTracks) in tracksBySource {
            let asset = AVURLAsset(url: sourceURL)
            let assetDuration = try await asset.load(.duration)
            
            // Process each track from this source
            for trackSelection in sourceTracks {
                guard trackSelection.selected else { continue }
                
                let track = trackSelection.track
                
                switch track.kind {
                case .video:
                    if let avTrack = try? await findAVTrack(in: asset, matching: track, mediaType: .video) {
                        if let compTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                            try compTrack.insertTimeRange(
                                CMTimeRange(start: .zero, duration: assetDuration),
                                of: avTrack,
                                at: videoDuration
                            )
                            videoDuration = CMTimeMaximum(videoDuration, assetDuration)
                        }
                    }
                    
                case .audio:
                    if let avTrack = try? await findAVTrack(in: asset, matching: track, mediaType: .audio) {
                        if let compTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                            try compTrack.insertTimeRange(
                                CMTimeRange(start: .zero, duration: assetDuration),
                                of: avTrack,
                                at: audioDuration
                            )
                            audioDuration = CMTimeMaximum(audioDuration, assetDuration)
                        }
                    }
                    
                case .subtitle:
                    // Subtitles will be handled separately via TX3G encoding
                    break
                    
                default:
                    break
                }
            }
        }
        
        guard !composition.tracks.isEmpty else {
            throw CompositionError.noTracksSelected
        }
        
        return composition
    }
    
    private static func findAVTrack(in asset: AVAsset, matching track: MediaTrack, mediaType: AVMediaType) async throws -> AVAssetTrack? {
        let avTracks = try await asset.loadTracks(withMediaType: mediaType)
        
        // Try to match by codec and language
        for avTrack in avTracks {
            let avCodec = extractCodec(from: avTrack)
            let avLanguage = try? await avTrack.load(.languageCode)
            
            if avCodec == track.codec && avLanguage == track.language {
                return avTrack
            }
        }
        
        // Fallback: return first track of matching type
        return avTracks.first
    }
    
    private static func extractCodec(from track: AVAssetTrack) -> String? {
        guard let formatDescriptions = track.formatDescriptions as? [CMFormatDescription],
              let firstDesc = formatDescriptions.first else {
            return nil
        }
        
        let codecType = CMFormatDescriptionGetMediaSubType(firstDesc)
        return fourCCToString(codecType)
    }
    
    private static func fourCCToString(_ fourCC: FourCharCode) -> String {
        let bytes = [
            UInt8((fourCC >> 24) & 0xFF),
            UInt8((fourCC >> 16) & 0xFF),
            UInt8((fourCC >> 8) & 0xFF),
            UInt8(fourCC & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "unknown"
    }
}

