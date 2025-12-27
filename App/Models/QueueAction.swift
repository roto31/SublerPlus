import Foundation

/// Queue action types for batch processing
public enum QueueActionType: String, Codable, Sendable {
    case pre  // Before muxing
    case post // After muxing
}

/// Protocol for queue actions
public protocol QueueAction: Sendable {
    var type: QueueActionType { get }
    var description: String { get }
    func execute(on file: URL) async throws
}

/// Set preferred tracks by language
public struct QueuePreferredTrackAction: QueueAction {
    public let type: QueueActionType = .pre
    public let description: String
    public let trackKind: MediaTrack.Kind
    public let preferredLanguage: String
    
    public init(trackKind: MediaTrack.Kind, preferredLanguage: String) {
        self.trackKind = trackKind
        self.preferredLanguage = preferredLanguage
        self.description = "Set preferred \(trackKind.rawValue) track to \(preferredLanguage)"
    }
    
    public func execute(on file: URL) async throws {
        // Extract tracks
        let tracks = try await ContainerImporter.extractTracks(from: file)
        
        // Find preferred track
        _ = tracks.filter { track in
            track.kind == trackKind && track.language?.lowercased() == preferredLanguage.lowercased()
        }
        
        // Mark preferred track as default
        // This would require updating the MP4 file's track flags
        // For now, this is a placeholder - full implementation would use AtomCodec
        // to update track header flags (tkhd atom)
    }
}

/// Fix audio fallback settings
public struct QueueFixFallbacksAction: QueueAction {
    public let type: QueueActionType = .pre
    public let description = "Fix audio fallback settings"
    
    public init() {}
    
    public func execute(on file: URL) async throws {
        // Audio fallbacks determine which audio track plays when language changes
        // This requires setting alternate group IDs and fallback relationships
        // Full implementation would use AtomCodec to update track relationships
    }
}

/// Set track language for unknown tracks
public struct QueueSetLanguageAction: QueueAction {
    public let type: QueueActionType = .pre
    public let description: String
    public let language: String
    
    public init(language: String) {
        self.language = language
        self.description = "Set unknown language tracks to \(language)"
    }
    
    public func execute(on file: URL) async throws {
        // Update tracks with "und" (undefined) language to specified language
        // This would require updating track language metadata in MP4
        // Full implementation would use AtomCodec to update mdhd atom language field
    }
}

/// Clear track names
public struct QueueClearTrackNameAction: QueueAction {
    public let type: QueueActionType = .pre
    public let description = "Clear track names"
    
    public init() {}
    
    public func execute(on file: URL) async throws {
        // Remove track name metadata
        // Full implementation would use AtomCodec to remove name atoms
    }
}

/// Organize track groups (audio/subtitle grouping)
public struct QueueOrganizeGroupsAction: QueueAction {
    public let type: QueueActionType = .pre
    public let description = "Organize track groups"
    
    public init() {}
    
    public func execute(on file: URL) async throws {
        // Group related tracks (e.g., all English audio tracks together)
        // This requires setting alternate group IDs
        // Full implementation would use AtomCodec to update track grouping
    }
}

/// Batch operation configuration
public struct QueueBatchConfig: Sendable, Codable {
    public var preferredAudioLanguage: String?
    public var preferredSubtitleLanguage: String?
    public var fixFallbacks: Bool
    public var setLanguage: String?
    public var clearTrackNames: Bool
    public var organizeGroups: Bool
    public var optimize: Bool
    
    public init(
        preferredAudioLanguage: String? = nil,
        preferredSubtitleLanguage: String? = nil,
        fixFallbacks: Bool = false,
        setLanguage: String? = nil,
        clearTrackNames: Bool = false,
        organizeGroups: Bool = false,
        optimize: Bool = false
    ) {
        self.preferredAudioLanguage = preferredAudioLanguage
        self.preferredSubtitleLanguage = preferredSubtitleLanguage
        self.fixFallbacks = fixFallbacks
        self.setLanguage = setLanguage
        self.clearTrackNames = clearTrackNames
        self.organizeGroups = organizeGroups
        self.optimize = optimize
    }
}

