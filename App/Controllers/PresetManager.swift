import Foundation

/// Manages muxing presets
public actor PresetManager {
    
    private var presets: [Preset] = []
    private let presetsKey = "SublerPlus.Presets"
    
    public init() {
        // Load built-in presets synchronously
        presets = BuiltInPreset.allCases.map { $0.createPreset() }
        
        // Load custom presets from UserDefaults
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let customPresets = try? JSONDecoder().decode([Preset].self, from: data) {
            presets.append(contentsOf: customPresets)
        }
    }
    
    /// Save custom presets to UserDefaults
    private func savePresets() {
        // Separate built-in and custom presets
        let builtInIds = Set(BuiltInPreset.allCases.map { $0.createPreset().id })
        let customPresets = presets.filter { !builtInIds.contains($0.id) }
        
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }
    
    /// Get all presets
    public func getAllPresets() -> [Preset] {
        return presets
    }
    
    /// Get preset by ID
    public func getPreset(id: UUID) -> Preset? {
        return presets.first { $0.id == id }
    }
    
    /// Get preset by name
    public func getPreset(name: String) -> Preset? {
        return presets.first { $0.name == name }
    }
    
    /// Add or update preset
    public func savePreset(_ preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        savePresets()
    }
    
    /// Delete preset
    public func deletePreset(id: UUID) {
        // Don't delete built-in presets
        let builtInIds = Set(BuiltInPreset.allCases.map { $0.createPreset().id })
        guard !builtInIds.contains(id) else { return }
        
        presets.removeAll { $0.id == id }
        savePresets()
    }
    
    /// Apply preset to muxing options
    public func applyPreset(_ preset: Preset, to options: inout MuxingOptions, tracks: [TrackSelection]) -> [TrackSelection] {
        var modifiedTracks = tracks
        
        // Apply video settings
        if let videoSettings = preset.videoSettings {
            modifiedTracks = applyVideoSettings(videoSettings, to: modifiedTracks)
        }
        
        // Apply audio settings
        if let audioSettings = preset.audioSettings {
            modifiedTracks = applyAudioSettings(audioSettings, to: modifiedTracks)
            options.defaultAudioSettings = audioSettings.conversionSettings
        }
        
        // Apply subtitle settings
        if let subtitleSettings = preset.subtitleSettings {
            modifiedTracks = applySubtitleSettings(subtitleSettings, to: modifiedTracks)
        }
        
        // Apply optimization
        options.optimize = preset.optimize
        
        return modifiedTracks
    }
    
    /// Apply video preset settings
    private func applyVideoSettings(_ settings: VideoPresetSettings, to tracks: [TrackSelection]) -> [TrackSelection] {
        var modified = tracks
        
        // Filter by codec if specified
        if let preferredCodec = settings.preferredCodec {
            modified = modified.map { selection in
                if selection.track.kind == .video {
                    if selection.track.codec?.lowercased() != preferredCodec.lowercased() {
                        return TrackSelection(
                            id: selection.id,
                            track: selection.track,
                            sourceURL: selection.sourceURL,
                            selected: false, // Deselect non-preferred codec
                            conversionSettings: selection.conversionSettings
                        )
                    }
                }
                return selection
            }
        }
        
        // Filter by resolution if specified
        if let maxResolution = settings.maxResolution {
            let maxRes = parseResolution(maxResolution)
            modified = modified.map { selection in
                if selection.track.kind == .video,
                   let trackRes = selection.track.resolution {
                    let trackResValues = parseResolution(trackRes)
                    if trackResValues.width > maxRes.width || trackResValues.height > maxRes.height {
                        return TrackSelection(
                            id: selection.id,
                            track: selection.track,
                            sourceURL: selection.sourceURL,
                            selected: false,
                            conversionSettings: selection.conversionSettings
                        )
                    }
                }
                return selection
            }
        }
        
        return modified
    }
    
    /// Apply audio preset settings
    private func applyAudioSettings(_ settings: AudioPresetSettings, to tracks: [TrackSelection]) -> [TrackSelection] {
        var modified = tracks
        
        // Filter by language if specified
        if let preferredLanguage = settings.preferredLanguage {
            modified = modified.map { selection in
                if selection.track.kind == .audio {
                    let matchesLanguage = selection.track.language?.lowercased() == preferredLanguage.lowercased()
                    if !matchesLanguage && !settings.keepAllTracks {
                        return TrackSelection(
                            id: selection.id,
                            track: selection.track,
                            sourceURL: selection.sourceURL,
                            selected: false,
                            conversionSettings: selection.conversionSettings
                        )
                    }
                }
                return selection
            }
        }
        
        // Apply conversion settings
        if let conversionSettings = settings.conversionSettings {
            modified = modified.map { selection in
                if selection.track.kind == .audio,
                   selection.selected {
                    return TrackSelection(
                        id: selection.id,
                        track: selection.track,
                        sourceURL: selection.sourceURL,
                        selected: selection.selected,
                        conversionSettings: conversionSettings
                    )
                }
                return selection
            }
        }
        
        return modified
    }
    
    /// Apply subtitle preset settings
    private func applySubtitleSettings(_ settings: SubtitlePresetSettings, to tracks: [TrackSelection]) -> [TrackSelection] {
        var modified = tracks
        
        // Filter by language
        if let preferredLanguage = settings.preferredLanguage {
            modified = modified.map { selection in
                if selection.track.kind == .subtitle {
                    let matchesLanguage = selection.track.language?.lowercased() == preferredLanguage.lowercased()
                    if !matchesLanguage && !settings.keepAllTracks {
                        return TrackSelection(
                            id: selection.id,
                            track: selection.track,
                            sourceURL: selection.sourceURL,
                            selected: false,
                            conversionSettings: selection.conversionSettings
                        )
                    }
                }
                return selection
            }
        }
        
        // Remove forced subtitles if requested
        if settings.removeForced {
            modified = modified.map { selection in
                if selection.track.kind == .subtitle && selection.track.isForced {
                    return TrackSelection(
                        id: selection.id,
                        track: selection.track,
                        sourceURL: selection.sourceURL,
                        selected: false,
                        conversionSettings: selection.conversionSettings
                    )
                }
                return selection
            }
        }
        
        return modified
    }
    
    /// Parse resolution string (e.g., "1920x1080")
    private func parseResolution(_ resolution: String) -> (width: Int, height: Int) {
        let parts = resolution.components(separatedBy: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]) else {
            return (0, 0)
        }
        return (width, height)
    }
    
    /// Export presets to JSON data
    public func exportPresets(format: ExportFormat = .json) throws -> Data {
        // Export only custom presets (not built-in)
        let builtInIds = Set(BuiltInPreset.allCases.map { $0.createPreset().id })
        let customPresets = presets.filter { !builtInIds.contains($0.id) }
        
        switch format {
        case .json:
            return try JSONEncoder().encode(customPresets)
        case .plist:
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            return try encoder.encode(customPresets)
        }
    }
    
    /// Export presets to file
    public func exportPresets(to url: URL, format: ExportFormat = .json) throws {
        let data = try exportPresets(format: format)
        try data.write(to: url)
    }
    
    /// Import presets from JSON/PLIST data
    public func importPresets(from data: Data, format: ExportFormat = .json, conflictResolution: ConflictResolution = .rename) throws -> ImportResult {
        let importedPresets: [Preset]
        
        switch format {
        case .json:
            importedPresets = try JSONDecoder().decode([Preset].self, from: data)
        case .plist:
            let decoder = PropertyListDecoder()
            importedPresets = try decoder.decode([Preset].self, from: data)
        }
        
        // Validate imported presets
        var validPresets: [Preset] = []
        var invalidPresets: [String] = []
        
        for preset in importedPresets {
            if validatePreset(preset) {
                validPresets.append(preset)
            } else {
                invalidPresets.append(preset.name)
            }
        }
        
        // Handle conflicts
        let builtInIds = Set(BuiltInPreset.allCases.map { $0.createPreset().id })
        var addedCount = 0
        var updatedCount = 0
        var skippedCount = 0
        
        for preset in validPresets {
            // Skip built-in presets
            if builtInIds.contains(preset.id) {
                skippedCount += 1
                continue
            }
            
            // Check for name conflicts
            if let existingPreset = presets.first(where: { $0.name == preset.name && !builtInIds.contains($0.id) }) {
                switch conflictResolution {
                case .skip:
                    skippedCount += 1
                    continue
                case .overwrite:
                    if let index = presets.firstIndex(where: { $0.id == existingPreset.id }) {
                        presets[index] = preset
                        updatedCount += 1
                    }
                case .rename:
                    // Generate unique name
                    var newName = preset.name
                    var counter = 1
                    while presets.contains(where: { $0.name == newName }) {
                        newName = "\(preset.name) (\(counter))"
                        counter += 1
                    }
                    var renamedPreset = preset
                    renamedPreset.name = newName
                    presets.append(renamedPreset)
                    addedCount += 1
                }
            } else {
                // No conflict, add preset
                presets.append(preset)
                addedCount += 1
            }
        }
        
        // Save after import
        savePresets()
        
        return ImportResult(
            total: importedPresets.count,
            added: addedCount,
            updated: updatedCount,
            skipped: skippedCount,
            invalid: invalidPresets.count,
            invalidNames: invalidPresets
        )
    }
    
    /// Import presets from file
    public func importPresets(from url: URL, format: ExportFormat? = nil, conflictResolution: ConflictResolution = .rename) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        
        // Auto-detect format from file extension
        let detectedFormat: ExportFormat
        if let format = format {
            detectedFormat = format
        } else {
            let ext = url.pathExtension.lowercased()
            detectedFormat = (ext == "plist") ? .plist : .json
        }
        
        return try importPresets(from: data, format: detectedFormat, conflictResolution: conflictResolution)
    }
    
    /// Validate preset structure
    private func validatePreset(_ preset: Preset) -> Bool {
        // Check required fields
        guard !preset.name.isEmpty else { return false }
        
        // Validate resolution format if present
        if let maxRes = preset.videoSettings?.maxResolution {
            let parsed = parseResolution(maxRes)
            if parsed.width == 0 && parsed.height == 0 {
                return false
            }
        }
        
        // Additional validation can be added here
        
        return true
    }
    
    public enum ExportFormat: String, Sendable {
        case json
        case plist
    }
    
    public enum ConflictResolution: String, Sendable {
        case skip      // Skip conflicting presets
        case overwrite // Overwrite existing presets
        case rename    // Rename imported presets
    }
    
    public struct ImportResult: Sendable {
        public let total: Int
        public let added: Int
        public let updated: Int
        public let skipped: Int
        public let invalid: Int
        public let invalidNames: [String]
    }
}
