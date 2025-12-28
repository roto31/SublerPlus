import Foundation
import AVFoundation
import UniformTypeIdentifiers

public enum MetadataError: Error, Equatable {
    case unsupportedFileType
    case noProviderMatch
    case retainOriginalsCopyFailed
    case trackInspectionFailed
}

public enum ProviderPreference: String, Codable, Sendable {
    case balanced
    case scoreFirst
    case yearFirst
}

/// Provider weighting configuration for search result boosting
public struct ProviderWeights: Codable, Sendable {
    public var weights: [String: Double] // providerID -> boost factor
    
    // Note: defaultWeight is not stored/decoded, it's a constant
    public var defaultWeight: Double { 1.0 }
    
    public init(weights: [String: Double] = [:]) {
        self.weights = weights
    }
    
    /// Get weight for a provider, returning default if not specified
    public func weight(for providerID: String) -> Double {
        weights[providerID] ?? defaultWeight
    }
    
    /// Set weight for a provider
    public mutating func setWeight(_ weight: Double, for providerID: String) {
        weights[providerID] = weight
    }
    
    /// Initialize with default weights for known providers
    public static func defaults() -> ProviderWeights {
        let weights = ProviderWeights()
        // Set default weight of 1.0 for all known providers (no boost by default)
        // Users can customize these in settings
        return weights
    }
}

public protocol MP4Handler: Sendable {
    func readMetadata(at url: URL) throws -> MetadataHint
    func writeMetadata(_ metadata: MetadataDetails, tags: [String: Any], to url: URL) throws
}

public final class SublerMP4Handler: MP4Handler {
    public init() {}

    public func readMetadata(at url: URL) throws -> MetadataHint {
        let asset = AVURLAsset(url: url)
        let title = firstString(in: asset.metadata, identifiers: [
            .commonIdentifierTitle,
            .iTunesMetadataSongName
        ]) ?? url.deletingPathExtension().lastPathComponent

        let yearString = firstString(in: asset.metadata, identifiers: [
            .commonIdentifierCreationDate,
            .iTunesMetadataReleaseDate
        ])
        let year = yearString.flatMap { Int(String($0.prefix(4))) }

        let artist = firstString(in: asset.metadata, identifiers: [
            .commonIdentifierArtist,
            .iTunesMetadataArtist
        ])
        let performers = artist?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return MetadataHint(title: title, year: year, performers: performers)
    }
    
