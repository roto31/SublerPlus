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
}

// Mapping MetadataDetails -> MP4 tags
public func mp4TagUpdates(from details: MetadataDetails, coverData: Data?) -> [String: Any] {
    var tags: [String: Any] = [
        "©nam": details.title,
        "©ART": details.performers.joined(separator: ", "),
        "©gen": details.tags.joined(separator: ", ")
    ]
    if let releaseDate = details.releaseDate {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        tags["©day"] = formatter.string(from: releaseDate)
    }
    if let coverData {
        tags["covr"] = coverData
    }
    return tags
}

