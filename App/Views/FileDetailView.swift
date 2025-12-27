import SwiftUI
import AppKit
import SublerPlusCore

struct FileDetailView: View {
    let file: URL
    let details: MetadataDetails?
    let job: Job?
    var onRefreshArtwork: (() -> Void)?
    var onApplyArtwork: ((URL) -> Void)?
    var tracks: [MediaTrack] = []
    var chapters: [Chapter] = []
    var subtitles: [SubtitleCandidate] = []
    var onSearchSubtitles: (() -> Void)?
    var onAttachSubtitle: ((SubtitleCandidate) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(file.deletingPathExtension().lastPathComponent)
                .font(.title2)
                .accessibilityLabel("Selected file \(file.lastPathComponent)")
            Text(file.path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([file])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(file.path, forType: .string)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            .accessibilityElement(children: .combine)

            if let job {
                HStack {
                    Label(job.status.rawValue.capitalized, systemImage: statusIcon(for: job.status))
                        .foregroundColor(color(for: job.status))
                    Text(job.message).font(.caption).foregroundColor(.secondary)
                }
                .accessibilityLabel("Job status \(job.status.rawValue)")
            }

            if let details {
                Divider()
                if let url = details.coverURL {
                    HStack {
                        Text("Artwork")
                            .font(.headline)
                        Spacer()
                        if onRefreshArtwork != nil {
                            Button("Refresh Artwork") {
                                onRefreshArtwork?()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityHint("Clear cache and reload artwork")
                        }
                    }
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 160, height: 90)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 260)
                                .cornerRadius(6)
                                .shadow(radius: 2)
                        case .failure:
                            Image(systemName: "photo")
                                .frame(width: 160, height: 90)
                                .foregroundColor(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                Text(details.title).font(.headline)
                if let synopsis = details.synopsis {
                    Text(synopsis).font(.body)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let show = details.show {
                        Text("Show: \(show)").font(.callout)
                    }
                    if let season = details.seasonNumber, let episode = details.episodeNumber {
                        Text("Season \(season) • Episode \(episode)").font(.callout)
                    } else if let season = details.seasonNumber {
                        Text("Season \(season)").font(.callout)
                    }
                    if let episodeID = details.episodeID {
                        Text("Episode ID: \(episodeID)").font(.caption)
                }
                if let studio = details.studio {
                    Text("Studio: \(studio)").font(.callout)
                }
                if !details.performers.isEmpty {
                    Text("Performers: \(details.performers.joined(separator: ", "))").font(.callout)
                }
                if !details.tags.isEmpty {
                    Text("Tags: \(details.tags.joined(separator: ", "))").font(.callout)
                }
                    if let dateText = formattedDate(details.releaseDate) {
                        Text("Release: \(dateText)").font(.callout)
                    }
                    if let track = details.trackNumber {
                        let total = details.trackTotal ?? 0
                        Text("Track: \(track)\(total > 0 ? "/\(total)" : "")").font(.callout)
                    }
                    if let disc = details.discNumber {
                        let total = details.discTotal ?? 0
                        Text("Disc: \(disc)\(total > 0 ? "/\(total)" : "")").font(.callout)
                    }
                    if let rating = details.rating {
                        Text(String(format: "Rating: %.2f", rating)).font(.callout)
                    }
                    if let advisory = details.contentRating {
                        Text("Content Rating: \(advisory)").font(.callout)
                    }
                    if let lyrics = details.lyrics, !lyrics.isEmpty {
                        Text("Lyrics: \(lyrics)").font(.callout)
                    }
                    if details.isCompilation == true {
                        Text("Compilation").font(.callout)
                    }
                    if details.isGapless == true {
                        Text("Gapless").font(.callout)
                    }
                    if let kind = details.mediaKind {
                        Text("Kind: \(kindLabel(kind))").font(.callout)
                    }
                    let flags: [String] = [
                        details.isHD == true ? "HD" : nil,
                        details.isHEVC == true ? "HEVC" : nil,
                        details.isHDR == true ? "HDR" : nil
                    ].compactMap { $0 }
                    if !flags.isEmpty {
                        Text("Flags: \(flags.joined(separator: ", "))").font(.callout)
                    }
                if let source = details.source {
                        Text("Provider: \(providerName(for: source))").font(.caption).foregroundColor(.secondary)
                    }
                    if let cover = details.coverURL {
                        Text("Artwork URL: \(cover.absoluteString)").font(.caption2).foregroundColor(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    if let sort = details.sortTitle {
                        Text("Sort Title: \(sort)").font(.caption2)
                    }
                    if let sortArtist = details.sortArtist {
                        Text("Sort Artist: \(sortArtist)").font(.caption2)
                    }
                    if let alternates = details.artworkAlternates, !alternates.isEmpty {
                        Divider()
                        Text("Alternate Artwork").font(.headline)
                        ForEach(alternates, id: \.self) { alt in
                            HStack {
                                Text(alt.absoluteString)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button("Apply") {
                                    onApplyArtwork?(alt)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                if !tracks.isEmpty {
                    Divider()
                    HStack {
                        Text("Tracks").font(.headline)
                        Spacer()
                        Text("\(tracks.count)").font(.caption).foregroundColor(.secondary)
                    }
                    let videoTracks = tracks.filter { $0.kind == .video }
                    let audioTracks = tracks.filter { $0.kind == .audio }
                    let subtitleTracks = tracks.filter { $0.kind == .subtitle }
                    let otherTracks = tracks.filter { ![.video, .audio, .subtitle].contains($0.kind) }
                    
                    if !videoTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Video").font(.subheadline).foregroundColor(.secondary)
                            ForEach(videoTracks, id: \.id) { track in
                                trackRow(track)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if !audioTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Audio").font(.subheadline).foregroundColor(.secondary)
                            ForEach(audioTracks, id: \.id) { track in
                                trackRow(track)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if !subtitleTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subtitles").font(.subheadline).foregroundColor(.secondary)
                            ForEach(subtitleTracks, id: \.id) { track in
                                trackRow(track)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if !otherTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Other").font(.subheadline).foregroundColor(.secondary)
                            ForEach(otherTracks, id: \.id) { track in
                                trackRow(track)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !chapters.isEmpty {
                    Divider()
                    HStack {
                        Text("Chapters").font(.headline)
                        Spacer()
                        Text("\(chapters.count)").font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(chapters.sorted { $0.startSeconds < $1.startSeconds }, id: \.id) { chapter in
                        HStack {
                            Text(formatTime(chapter.startSeconds)).font(.caption)
                            Text(chapter.title).font(.callout)
                            Spacer()
                        }
                    }
                }

                Divider()
                HStack {
                    Text("Subtitles").font(.headline)
                    Spacer()
                    Button("Search") { onSearchSubtitles?() }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Search subtitles from OpenSubtitles")
                }
                if subtitles.isEmpty {
                    Text("No subtitles found yet.").font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(subtitles, id: \.id) { sub in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(sub.title).font(.callout)
                                HStack(spacing: 6) {
                                    Text(sub.language).font(.caption).foregroundColor(.secondary)
                                    if let score = sub.score {
                                        Text(String(format: "Score: %.2f", score)).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Button("Attach") { onAttachSubtitle?(sub) }
                                .buttonStyle(.borderedProminent)
                                .accessibilityHint("Download and attach this subtitle")
                        }
                    }
                }
            } else {
                Text("No metadata written yet. Enrich this file to see details.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func color(for status: Job.Status) -> Color {
        switch status {
        case .queued: return .secondary
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .red
        }
    }

    private func statusIcon(for status: Job.Status) -> String {
        switch status {
        case .queued: return "clock"
        case .running: return "arrow.clockwise"
        case .succeeded: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private func formattedDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func providerName(for id: String) -> String {
        switch id.lowercased() {
        case "tmdb": return "TMDB"
        case "tvdb": return "TVDB"
        case "tpdb": return "ThePornDB"
        case "subler": return "Subler (local)"
        default: return id
        }
    }

    private func kindLabel(_ kind: MediaKind) -> String {
        switch kind {
        case .movie: return "Movie"
        case .tvShow: return "TV Show"
        case .musicVideo: return "Music Video"
        case .podcast: return "Podcast"
        case .audiobook: return "Audiobook"
        case .shortFilm: return "Short Film"
        case .ringtone: return "Ringtone"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
    
    @ViewBuilder
    private func trackRow(_ track: MediaTrack) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(track.codec ?? "Unknown Codec")
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer()
                if track.isDefault {
                    Label("Default", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                if track.isForced {
                    Label("Forced", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            HStack(spacing: 12) {
                if let lang = track.language {
                    Label(lang.uppercased(), systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let res = track.resolution {
                    Label(res, systemImage: "rectangle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let bitrate = track.bitrate {
                    Label("\(bitrate/1000) kbps", systemImage: "gauge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if track.hdr {
                    Label("HDR", systemImage: "sun.max.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

