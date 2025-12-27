import Foundation
import AVFoundation

public enum AudioConversionError: Error, Equatable {
    case unsupportedCodec(String)
    case conversionFailed(String)
    case ffmpegNotAvailable
    case invalidInput
}

/// Audio conversion engine supporting multiple codecs
/// Uses AVFoundation for AAC encoding (native) and FFmpeg for other formats
public final class AudioConverter: @unchecked Sendable {
    
    public init() {}
    
    /// Convert audio track to target codec
    public func convert(
        input: URL,
        output: URL,
        settings: AudioConversionSettings,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        guard settings.targetCodec != .passthrough else {
            // Just copy the file
            try FileManager.default.copyItem(at: input, to: output)
            return
        }
        
        // Use AVFoundation for AAC (native, faster)
        if settings.targetCodec == .aac {
            try await convertWithAVFoundation(
                input: input,
                output: output,
                settings: settings,
                progressHandler: progressHandler
            )
        } else if settings.targetCodec == .mlp {
            // MLP typically needs conversion to AC3 for compatibility
            // Create AC3 conversion settings
            var ac3Settings = settings
            ac3Settings.targetCodec = .ac3
            try await convertWithFFmpeg(
                input: input,
                output: output,
                settings: ac3Settings,
                progressHandler: progressHandler
            )
        } else {
            // Use FFmpeg for other codecs (AC3, etc.)
            try await convertWithFFmpeg(
                input: input,
                output: output,
                settings: settings,
                progressHandler: progressHandler
            )
        }
    }
    
    /// Convert using AVFoundation (for AAC)
    private func convertWithAVFoundation(
        input: URL,
        output: URL,
        settings: AudioConversionSettings,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        let asset = AVURLAsset(url: input)
        
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioConversionError.invalidInput
        }
        
        let composition = AVMutableComposition()
        guard let compTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioConversionError.conversionFailed("Could not create composition track")
        }
        
        let duration = try await asset.load(.duration)
        try compTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
        
        // Create audio mix for DRC if needed
        let audioMix = AVMutableAudioMix()
        if let drc = settings.drc {
            let audioMixInputParams = AVMutableAudioMixInputParameters(track: compTrack)
            audioMixInputParams.setVolumeRamp(fromStartVolume: Float(1.0 - drc), toEndVolume: Float(1.0 - drc), timeRange: CMTimeRange(start: .zero, duration: duration))
            audioMix.inputParameters = [audioMixInputParams]
        }
        
        // Export settings
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioConversionError.conversionFailed("Could not create export session")
        }
        
        exportSession.outputURL = output
        exportSession.outputFileType = .m4a
        exportSession.audioMix = audioMix
        
        // Set audio settings
        var audioSettings: [String: Any] = [:]
        audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        
        if let bitrate = settings.bitrate {
            audioSettings[AVEncoderBitRateKey] = bitrate * 1000 // Convert kbps to bps
        }
        
        if let sampleRate = settings.sampleRate {
            audioSettings[AVSampleRateKey] = sampleRate
        }
        
        // Mixdown settings
        let channelCount = getChannelCount(for: settings.mixdown, originalTrack: audioTrack)
        if channelCount > 0 {
            audioSettings[AVNumberOfChannelsKey] = channelCount
        }
        
        exportSession.audioTimePitchAlgorithm = .timeDomain
        
        // Monitor progress
        let progressTask = Task.detached {
            while exportSession.status == .exporting {
                await MainActor.run {
                    progressHandler?(Double(exportSession.progress))
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        await exportSession.export()
        progressTask.cancel()
        
        guard exportSession.status == .completed else {
            throw AudioConversionError.conversionFailed(exportSession.error?.localizedDescription ?? "Export failed")
        }
        
        await MainActor.run {
            progressHandler?(1.0)
        }
    }
    
    /// Convert using FFmpeg (for non-AAC codecs)
    private func convertWithFFmpeg(
        input: URL,
        output: URL,
        settings: AudioConversionSettings,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        guard await FFmpegWrapper.isAvailable() else {
            throw AudioConversionError.ffmpegNotAvailable
        }
        
        // Build FFmpeg command
        var args: [String] = [
            "-i", input.path,
            "-vn", // No video
            "-c:a", settings.targetCodec.rawValue
        ]
        
        // Bitrate
        if let bitrate = settings.bitrate {
            args.append(contentsOf: ["-b:a", "\(bitrate)k"])
        }
        
        // Sample rate
        if let sampleRate = settings.sampleRate {
            args.append(contentsOf: ["-ar", "\(sampleRate)"])
        }
        
        // Mixdown
        let channelLayout = getFFmpegChannelLayout(for: settings.mixdown)
        if let layout = channelLayout {
            args.append(contentsOf: ["-ac", layout])
        }
        
        // DRC (if supported by codec)
        if let drc = settings.drc, settings.targetCodec == .ac3 {
            // AC3 supports DRC via dialnorm
            let dialnorm = Int32((1.0 - drc) * 31) // 0-31 range
            args.append(contentsOf: ["-dialnorm", "\(dialnorm)"])
        }
        
        args.append(contentsOf: [
            "-y", // Overwrite
            output.path
        ])
        
        try await FFmpegWrapper.convertAudio(
            input: input,
            output: output,
            codec: settings.targetCodec.rawValue,
            bitrate: settings.bitrate,
            progressHandler: progressHandler
        )
    }
    
    /// Get channel count for mixdown setting
    private func getChannelCount(for mixdown: AudioConversionSettings.Mixdown, originalTrack: AVAssetTrack) -> Int {
        switch mixdown {
        case .mono: return 1
        case .stereo: return 2
        case .dolby: return 6 // 5.1
        case .dolbyProLogicII: return 2 // Stereo with Pro Logic encoding
        case .auto:
            // Try to get from original track format
            // Use track's natural channel count if available
            let channelCount = originalTrack.mediaType == .audio ? Int(originalTrack.naturalSize.width) : 0
            if channelCount > 0 {
                return channelCount
            }
            return 2 // Default to stereo
        }
    }
    
    /// Get FFmpeg channel layout argument
    private func getFFmpegChannelLayout(for mixdown: AudioConversionSettings.Mixdown) -> String? {
        switch mixdown {
        case .mono: return "1"
        case .stereo: return "2"
        case .dolby: return "6"
        case .dolbyProLogicII: return "2"
        case .auto: return nil // Keep original
        }
    }
}