    public func readFullMetadata(at url: URL) throws -> MetadataDetails? {
        let asset = AVURLAsset(url: url)
        let metadata = asset.metadata
        
        // Extract title
        let title = firstString(in: metadata, identifiers: [
            .commonIdentifierTitle,
            .iTunesMetadataSongName
        ]) ?? url.deletingPathExtension().lastPathComponent
        
        // Extract synopsis/description
        let synopsis = firstString(in: metadata, identifiers: [
            .commonIdentifierDescription,
            .iTunesMetadataDescription,
            .quickTimeMetadataDescription
        ])
        
        // Extract studio/network
        let studio = firstString(in: metadata, identifiers: [
            .iTunesMetadataPublisher,
            .quickTimeMetadataPublisher,
            .commonIdentifierPublisher
        ])
        
        // Extract release date
        let releaseDateString = firstString(in: metadata, identifiers: [
            .commonIdentifierCreationDate,
            .iTunesMetadataReleaseDate,
            .quickTimeMetadataCreationDate
        ])
        let releaseDate = releaseDateString.flatMap { parseDate($0) }
        
        // Extract performers/actors
        let artist = firstString(in: metadata, identifiers: [
            .commonIdentifierArtist,
            .iTunesMetadataArtist
        ])
        let performers = artist?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        
        // Extract tags/genres
        var tags: [String] = []
        if let genre = firstString(in: metadata, identifiers: [
            .quickTimeMetadataGenre,
            .iTunesMetadataUserGenre,
            .commonIdentifierType
        ]) {
            tags.append(genre)
        }
        
        // Extract metadata from MP4 atoms (TV show info, rating, etc.)
        var atomTags: [String: Any] = [:]
        do {
            atomTags = try AtomCodec.readIlst(from: url)
        } catch {
            // Best effort - if atom parsing fails, continue with AVFoundation metadata only
        }
        
        // Extract rating from atoms (rtng atom)
        let rating: Double? = {
            if let rtngValue = atomTags["rtng"] as? Int32 {
                return Double(rtngValue)
            }
            return nil
        }()
        
        // Extract TV show info from atoms
        let show = atomTags["tvsh"] as? String
        let seasonNumber: Int? = {
            if let tvsnValue = atomTags["tvsn"] as? Int32 {
                return Int(tvsnValue)
            }
            return nil
        }()
        let episodeNumber: Int? = {
            if let tvesValue = atomTags["tves"] as? Int32 {
                return Int(tvesValue)
            }
            return nil
        }()
        let episodeID = atomTags["tven"] as? String
        
        // Extract media kind
        let mediaKindString = firstString(in: metadata, identifiers: [
            .iTunesMetadataContentRating,
            .commonIdentifierType
        ])
        let mediaKind = mediaKindString.flatMap { MediaKind(rawValue: $0.lowercased()) }
        
        // Extract content rating
        let contentRating = firstString(in: metadata, identifiers: [
            .iTunesMetadataContentRating
        ]).flatMap { Int($0) }
        
        // Extract lyrics
        let lyrics = firstString(in: metadata, identifiers: [
            .iTunesMetadataLyrics
        ])
        
        // Extract track/disc info (for music) - try atoms first, then AVFoundation
        let trackNumber: Int? = {
            if let trknPair = atomTags["trkn"] as? [Int], trknPair.count >= 1 {
                return trknPair[0]
            }
            return firstString(in: metadata, identifiers: [
                .iTunesMetadataTrackNumber
            ]).flatMap { Int($0) }
        }()
        
        let trackTotal: Int? = {
            if let trknPair = atomTags["trkn"] as? [Int], trknPair.count >= 2 {
                return trknPair[1]
            }
            return nil
        }()
        
        let discNumber: Int? = {
            if let diskPair = atomTags["disk"] as? [Int], diskPair.count >= 1 {
                return diskPair[0]
            }
            return firstString(in: metadata, identifiers: [
                .iTunesMetadataDiscNumber
            ]).flatMap { Int($0) }
        }()
        
        let discTotal: Int? = {
            if let diskPair = atomTags["disk"] as? [Int], diskPair.count >= 2 {
                return diskPair[1]
            }
            return nil
        }()
        
        // Extract media kind from atoms (stik atom)
        let mediaKindFromAtoms: MediaKind? = {
            if let stikValue = atomTags["stik"] as? Int32 {
                return mediaKindFromStik(Int(stikValue))
            }
            return nil
        }()
        
        // Use atom media kind if available, otherwise fall back to AVFoundation
        let finalMediaKind = mediaKindFromAtoms ?? mediaKind
        
        // Generate ID from file URL
        let id = url.absoluteString
        
        // Extract additional metadata from atoms
        let sortTitle = atomTags["sonm"] as? String
        let sortArtist = atomTags["soar"] as? String
        let sortAlbum = atomTags["soal"] as? String
        
        // Extract HD/HEVC/HDR flags from atoms
        let isHD: Bool? = {
            if let hdvdValue = atomTags["hdvd"] as? Int32 {
                return hdvdValue != 0
            }
            return nil
        }()
        
        let isHEVC: Bool? = {
            if let hevcValue = atomTags["hevc"] as? Int32 {
                return hevcValue != 0
            }
            return nil
        }()
        
        let isHDR: Bool? = {
            if let hdrvValue = atomTags["hdrv"] as? Int32 {
                return hdrvValue != 0
            }
            return nil
        }()
        
        let isGapless: Bool? = {
            if let pgapValue = atomTags["pgap"] as? Int32 {
                return pgapValue != 0
            }
            return nil
        }()
        
        let isCompilation: Bool? = {
            if let cpilValue = atomTags["cpil"] as? Int32 {
                return cpilValue != 0
            }
            return nil
        }()
        
        return MetadataDetails(
            id: id,
            title: title,
            synopsis: synopsis,
            releaseDate: releaseDate,
            studio: studio,
            tags: tags,
            performers: performers,
            coverURL: nil, // Artwork will be extracted separately
            rating: rating,
            source: "file",
            show: show,
            episodeID: episodeID,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            mediaKind: finalMediaKind,
            sortTitle: sortTitle,
            sortArtist: sortArtist,
            sortAlbum: sortAlbum,
            trackNumber: trackNumber,
            trackTotal: trackTotal,
            discNumber: discNumber,
            discTotal: discTotal,
            isHD: isHD,
            isHEVC: isHEVC,
            isHDR: isHDR,
            artworkAlternates: nil,
            lyrics: lyrics,
            contentRating: contentRating,
            isGapless: isGapless,
            isCompilation: isCompilation
        )
    }
    
