import Foundation
import SwiftUI

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public private(set) var searchResults: [MetadataResult] = []
    @Published public var adultEnabled: Bool = false
    @Published public var status: String = "Idle"
    @Published public var mediaFiles: [URL] = []
    @Published public var selectedFile: URL?
    @Published public var searchQuery: String = ""
    @Published public var jobs: [Job] = []
    @Published public var activityLines: [String] = []
    @Published public var ambiguityQueue: [AmbiguousMatch] = []
    @Published public var pendingAmbiguity: AmbiguousMatch?
    @Published public var showAmbiguitySheet: Bool = false
    @Published public var tokenMissing: Bool = false

    private let settingsStore: SettingsStore
    private let pipeline: MetadataPipeline
    private let adultProvider: MetadataProvider
    private let artworkCache: ArtworkCacheManager
    private let apiKeys: APIKeyManager
    private let jobQueue: JobQueue
    private let statusStream: StatusStream
    private let batchLimiter = AsyncSemaphore(2)
    private var resolutionCache: [AmbiguityResolutionKey: MetadataDetails] = [:]
    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("SublerPlus", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("ambiguity-cache.json")
    }()

    public init(
        settingsStore: SettingsStore,
        pipeline: MetadataPipeline,
        adultProvider: MetadataProvider,
        artworkCache: ArtworkCacheManager,
        apiKeys: APIKeyManager,
        jobQueue: JobQueue,
        statusStream: StatusStream
    ) {
        self.settingsStore = settingsStore
        self.pipeline = pipeline
        self.adultProvider = adultProvider
        self.artworkCache = artworkCache
        self.apiKeys = apiKeys
        self.jobQueue = jobQueue
        self.statusStream = statusStream
        Task {
            await loadSettings()
            refreshTokenBanner()
            await refreshJobs()
            await startActivityFeed()
            await loadResolutionCache()
        }
    }

    private func loadSettings() async {
        let current = await settingsStore.settings
        adultEnabled = current.adultEnabled
    }

    public func refreshTokenBanner() {
        let token = apiKeys.loadWebToken() ?? ProcessInfo.processInfo.environment["WEBUI_TOKEN"]
        tokenMissing = token?.isEmpty ?? true
    }

    public var hasSelection: Bool { selectedFile != nil }

    public func addFiles(_ urls: [URL]) {
        let allowed = urls.filter { ["mp4","m4v","mov"].contains($0.pathExtension.lowercased()) }
        let unique = allowed.filter { !mediaFiles.contains($0) }
        mediaFiles.append(contentsOf: unique)
    }

    public func presentFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .mpeg4Movie]
        if panel.runModal() == .OK {
            addFiles(panel.urls)
        }
    }

    @discardableResult
    public func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    Task { @MainActor in self.addFiles([url]) }
                    handled = true
                } else if let url = item as? URL {
                    Task { @MainActor in self.addFiles([url]) }
                    handled = true
                }
            }
        }
        return handled
    }

    public func searchAdultMetadata(for query: String) {
        searchQuery = query
        Task {
            do {
                let results = try await adultProvider.search(query: query)
                try Task.checkCancellation()
                self.searchResults = results
            } catch is CancellationError {
                // Ignore
            } catch {
                status = "Search failed: \(error.localizedDescription)"
            }
        }
    }

    public func triggerSearch() {
        guard !searchQuery.isEmpty else { return }
        searchAdultMetadata(for: searchQuery)
    }

    public func enrich(file url: URL) {
        Task {
            do {
                status = "Enriching \(url.lastPathComponent)"
                let details = try await pipeline.enrich(file: url, includeAdult: adultEnabled, onAmbiguous: { choices in
                    let match = AmbiguousMatch(file: url, choices: choices)
                    if let auto = self.autoResolve(match: match) {
                        return auto
                    }
                    await MainActor.run { [weak self] in
                        self?.pendingAmbiguity = match
                        self?.ambiguityQueue.append(match)
                        self?.showAmbiguitySheet = true
                    }
                    return nil // defer resolution
                })
                if let details = details {
                    let cover = await artworkCache.fetchArtwork(from: details.coverURL)
                    _ = mp4TagUpdates(from: details, coverData: cover)
                    status = "Updated metadata for \(details.title)"
                } else {
                    status = "Enrichment deferred: awaiting user choice"
                }
            } catch {
                status = "Enrichment failed: \(error.localizedDescription)"
            }
        }
    }

    public func enrichSelected() {
        if let selectedFile {
            enrich(file: selectedFile)
        }
    }

    public func openSettings() {
        // placeholder for future deep links
    }

    public func openHelp() {
        if let url = URL(string: "https://github.com/roto31/SublerPlus/wiki") {
            NSWorkspace.shared.open(url)
        }
    }

    public func resolveAmbiguity(choice: MetadataDetails, for match: AmbiguousMatch) {
        Task {
            let key = cacheKey(for: match.file, choice: choice)
            resolutionCache[key] = choice
            persistResolutionCache()
            await statusStream.add("Resolved \(match.file.lastPathComponent) to \(choice.title)")
            try? await pipeline.writeResolved(details: choice, to: match.file)
            await MainActor.run {
                ambiguityQueue.removeAll { $0.id == match.id }
                if pendingAmbiguity?.id == match.id { pendingAmbiguity = nil }
                showAmbiguitySheet = false
            }
        }
    }

    // Batch/job handling
    public func enqueueBatch(urls: [URL]) {
        Task {
            let jobs = await jobQueue.enqueue(urls)
            await refreshJobs()
            for job in jobs {
                Task.detached { [weak self] in
                    guard let self else { return }
                    await self.batchLimiter.acquire()
                    await self.jobQueue.update(jobID: job.id, status: .running, message: job.url.lastPathComponent)
                    do {
                        let details = try await self.pipeline.enrich(file: job.url, includeAdult: self.adultEnabled, onAmbiguous: { choices in
                            let match = AmbiguousMatch(file: job.url, choices: choices)
                            if let auto = await MainActor.run(body: { self.autoResolve(match: match) }) { return auto }
                            await MainActor.run { [weak self] in
                                self?.ambiguityQueue.append(match)
                                self?.pendingAmbiguity = match
                                self?.showAmbiguitySheet = true
                            }
                            return nil // defer
                        })
                        if let details = details {
                            let cover = await self.artworkCache.fetchArtwork(from: details.coverURL)
                            _ = mp4TagUpdates(from: details, coverData: cover)
                            await self.jobQueue.update(jobID: job.id, status: .succeeded, message: details.title)
                        } else {
                            await self.jobQueue.update(jobID: job.id, status: .failed, message: "Ambiguous; awaiting user choice")
                        }
                    } catch {
                        await self.jobQueue.update(jobID: job.id, status: .failed, message: error.localizedDescription)
                    }
                    await self.refreshJobs()
                    await self.batchLimiter.release()
                }
            }
        }
    }

    public func retryJob(id: UUID) {
        Task {
            await jobQueue.retry(jobID: id)
            await refreshJobs()
            if let job = jobs.first(where: { $0.id == id }) {
                enqueueBatch(urls: [job.url])
            }
        }
    }

    public func refreshJobs() async {
        let snapshot = await jobQueue.snapshot()
        await MainActor.run { jobs = snapshot }
    }

    public func appendActivity(_ message: String) {
        activityLines.append(message)
    }

    private func startActivityFeed() async {
        while true {
            let recent = await statusStream.recent(limit: 50)
            let lines = recent.map { "[\($0.timestamp)] \($0.message)" }
            await MainActor.run { activityLines = lines }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        }
    }

    private func cacheKey(for file: URL, choice: MetadataDetails) -> AmbiguityResolutionKey {
        let title = file.deletingPathExtension().lastPathComponent.lowercased()
        let year = choice.releaseDate.flatMap { Calendar.current.dateComponents([.year], from: $0).year }
        let studio = choice.studio?.lowercased()
        return AmbiguityResolutionKey(title: title, year: year, studio: studio)
    }

    private func autoResolve(match: AmbiguousMatch) -> MetadataDetails? {
        for choice in match.choices {
            let key = cacheKey(for: match.file, choice: choice)
            if let cached = resolutionCache[key] {
                return cached
            }
        }
        return nil
    }

    private func loadResolutionCache() async {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        if let decoded = try? JSONDecoder().decode([AmbiguityResolutionKey: MetadataDetails].self, from: data) {
            resolutionCache = decoded
        }
    }

    private func persistResolutionCache() {
        if let data = try? JSONEncoder().encode(resolutionCache) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }

    public func clearResolutionCache() {
        resolutionCache.removeAll()
        try? FileManager.default.removeItem(at: cacheURL)
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var adultEnabled: Bool = false
    @Published public var tpdbConfidence: Double = 0.5
    @Published public var tpdbKey: String = ""
    @Published public var tmdbKey: String = ""
    @Published public var tvdbKey: String = ""
    @Published public var webToken: String = ""
    @Published public var keyRotationInfo: String = ""
    @Published public var retainOriginals: Bool = false
    @Published public var outputDirectory: URL?

    private let settingsStore: SettingsStore
    private let apiKeys: APIKeyManager
    private var lastRotation: Date?

    public init(settingsStore: SettingsStore, apiKeys: APIKeyManager) {
        self.settingsStore = settingsStore
        self.apiKeys = apiKeys
        Task { await load() }
    }

    private func load() async {
        let settings = await settingsStore.settings
        adultEnabled = settings.adultEnabled
        tpdbConfidence = settings.tpdbConfidence
        tpdbKey = apiKeys.loadTPDBKey() ?? ""
        tmdbKey = apiKeys.loadTMDBKey() ?? ""
        tvdbKey = apiKeys.loadTVDBKey() ?? ""
        webToken = apiKeys.loadWebToken() ?? ""
        lastRotation = settings.lastKeyRotation
        keyRotationInfo = rotationText()
        retainOriginals = settings.retainOriginals
        outputDirectory = settings.outputDirectory.flatMap { URL(fileURLWithPath: $0) }
    }

    public func save() {
        Task {
            await settingsStore.update { settings in
                settings.adultEnabled = adultEnabled
                settings.tpdbConfidence = tpdbConfidence
                settings.lastKeyRotation = lastRotation
                settings.retainOriginals = retainOriginals
                settings.outputDirectory = outputDirectory?.path
            }
            apiKeys.saveTPDBKey(tpdbKey)
            apiKeys.saveTMDBKey(tmdbKey)
            apiKeys.saveTVDBKey(tvdbKey)
            if !webToken.isEmpty {
                apiKeys.saveWebToken(webToken)
            }
        }
    }

    public func generateToken() {
        webToken = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        lastRotation = Date()
        keyRotationInfo = rotationText()
    }

    public func pickOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    public func markRotatedNow() {
        lastRotation = Date()
        keyRotationInfo = rotationText()
    }

    private func rotationText() -> String {
        guard let lastRotation else { return "Token/key not rotated yet." }
        let days = Int(Date().timeIntervalSince(lastRotation) / 86_400)
        if days > 90 {
            return "Rotate keys: last rotation \(days) days ago."
        }
        return "Last rotation \(days) days ago."
    }
}

