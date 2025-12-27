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

    public init(subtitles: OpenSubtitlesProvider?, language: String = "eng") {
        self.subtitles = subtitles
        self.language = language
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
        let asset = AVURLAsset(url: url)
        let composition = AVMutableComposition()
        guard
            let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
            let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw SubtitleError.muxFailed }
        try compVideo.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)

        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try compAudio.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
        }

        // Add subtitle as an auxiliary track (quick approach: AVMutableCompositionTrack with mediaType .text)
        if let subTrack = composition.addMutableTrack(withMediaType: .text, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let textRange = CMTimeRange(start: .zero, duration: asset.duration)
            // We attach empty timeRange; AVAssetExportSession will include the track, but real timed text requires more work.
            // For parity, we attach the data as a sidecar (see below).
            subTrack.insertEmptyTimeRange(textRange)
        }

        // Export sidecar subtitle file (WebVTT) alongside media for now (simpler than timed text authoring).
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