    /// Convert stik (media kind) atom value to MediaKind enum
    private func mediaKindFromStik(_ stik: Int) -> MediaKind? {
        // stik values: 0=Movie, 1=Normal, 2=AudioBook, 5=Whacked Bookmark, 6=Music Video, 9=Short Film, 10=TV Show, 11=Booklet, 14=Ringtone
        switch stik {
        case 0: return .movie
        case 2: return .audiobook
        case 6: return .musicVideo
        case 9: return .shortFilm
        case 10: return .tvShow
        case 14: return .ringtone
        default: return nil
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                f.timeZone = TimeZone(abbreviation: "UTC")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
    
    public func extractArtwork(from url: URL) throws -> URL? {
        let asset = AVURLAsset(url: url)
        let metadata = asset.metadata
        
        // Look for artwork in metadata
        let artworkItems = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork)
        if artworkItems.isEmpty {
            // Try iTunes artwork
            let itunesArtwork = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .iTunesMetadataCoverArt)
            if let item = itunesArtwork.first,
               let data = item.dataValue {
                return saveArtworkToTempFile(data: data)
            }
        } else if let item = artworkItems.first,
                  let data = item.dataValue {
            return saveArtworkToTempFile(data: data)
        }
        
        return nil
    }
    
    private func saveArtworkToTempFile(data: Data) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")
        
        do {
            try data.write(to: tempFile)
            return tempFile
        } catch {
            return nil
        }
    }

    public func writeMetadata(_ metadata: MetadataDetails, tags: [String: Any], to url: URL) throws {
        let asset = AVURLAsset(url: url)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw NSError(domain: "SublerMP4Handler", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create export session"])
        }

        var items: [AVMutableMetadataItem] = []

        if let title = tags["©nam"] as? String {
            items.append(makeStringItem(.commonIdentifierTitle, value: title))
        }
        if let artist = tags["©ART"] as? String {
            items.append(makeStringItem(.commonIdentifierArtist, value: artist))
            items.append(makeStringItem(.iTunesMetadataArtist, value: artist))
        }
        if let genre = tags["©gen"] as? String {
            items.append(makeStringItem(.quickTimeMetadataGenre, value: genre))
            items.append(makeStringItem(.iTunesMetadataUserGenre, value: genre))
        }
        if let day = tags["©day"] as? String {
            items.append(makeStringItem(.quickTimeMetadataCreationDate, value: day))
            items.append(makeStringItem(.commonIdentifierCreationDate, value: day))
        }
        if let cover = tags["covr"] as? Data {
            items.append(makeDataItem(.commonIdentifierArtwork, value: cover))
            items.append(makeDataItem(.iTunesMetadataCoverArt, value: cover))
        }

        exportSession.metadata = items
        let tempURL = url.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).mp4")
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mp4

        try FileManager.default.removeItem(at: tempURL)
        // ignore failure if not exists

        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?
        exportSession.exportAsynchronously {
            if let err = exportSession.error {
                exportError = err
            } else if exportSession.status != .completed {
                exportError = NSError(domain: "SublerMP4Handler", code: 4, userInfo: [NSLocalizedDescriptionKey: "Export failed with status \(exportSession.status)"])
            }
            semaphore.signal()
        }
        semaphore.wait()
        if let exportError {
            throw exportError
        }

        // Replace original file atomically
        do {
            try AtomCodec.updateIlst(at: tempURL, tags: tags)
        } catch {
            // Best-effort; ignore atom failures to keep file intact
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }

    private func firstString(in metadata: [AVMetadataItem], identifiers: [AVMetadataIdentifier]) -> String? {
        for identifier in identifiers {
            if let item = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier).first,
               let value = item.stringValue, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func makeStringItem(_ identifier: AVMetadataIdentifier, value: String) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }

    private func makeDataItem(_ identifier: AVMetadataIdentifier, value: Data) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSData
        return item
    }
}

