import Foundation
import AVFoundation

public enum MuxerError: Error, Equatable {
    case invalidInput
    case noTracks
    case compositionFailed
    case exportFailed(String)
    case fileWriteFailed
    case audioConversionFailed(String)
}

public final class Muxer: @unchecked Sendable {
    private static let audioConverter = AudioConverter()
    
    /// Remux a file (convert container format while preserving tracks)
    public static func remux(
        sourceURL: URL,
        outputURL: URL,
        options: MuxingOptions = MuxingOptions(),
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        // Extract tracks from source
        let tracks = try await ContainerImporter.extractTracks(from: sourceURL)
        
        // Create track selections (all selected by default)
        let trackSelections = tracks.map { track in
            TrackSelection(track: track, sourceURL: sourceURL, selected: true)
        }
        
        // Mux with selected tracks
        try await mux(
            tracks: trackSelections,
            outputURL: outputURL,
            options: options,
            progressHandler: progressHandler
        )
    }
    
    /// Mux selected tracks from one or more sources
    public static func mux(
        tracks: [TrackSelection],
        outputURL: URL,
        options: MuxingOptions = MuxingOptions(),
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        guard !tracks.isEmpty else {
            throw MuxerError.noTracks
        }
        
        // Convert audio tracks if needed
        let convertedTracks = try await convertAudioTracksIfNeeded(
            tracks: tracks,
            options: options
        )
        
        // Create composition
        let composition = try await TrackComposition.createComposition(
            tracks: convertedTracks,
            options: options
        )
        
        // Determine export preset
        let preset = options.optimize ? AVAssetExportPresetHighestQuality : AVAssetExportPresetPassthrough
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: preset) else {
            throw MuxerError.exportFailed("Unable to create export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = determineOutputFileType(for: outputURL)
        
        // Set up progress monitoring
        // Note: AVAssetExportSession is not Sendable, but we access it only on MainActor
        if let progressHandler = progressHandler {
            Task { @MainActor in
                while exportSession.status == .waiting || exportSession.status == .exporting {
                    let currentProgress = exportSession.progress
                    progressHandler(Double(currentProgress))
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
        }
        
        await exportSession.export()
        
        // Final progress update
        if let progressHandler = progressHandler {
            await MainActor.run {
                progressHandler(1.0)
            }
        }
        
        // Check export status
        guard exportSession.status == .completed else {
            let errorMsg = exportSession.error?.localizedDescription ?? "Unknown error"
            throw MuxerError.exportFailed(errorMsg)
        }
        
        // Post-process: preserve HDR/Dolby Vision metadata
        try await preserveVideoMetadata(
            from: tracks,
            to: outputURL,
            composition: composition
        )
        
        // Post-process: update brand atoms for output format
        let outputFormat = determineOutputFormat(for: outputURL)
        try MP4BrandHandler.updateBrands(at: outputURL, format: outputFormat)
        
        // Post-process: optimize atoms if requested
        if options.optimize {
            try optimizeMP4Atoms(at: outputURL)
        }
    }
    
    /// Determine output file type from URL extension
    private static func determineOutputFileType(for url: URL) -> AVFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4v": return .m4v
        case "m4a": return .m4a
        case "m4b": return .m4a // M4B uses same file type as M4A
        case "m4r": return .m4a // M4R uses same file type as M4A
        default: return .mp4
        }
    }
    
    /// Determine output format from URL extension
    private static func determineOutputFormat(for url: URL) -> MP4BrandHandler.OutputFormat {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4v": return .m4v
        case "m4a": return .m4a
        case "m4b": return .m4b
        case "m4r": return .m4r
        default: return .mp4
        }
    }
    
    /// Add tracks to an existing MP4 file
    public static func addTracks(
        to fileURL: URL,
        tracks: [TrackSelection],
        outputURL: URL,
        options: MuxingOptions = MuxingOptions(),
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        // Extract existing tracks
        let existingTracks = try await ContainerImporter.extractTracks(from: fileURL)
        let existingSelections = existingTracks.map { track in
            TrackSelection(track: track, sourceURL: fileURL, selected: true)
        }
        
        // Combine with new tracks
        let allTracks = existingSelections + tracks
        
        // Mux everything together
        try await mux(
            tracks: allTracks,
            outputURL: outputURL,
            options: options,
            progressHandler: progressHandler
        )
    }
    
