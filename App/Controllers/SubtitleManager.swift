import Foundation
import AVFoundation

public struct SubtitleDownloadResult: Sendable {
    public let data: Data
    public let suggestedFilename: String
    public let language: String
    public let isVTT: Bool
}

public enum SubtitleError: Error {
    case invalidData
    case conversionFailed
    case muxFailed
}

public final class SubtitleManager: @unchecked Sendable {
    private let subtitles: OpenSubtitlesProvider?
    private let language: String
    private let fairPlayHandler = FairPlaySubtitleHandler()

    public init(subtitles: OpenSubtitlesProvider?, language: String = "eng") {
        self.subtitles = subtitles
        self.language = language
    }
    
    /// Check if subtitle codec is FairPlay-encrypted
    public func isFairPlaySubtitle(codec: String) -> Bool {
        return fairPlayHandler.isFairPlaySubtitle(codec: codec)
    }

    public func search(title: String, year: Int?) async -> [SubtitleCandidate] {
        guard let provider = subtitles else { return [] }
        do {
            return try await provider.search(title: title, year: year, language: language)
        } catch {
            return []
        }
    }

    public func download(candidate: SubtitleCandidate) async -> SubtitleDownloadResult? {
        guard let provider = subtitles else { return nil }
        do {
            let data = try await provider.downloadSubtitle(from: candidate.downloadURL)
            let isVTT = candidate.downloadURL.pathExtension.lowercased().contains("vtt")
            return SubtitleDownloadResult(
                data: data,
                suggestedFilename: candidate.title,
                language: candidate.language,
                isVTT: isVTT
            )
        } catch {
            return nil
        }
    }

    public func muxSubtitle(into url: URL, subtitle: SubtitleDownloadResult, forced: Bool = false) async throws {
        // Parse subtitle data to TX3G samples
        let samples: [TX3GSample]
        if subtitle.isVTT {
            samples = try TX3GEncoder.parseWebVTT(subtitle.data)
        } else {
            samples = try TX3GEncoder.parseSRT(subtitle.data)
        }
        
        guard !samples.isEmpty else {
            throw SubtitleError.invalidData
        }
        
        // Create composition with video/audio tracks
        let asset = AVURLAsset(url: url)
        let composition = AVMutableComposition()
        let duration = try await asset.load(.duration)
        
        guard
            let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
            let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw SubtitleError.muxFailed }
        try compVideo.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)

        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try compAudio.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
        }

        // Add subtitle as text track
        // Note: Full TX3G embedding requires low-level MP4 atom manipulation
        // For now, we'll use AVFoundation's text track support and post-process with AtomCodec
        if let subTrack = composition.addMutableTrack(withMediaType: .text, preferredTrackID: kCMPersistentTrackID_Invalid) {
            // Insert timed text samples
            for sample in samples {
                let timeRange = CMTimeRange(start: sample.startTime, duration: sample.duration)
                // AVFoundation doesn't directly support adding text samples to composition
                // We'll need to use a different approach or post-process the MP4
                subTrack.insertEmptyTimeRange(timeRange)
            }
        }

        // Export to temporary file
        let tempURL = url.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).mp4")
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw SubtitleError.muxFailed
        }
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mp4
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw SubtitleError.muxFailed
        }
        
        // Embed TX3G track using TX3GTrackBuilder
        do {
            // Find next available track ID
            let asset = AVURLAsset(url: tempURL)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            let subtitleTracks = try await asset.loadTracks(withMediaType: .subtitle)
            let allTracks = videoTracks + audioTracks + subtitleTracks
            let maxTrackID = allTracks.map { $0.trackID }.max() ?? 0
            let nextTrackID = UInt32(maxTrackID + 1)
            
            // Add TX3G track to the exported file
            try TX3GTrackBuilder.addTX3GTrack(
                to: tempURL,
                samples: samples,
                language: subtitle.language,
                trackID: nextTrackID,
                timescale: 600,
                style: .default
            )
            
            // Replace original with file containing embedded TX3G track
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            // Fallback to sidecar approach if TX3G embedding fails
            let vttData: Data
            if subtitle.isVTT {
                vttData = subtitle.data
            } else if let converted = srtToVtt(subtitle.data) {
                vttData = converted
            } else {
                throw SubtitleError.conversionFailed
            }
            let sidecarURL = url.deletingPathExtension().appendingPathExtension("\(subtitle.language).vtt")
            try vttData.write(to: sidecarURL, options: .atomic)
            
            // Replace original with temp file
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        }
    }

    private func srtToVtt(_ data: Data) -> Data? {
        guard let s = String(data: data, encoding: .utf8) else { return nil }
        var lines: [String] = ["WEBVTT"]
        // Use components(separatedBy:) for macOS 12 compatibility
        let parts = s.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n\n")
        let tsRegex = try? NSRegularExpression(pattern: #"(\d{2}):(\d{2}):(\d{2}),(\d{3}) --> (\d{2}):(\d{2}):(\d{2}),(\d{3})"#)
        for block in parts {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            var linesBlock = trimmed.split(separator: "\n").map(String.init)
            if linesBlock.count >= 2 {
                // Drop numeric index if present
                if Int(linesBlock[0]) != nil { linesBlock.removeFirst() }
                if let first = linesBlock.first,
                   let tsRegex,
                   tsRegex.firstMatch(in: first, range: NSRange(location: 0, length: first.utf16.count)) != nil {
                    let vttTs = first.replacingOccurrences(of: ",", with: ".")
                    lines.append(vttTs)
                    lines.append(contentsOf: linesBlock.dropFirst())
                    lines.append("") // blank line
                }
            }
        }
        return lines.joined(separator: "\n").data(using: .utf8)
    }
}

