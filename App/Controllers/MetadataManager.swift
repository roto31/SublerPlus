import Foundation
import AVFoundation
import UniformTypeIdentifiers

public enum MetadataError: Error, Equatable {
    case unsupportedFileType
    case noProviderMatch
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

    public init(adultEnabled: Bool = false, tpdbConfidence: Double = 0.5, lastKeyRotation: Date? = nil) {
        self.adultEnabled = adultEnabled
        self.tpdbConfidence = tpdbConfidence
        self.lastKeyRotation = lastKeyRotation
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

    public func all(includeAdult: Bool) -> [PipelineMetadataProvider] {
        store.values.filter { includeAdult || !$0.isAdult }
    }
}

public final class MetadataPipeline {
    private let registry: ProvidersRegistry
    private let mp4Handler: MP4Handler
    private let artwork: ArtworkCacheManager?

    public init(registry: ProvidersRegistry, mp4Handler: MP4Handler, artwork: ArtworkCacheManager? = nil) {
        self.registry = registry
        self.mp4Handler = mp4Handler
        self.artwork = artwork
    }

    public func enrich(
        file: URL,
        includeAdult: Bool,
        onAmbiguous: (([MetadataDetails]) async -> MetadataDetails?)? = nil
    ) async throws -> MetadataDetails? {
        guard isSupportedMedia(file) else { throw MetadataError.unsupportedFileType }
        let hint = try mp4Handler.readMetadata(at: file)
        let providers = registry.all(includeAdult: includeAdult)
        for provider in providers {
            do {
                let details = try await provider.fetch(for: file, hint: hint)
                let cover = await artwork?.fetchArtwork(from: details.coverURL)
                let tags = mp4TagUpdates(from: details, coverData: cover)
                try mp4Handler.writeMetadata(details, tags: tags, to: file)
                return details
            } catch {
                continue
            }
        }
        throw MetadataError.noProviderMatch
    }

    public func writeResolved(details: MetadataDetails, to file: URL) async throws {
        let cover = await artwork?.fetchArtwork(from: details.coverURL)
        let tags = mp4TagUpdates(from: details, coverData: cover)
        try mp4Handler.writeMetadata(details, tags: tags, to: file)
    }
}

private func isSupportedMedia(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    return ["mp4", "m4v", "mov"].contains(ext)
}

public struct AmbiguousDetails {
    public let candidates: [MetadataDetails]
}