    /// Remove tracks from an MP4 file
    public static func removeTracks(
        from fileURL: URL,
        trackIDs: Set<UUID>,
        outputURL: URL,
        options: MuxingOptions = MuxingOptions(),
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        // Extract all tracks
        let allTracks = try await ContainerImporter.extractTracks(from: fileURL)
        
        // Create selections, deselecting tracks to remove
        let trackSelections = allTracks.map { track in
            TrackSelection(
                track: track,
                sourceURL: fileURL,
                selected: !trackIDs.contains(track.id)
            )
        }
        
        // Mux with selected tracks only
        try await mux(
            tracks: trackSelections,
            outputURL: outputURL,
            options: options,
            progressHandler: progressHandler
        )
    }
    
    /// Convert audio tracks if conversion settings are specified
    private static func convertAudioTracksIfNeeded(
        tracks: [TrackSelection],
        options: MuxingOptions
    ) async throws -> [TrackSelection] {
        var convertedTracks: [TrackSelection] = []
        let tempDir = FileManager.default.temporaryDirectory
        
        for trackSelection in tracks {
            guard trackSelection.selected,
                  trackSelection.track.kind == .audio else {
                convertedTracks.append(trackSelection)
                continue
            }
            
            // Check if conversion is needed
            let conversionSettings = trackSelection.conversionSettings ?? options.defaultAudioSettings
            
            guard let settings = conversionSettings,
                  settings.targetCodec != .passthrough else {
                convertedTracks.append(trackSelection)
                continue
            }
            
            // Check if codec already matches
            if let currentCodec = trackSelection.track.codec?.lowercased(),
               currentCodec == settings.targetCodec.rawValue.lowercased() {
                convertedTracks.append(trackSelection)
                continue
            }
            
            // Convert audio track
            let tempOutput = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")
            
            do {
                try await audioConverter.convert(
                    input: trackSelection.sourceURL,
                    output: tempOutput,
                    settings: settings
                )
                
                // Create new track selection with converted file
                let convertedTracksList = try await ContainerImporter.extractTracks(from: tempOutput)
                if let convertedTrack = convertedTracksList.first(where: { $0.kind == .audio }) {
                    let newSelection = TrackSelection(
                        id: trackSelection.id,
                        track: convertedTrack,
                        sourceURL: tempOutput,
                        selected: true,
                        conversionSettings: nil // Already converted
                    )
                    convertedTracks.append(newSelection)
                } else {
                    throw MuxerError.audioConversionFailed("No audio track found in converted file")
                }
            } catch {
                throw MuxerError.audioConversionFailed(error.localizedDescription)
            }
        }
        
        return convertedTracks
    }
    
