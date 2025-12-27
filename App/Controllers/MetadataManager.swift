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

    public init(adultEnabled: Bool = false, tpdbConfidence: Double = 0.5, lastKeyRotation: Date? = nil, retainOriginals: Bool = false, outputDirectory: String? = nil, generateNFO: Bool = false, nfoOutputDirectory: String? = nil, tvNamingTemplate: String = "S%02dE%02d - %t", watchFolders: [String] = [], defaultSubtitleLanguage: String = "eng") {
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
    public var retainOriginals: Bool = false
    public var outputDirectory: URL?
    public var generateNFO: Bool = false
    public var nfoOutputDirectory: URL?
    public var tvNamingTemplate: String = "S%02dE%02d - %t"

    public init(registry: ProvidersRegistry, mp4Handler: MP4Handler, artwork: ArtworkCacheManager? = nil) {
        self.registry = registry
        self.mp4Handler = mp4Handler
        self.artwork = artwork
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
            return best
        }
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
    return ["mp4", "m4v", "mov"].contains(ext)
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

