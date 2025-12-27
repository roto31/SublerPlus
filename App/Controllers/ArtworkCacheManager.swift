import Foundation

public actor ArtworkCacheManager {
    private var cache: [URL: Data] = [:]
    private let maxBytes: Int

    public init(maxBytes: Int = 5 * 1024 * 1024) {
        self.maxBytes = maxBytes
    }

    public func fetchArtwork(from url: URL?, session: URLSession = .shared) async -> Data? {
        guard let url else { return nil }
        if let cached = cache[url] { return cached }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return nil }
            guard data.count <= maxBytes else { return nil }
            cache[url] = data
            return data
        } catch {
            return nil
        }
    }

    public func clear() {
        cache.removeAll()
    }
}

// Mapping MetadataDetails -> MP4 tags
public func mp4TagUpdates(from details: MetadataDetails, coverData: Data?) -> [String: Any] {
    var tags: [String: Any] = [
        "©nam": details.title,
        "©ART": details.performers.joined(separator: ", "),
        "©gen": details.tags.joined(separator: ", ")
    ]
    if let show = details.show { tags["tvsh"] = show }
    if let episodeID = details.episodeID { tags["tven"] = episodeID }
    if let season = details.seasonNumber { tags["tvsn"] = season }
    if let episode = details.episodeNumber { tags["tves"] = episode }
    if let sortTitle = details.sortTitle { tags["sonm"] = sortTitle }
    if let sortArtist = details.sortArtist { tags["soar"] = sortArtist }
    if let sortAlbum = details.sortAlbum { tags["soal"] = sortAlbum }
    if let track = details.trackNumber {
        tags["trkn"] = [track, details.trackTotal ?? 0]
    }
    if let disc = details.discNumber {
        tags["disk"] = [disc, details.discTotal ?? 0]
    }
    if let mediaKind = details.mediaKind {
        tags["stik"] = mediaKindCode(mediaKind)
    }
    if let isHD = details.isHD {
        tags["hdvd"] = isHD ? 1 : 0
    }
    if let isHEVC = details.isHEVC {
        tags["hevc"] = isHEVC ? 1 : 0
    }
    if let isHDR = details.isHDR {
        tags["hdrv"] = isHDR ? 1 : 0
    }
    if let releaseDate = details.releaseDate {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        tags["©day"] = formatter.string(from: releaseDate)
    }
    if let lyrics = details.lyrics {
        tags["©lyr"] = lyrics
    }
    if let advisory = details.contentRating {
        tags["rtng"] = advisory
    }
    if let gapless = details.isGapless {
        tags["pgap"] = gapless ? 1 : 0
    }
    if let compilation = details.isCompilation {
        tags["cpil"] = compilation ? 1 : 0
    }
    if let coverData {
        tags["covr"] = coverData
    }
    return tags
}

private func mediaKindCode(_ kind: MediaKind) -> Int {
    switch kind {
    case .movie: return 9
    case .tvShow: return 10
    case .musicVideo: return 6
    case .podcast: return 5
    case .audiobook: return 2
    case .shortFilm: return 12
    case .ringtone: return 14
    case .other: return 0
    case .unknown: return 0
    }
}