public struct AppSettings: Codable {
    public var adultEnabled: Bool
    public var tpdbConfidence: Double
    public var lastKeyRotation: Date?
    public var retainOriginals: Bool
    public var outputDirectory: String?
    public var generateNFO: Bool
    public var nfoOutputDirectory: String?
    public var tvNamingTemplate: String
    public var watchFolders: [String]
    public var defaultSubtitleLanguage: String
    public var autoSubtitleLookup: Bool
    public var iTunesCountry: String
    public var preferHighResArtwork: Bool
    public var enableMusicMetadata: Bool
    public var providerWeights: ProviderWeights

    public init(adultEnabled: Bool = false, tpdbConfidence: Double = 0.5, lastKeyRotation: Date? = nil, retainOriginals: Bool = false, outputDirectory: String? = nil, generateNFO: Bool = false, nfoOutputDirectory: String? = nil, tvNamingTemplate: String = "S%02dE%02d - %t", watchFolders: [String] = [], defaultSubtitleLanguage: String = "eng", autoSubtitleLookup: Bool = false, iTunesCountry: String = "us", preferHighResArtwork: Bool = true, enableMusicMetadata: Bool = true, providerWeights: ProviderWeights = ProviderWeights.defaults()) {
        self.adultEnabled = adultEnabled
        self.tpdbConfidence = tpdbConfidence
        self.lastKeyRotation = lastKeyRotation
        self.retainOriginals = retainOriginals
        self.outputDirectory = outputDirectory
        self.generateNFO = generateNFO
        self.nfoOutputDirectory = nfoOutputDirectory
        self.tvNamingTemplate = tvNamingTemplate
        self.watchFolders = watchFolders
        self.defaultSubtitleLanguage = defaultSubtitleLanguage
        self.autoSubtitleLookup = autoSubtitleLookup
        self.iTunesCountry = iTunesCountry
        self.preferHighResArtwork = preferHighResArtwork
        self.enableMusicMetadata = enableMusicMetadata
        self.providerWeights = providerWeights
    }
}