    /// Preserve HDR and Dolby Vision metadata from source tracks
    private static func preserveVideoMetadata(
        from tracks: [TrackSelection],
        to outputURL: URL,
        composition: AVMutableComposition
    ) async throws {
        let hdrHandler = HDRMetadataHandler()
        let dolbyHandler = DolbyVisionHandler()
        
        // Find video tracks in source
        for trackSelection in tracks where trackSelection.selected && trackSelection.track.kind == .video {
            let asset = AVURLAsset(url: trackSelection.sourceURL)
            if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
                // Check for HDR
                if hdrHandler.isHDR(track: videoTrack) {
                    // HDR metadata should be preserved by AVFoundation passthrough
                    // Log for verification
                    print("HDR metadata detected and should be preserved")
                }
                
                // Check for Dolby Vision
                if dolbyHandler.isDolbyVision(track: videoTrack) {
                    // Extract Dolby Vision metadata
                    if let dvMetadata = try? await dolbyHandler.extractDolbyVisionMetadata(from: videoTrack) {
                        // Check for enhancement layer
                        if dvMetadata.elPresentFlag {
                            // Look for enhancement layer track
                            let allVideoTracks = try await asset.loadTracks(withMediaType: .video)
                            let assetDuration = try await asset.load(.duration)
                            for elTrack in allVideoTracks where elTrack != videoTrack {
                                // Check if this is an enhancement layer track
                                if dolbyHandler.isDolbyVision(track: elTrack) {
                                    // Find corresponding composition track
                                    if let compVideoTrack = composition.tracks.first(where: { $0.mediaType == .video }) {
                                        // Preserve enhancement layer
                                        _ = try? dolbyHandler.preserveEnhancementLayer(
                                            elTrack: elTrack,
                                            in: composition,
                                            groupedWith: compVideoTrack,
                                            duration: assetDuration
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Dolby Vision metadata should be preserved by AVFoundation passthrough
                        print("Dolby Vision metadata detected: Profile \(dvMetadata.profile ?? 0), Level \(dvMetadata.level ?? 0), RPU: \(dvMetadata.rpuPresentFlag), EL: \(dvMetadata.elPresentFlag)")
                    }
                }
            }
        }
    }
    
    /// Optimize MP4 atoms (reorder, compact, remove unused)
    private static func optimizeMP4Atoms(at url: URL) throws {
        // Read file data
        let fileData = try Data(contentsOf: url)
        
        // Find key atoms using AtomCodec.findAtom
        guard let ftypAtom = AtomCodec.findAtom(in: fileData, type: "ftyp", start: 0, length: fileData.count),
              let moovAtom = AtomCodec.findAtom(in: fileData, type: "moov", start: 0, length: fileData.count),
              let mdatAtom = AtomCodec.findAtom(in: fileData, type: "mdat", start: 0, length: fileData.count) else {
            // If we can't find required atoms, skip optimization
            return
        }
        
        // Check if moov is already before mdat
        if moovAtom.offset < mdatAtom.offset {
            // Already optimized order, but we can still compact
            try compactMP4Atoms(at: url, fileData: fileData)
            return
        }
        
        // Reorder: moov should be before mdat for streaming
        var optimizedData = Data()
        
        // 1. Write ftyp atom
        optimizedData.append(fileData[ftypAtom.offset..<ftypAtom.offset + ftypAtom.size])
        
        // 2. Write moov atom (before mdat)
        optimizedData.append(fileData[moovAtom.offset..<moovAtom.offset + moovAtom.size])
        
        // 3. Write mdat atom
        optimizedData.append(fileData[mdatAtom.offset..<mdatAtom.offset + mdatAtom.size])
        
        // 4. Write any remaining atoms (free, skip, etc.) but skip unused ones
        let remainingRange = mdatAtom.offset + mdatAtom.size..<fileData.endIndex
        if !remainingRange.isEmpty {
            // Parse and filter remaining atoms
            var offset = remainingRange.lowerBound
            while offset < remainingRange.upperBound {
                guard offset + 8 <= fileData.endIndex else { break }
                
                let atomSize = fileData.withUnsafeBytes { bytes in
                    UInt32(bigEndian: bytes.load(fromByteOffset: offset, as: UInt32.self))
                }
                
                guard atomSize > 0 && offset + Int(atomSize) <= fileData.endIndex else { break }
                
                let atomType = String(data: fileData[offset + 4..<offset + 8], encoding: .ascii) ?? ""
                
                // Skip free/skip atoms (unused space)
                if atomType != "free" && atomType != "skip" {
                    optimizedData.append(fileData[offset..<offset + Int(atomSize)])
                }
                
                offset += Int(atomSize)
            }
        }
        
        // Write optimized data to temporary file
        let tempURL = url.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).mp4")
        try optimizedData.write(to: tempURL)
        
        // Replace original file
        let fileManager = FileManager.default
        _ = try fileManager.replaceItem(at: url, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
    }
    
    /// Compact MP4 atoms (remove free/skip atoms, unused atoms)
    private static func compactMP4Atoms(at url: URL, fileData: Data) throws {
        var compactedData = Data()
        var offset = 0
        
        while offset < fileData.count {
            guard offset + 8 <= fileData.count else { break }
            
            let atomSize = fileData.withUnsafeBytes { bytes in
                UInt32(bigEndian: bytes.load(fromByteOffset: offset, as: UInt32.self))
            }
            
            guard atomSize > 0 && offset + Int(atomSize) <= fileData.count else { break }
            
            let atomType = String(data: fileData[offset + 4..<offset + 8], encoding: .ascii) ?? ""
            
            // Skip free/skip atoms (unused space)
            if atomType != "free" && atomType != "skip" {
                compactedData.append(fileData[offset..<offset + Int(atomSize)])
            }
            
            offset += Int(atomSize)
        }
        
        // Write compacted data to temporary file
        let tempURL = url.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).mp4")
        try compactedData.write(to: tempURL)
        
        // Replace original file
        let fileManager = FileManager.default
        _ = try fileManager.replaceItem(at: url, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
    }
}