public actor SettingsStore {
    private let defaults = UserDefaults.standard
    private let settingsKey = "SublerPlus.Settings"
    private let keychain: APIKeyStore
    public private(set) var settings: AppSettings

    public init(keychain: APIKeyStore) {
        self.keychain = keychain
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    public func update(_ block: (inout AppSettings) -> Void) {
        block(&settings)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    public func tpdbKey() -> String? {
        keychain.get(key: "tpdb")
    }

    public func setTPDBKey(_ value: String) {
        keychain.set(key: "tpdb", value: value)
    }
}

public final class ProvidersRegistry {
    private var store: [String: PipelineMetadataProvider] = [:]
    public init(providers: [PipelineMetadataProvider]) {
        providers.forEach { store[$0.id] = $0 }
    }

    public func all(includeAdult: Bool, preference: ProviderPreference = .balanced) -> [PipelineMetadataProvider] {
        let filtered = store.values.filter { includeAdult || !$0.isAdult }
        switch preference {
        case .balanced: return Array(filtered)
        case .scoreFirst: return Array(filtered).sorted { $0.id < $1.id }
        case .yearFirst: return Array(filtered).sorted { $0.isAdult && !$1.isAdult }
        }
    }
}

public final class MetadataPipeline {
    private let registry: ProvidersRegistry
    private let mp4Handler: MP4Handler
    private let artwork: ArtworkCacheManager?
    private let subtitleManager: SubtitleManager?
    public var retainOriginals: Bool = false
    public var outputDirectory: URL?
    public var generateNFO: Bool = false
    public var nfoOutputDirectory: URL?
    public var tvNamingTemplate: String = "S%02dE%02d - %t"
    public var autoSubtitleLookup: Bool = false

    public init(registry: ProvidersRegistry, mp4Handler: MP4Handler, artwork: ArtworkCacheManager? = nil, subtitleManager: SubtitleManager? = nil) {
        self.registry = registry
        self.mp4Handler = mp4Handler
        self.artwork = artwork
        self.subtitleManager = subtitleManager
    }

    public func enrich(
        file: URL,
        includeAdult: Bool,
        preference: ProviderPreference = .balanced,
        onAmbiguous: (([MetadataDetails]) async -> MetadataDetails?)? = nil
    ) async throws -> MetadataDetails? {
        guard isSupportedMedia(file) else { throw MetadataError.unsupportedFileType }
        let hint = try mp4Handler.readMetadata(at: file)
        let providers = registry.all(includeAdult: includeAdult, preference: preference)

        var candidates: [MetadataDetails] = []
        for provider in providers {
            do {
                let details = try await provider.fetch(for: file, hint: hint)
                let annotated = details.withSource(provider.id)
                candidates.append(annotated)
            } catch {
                continue
            }
        }

        guard !candidates.isEmpty else { throw MetadataError.noProviderMatch }

        let deduped = self.dedupeCandidates(candidates, hint: hint)

        let best = pickBestMatch(from: deduped, hint: hint, preference: preference)
        if deduped.count > 1, let onAmbiguous {
            let choice = await onAmbiguous(deduped)
            if let choice {
                try await writeResolved(details: choice, to: file)
                return choice
            } else {
                return nil
            }
        } else {
            try await writeResolved(details: best, to: file)
            
            // Automatic subtitle lookup after successful metadata enrichment
            if autoSubtitleLookup, let subtitleMgr = subtitleManager {
                await performAutoSubtitleLookup(for: file, metadata: best, subtitleManager: subtitleMgr)
            }
            
            return best
        }
    }
    
    private func performAutoSubtitleLookup(for file: URL, metadata: MetadataDetails, subtitleManager: SubtitleManager) async {
        // Extract title and year from enriched metadata
        let title = metadata.title
        let year = metadata.releaseDate.flatMap { Calendar.current.dateComponents([.year], from: $0).year }
        
        // Search for subtitles (language is set in SubtitleManager initialization)
        let candidates = await subtitleManager.search(title: title, year: year)
        
        guard let bestCandidate = findBestSubtitleMatch(candidates: candidates, metadata: metadata) else {
            return // No suitable match found
        }
        
        // Download and embed subtitle
        guard let subtitleResult = await subtitleManager.download(candidate: bestCandidate) else {
            return // Download failed
        }
        
        do {
            try await subtitleManager.muxSubtitle(into: file, subtitle: subtitleResult)
        } catch {
            // Log error but don't fail the enrichment
            // Subtitle attachment is best-effort
        }
    }
    
    private func findBestSubtitleMatch(candidates: [SubtitleCandidate], metadata: MetadataDetails) -> SubtitleCandidate? {
        guard !candidates.isEmpty else { return nil }
        
        // Prefer exact year match
        if let metadataYear = metadata.releaseDate.flatMap({ Calendar.current.dateComponents([.year], from: $0).year }) {
            let yearMatches = candidates.filter { $0.releaseYear == metadataYear }
            if !yearMatches.isEmpty {
                // Return highest scored match with year match
                return yearMatches.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.first
            }
        }
        
        // Fallback: return highest scored match
        return candidates.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.first
    }

    public func writeResolved(details: MetadataDetails, to file: URL) async throws {
        let cover = await artwork?.fetchArtwork(from: details.coverURL)
        let tags = mp4TagUpdates(from: details, coverData: cover)
        var targetURL = try await destinationURL(for: file)
        if let renamed = try? renameIfNeeded(targetURL, details: details) {
            targetURL = renamed
        }
        try mp4Handler.writeMetadata(details, tags: tags, to: targetURL)
        if generateNFO {
            let generator = NFOGenerator()
            let nfo = generator.generate(details: details)
            let dir = nfoOutputDirectory ?? targetURL.deletingLastPathComponent()
            let nfoURL = dir.appendingPathComponent(targetURL.deletingPathExtension().lastPathComponent).appendingPathExtension("nfo")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? nfo.data(using: .utf8)?.write(to: nfoURL)
        }
    }
}

private func isSupportedMedia(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    return ["mp4", "m4v", "m4a", "mov", "mkv"].contains(ext)
}

extension MetadataPipeline {
    private func destinationURL(for original: URL) async throws -> URL {
        guard retainOriginals, let outputDirectory else { return original }
        let name = original.lastPathComponent
        let target = outputDirectory.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: original, to: target)
            return target
        } catch {
            throw MetadataError.retainOriginalsCopyFailed
        }
    }

    private func pickBestMatch(from candidates: [MetadataDetails], hint: MetadataHint, preference: ProviderPreference) -> MetadataDetails {
        func score(_ d: MetadataDetails) -> Double {
            let base = d.rating ?? 0
            let providerBoost = providerWeight(for: d.source)
            let dy = releaseYear(d)
            let yearDiff: Double
            if let hy = hint.year, let dy {
                yearDiff = Double(abs(hy - dy))
            } else {
                yearDiff = 6 // penalize unknown year slightly
            }
            var bonus: Double = 0
            if d.mediaKind == .tvShow {
                bonus += 0.3
            }
            if d.show != nil, d.seasonNumber != nil {
                bonus += 0.2
            }
            switch preference {
            case .balanced:
                return (base * providerBoost) - (yearDiff * 0.15) + providerBoost * 0.5 + bonus
            case .scoreFirst:
                return (base * providerBoost) - (yearDiff * 0.05) + providerBoost + bonus
            case .yearFirst:
                return (base * providerBoost) - (yearDiff * 0.3) + providerBoost * 0.4 + bonus
            }
        }
        return candidates.max(by: { score($0) < score($1) }) ?? candidates[0]
    }

    private func providerWeight(for source: String?) -> Double {
        switch source {
        case "tmdb": return 1.1
        case "tpdb": return 1.05
        case "tvdb": return 1.0
        case "subler": return 0.6
        default: return 1.0
        }
    }

    private func releaseYear(_ details: MetadataDetails) -> Int? {
        details.releaseDate.flatMap { Calendar.current.dateComponents([.year], from: $0).year }
    }

    private func dedupeCandidates(_ list: [MetadataDetails], hint: MetadataHint) -> [MetadataDetails] {
        var bestByKey: [String: MetadataDetails] = [:]
        for item in list {
            let key = dedupeKey(for: item, hint: hint)
            if let existing = bestByKey[key] {
                let currentScore = (item.rating ?? 0) * providerWeight(for: item.source)
                let existingScore = (existing.rating ?? 0) * providerWeight(for: existing.source)
                if currentScore > existingScore {
                    bestByKey[key] = item
                }
            } else {
                bestByKey[key] = item
            }
        }
        return Array(bestByKey.values)
    }

    private func dedupeKey(for item: MetadataDetails, hint: MetadataHint) -> String {
        let year = releaseYear(item) ?? hint.year ?? 0
        if let show = item.show?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
            let season = item.seasonNumber ?? 0
            let episode = item.episodeNumber ?? 0
            return "\(show)|\(season)|\(episode)|\(year)"
        }
        let title = item.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let studio = (item.studio ?? "").lowercased()
        return "\(title)|\(year)|\(studio)"
    }

    // MARK: - TV naming

    private func renameIfNeeded(_ url: URL, details: MetadataDetails) throws -> URL {
        guard tvNamingTemplate.contains("%t") else { return url }

        let title = sanitized(details.title)
        let year = releaseYear(details)

        // Attempt to parse season/episode from filename: S01E02 or 1x02
        let name = url.deletingPathExtension().lastPathComponent
        let pattern = #"(?i)(?:s(\d{1,2})e(\d{1,2})|(\d{1,2})x(\d{1,2}))"#
        var season: Int = 1
        var episode: Int = 1
        if let match = name.range(of: pattern, options: .regularExpression) {
            let matched = String(name[match])
            if matched.lowercased().contains("s") {
                let parts = matched.lowercased().replacingOccurrences(of: "s", with: "").split(separator: "e")
                if parts.count == 2 {
                    season = Int(parts[0]) ?? season
                    episode = Int(parts[1]) ?? episode
                }
            } else if matched.contains("x") {
                let parts = matched.split(separator: "x")
                if parts.count == 2 {
                    season = Int(parts[0]) ?? season
                    episode = Int(parts[1]) ?? episode
                }
            }
        }

        var filename = tvNamingTemplate
        filename = filename.replacingOccurrences(of: "%t", with: title)
        filename = filename.replacingOccurrences(of: "%s", with: String(format: "%02d", season))
        filename = filename.replacingOccurrences(of: "%e", with: String(format: "%02d", episode))
        if let year {
            filename = filename.replacingOccurrences(of: "%y", with: String(year))
        }

        // Clean unsafe chars
        filename = filename.replacingOccurrences(of: #"[\\/:\*?"<>|]"#, with: "-", options: .regularExpression)
        if filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }

        let newURL = url.deletingLastPathComponent().appendingPathComponent(filename).appendingPathExtension(url.pathExtension)
        if newURL == url { return url }

        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            return newURL
        } catch {
            return url // fall back silently
        }
    }

    private func sanitized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct AmbiguousDetails {
    public let candidates: [MetadataDetails]
}

