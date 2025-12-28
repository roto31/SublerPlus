import Foundation
import SwiftUI
import AVFoundation

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
    @Published public var fileMetadata: [URL: MetadataDetails] = [:]
    @Published public var searchTitle: String = ""
    @Published public var searchStudio: String = ""
    @Published public var searchYearFrom: String = ""
    @Published public var searchYearTo: String = ""
    @Published public var searchActors: String = ""
    @Published public var searchDirectors: String = ""
    @Published public var searchAirDate: String = ""
    @Published public var providerPreference: ProviderPreference = .balanced
    @Published public var watchFolders: [URL] = []
    @Published public var defaultSubtitleLanguage: String = "eng"
    @Published public var droppedFile: URL?
    @Published public var droppedFileMetadata: MetadataDetails?
    @Published public var droppedFileArtworkURL: URL?
    @Published public var selectedSearchResult: MetadataResult?
    @Published public var selectedResultDetails: MetadataDetails?
    @Published public var pendingArtworkURL: URL?
    @Published public var showArtworkPicker: Bool = false
    @Published public var showApplyConfirmation: Bool = false
    
    // Search state management
    @Published public var isSearching: Bool = false
    @Published public var searchError: String?
    
    private var currentFetchTask: Task<Void, Never>?
    private var currentSearchTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?
    private let settingsStore: SettingsStore
    private let pipeline: MetadataPipeline
    private let adultProvider: MetadataProvider
    private let searchProviders: [MetadataProvider]
    private var unifiedSearchManager: UnifiedSearchManager
    private let searchCache: SearchCacheManager
    private let artworkCache: ArtworkCacheManager
    private let apiKeys: APIKeyManager
    private let jobQueue: JobQueue
    private let statusStream: StatusStream
    private let batchLimiter = AsyncSemaphore(2)
    private var resolutionCache: [AmbiguityResolutionKey: MetadataDetails] = [:]
    private var folderMonitors: [URL: FolderMonitor] = [:]
    private var watchedKnownFiles: Set<URL> = []
    private var artworkOverrides: [URL: URL] = [:]
    private var fileTracks: [URL: [MediaTrack]] = [:]
    private var fileChapters: [URL: [Chapter]] = [:]
    
    public func getTracks(for url: URL) -> [MediaTrack]? {
        fileTracks[url]
    }
    
    public func getChapters(for url: URL) -> [Chapter]? {
        fileChapters[url]
    }
    
    public func getAvailableProviders() -> [String] {
        unifiedSearchManager.availableProviders
    }
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
        searchProviders: [MetadataProvider],
        artworkCache: ArtworkCacheManager,
        apiKeys: APIKeyManager,
        jobQueue: JobQueue,
        statusStream: StatusStream
    ) {
        self.settingsStore = settingsStore
        self.pipeline = pipeline
        self.adultProvider = adultProvider
        self.searchProviders = searchProviders
        self.searchCache = SearchCacheManager(maxEntries: 100)
        // Initialize with default weights, will be updated when settings load
        self.unifiedSearchManager = UnifiedSearchManager(
            modernProviders: searchProviders,
            includeAdult: false,
            searchCache: searchCache,
            providerWeights: ProviderWeights.defaults()
        )
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
        let folders = current.watchFolders.map { URL(fileURLWithPath: $0) }
        updateWatchFolders(folders)
        defaultSubtitleLanguage = current.defaultSubtitleLanguage
        
        // Update unified search manager with current settings
        await MainActor.run {
            self.unifiedSearchManager = UnifiedSearchManager(
                modernProviders: searchProviders,
                includeAdult: adultEnabled,
                searchCache: searchCache,
                providerWeights: current.providerWeights
            )
        }
    }

    public func refreshTokenBanner() {
        let token = apiKeys.loadWebToken() ?? ProcessInfo.processInfo.environment["WEBUI_TOKEN"]
        tokenMissing = token?.isEmpty ?? true
        if tokenMissing {
            status = "SECURITY: WebUI token is required. Set it in Settings."
        }
    }

    public var hasSelection: Bool { selectedFile != nil }

    @discardableResult
    public func addFiles(_ urls: [URL]) -> Int {
        let exts: Set<String> = ["mp4", "m4v", "mov"]
        let allowed = urls.filter { exts.contains($0.pathExtension.lowercased()) }
        let unique = allowed.filter { !mediaFiles.contains($0) }
        guard !unique.isEmpty else {
            status = "No new supported files to add"
            return 0
        }
        mediaFiles.append(contentsOf: unique)
        Task {
            for url in unique {
                async let tracks = inspectTracks(url: url)
                async let chapters = inspectChapters(url: url)
                let (t, c) = await (tracks, chapters)
                await MainActor.run {
                    self.fileTracks[url] = t
                    self.fileChapters[url] = c
                }
            }
        }
        status = "Added \(unique.count) file\(unique.count == 1 ? "" : "s")"
        return unique.count
    }

    public func presentFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsOtherFileTypes = false
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie]
        if panel.runModal() == .OK {
            let added = addFiles(panel.urls)
            if added == 0 {
                status = "No supported media selected"
            }
        }
    }

    @discardableResult
    public func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier("public.file-url") }
        guard !fileProviders.isEmpty else { return false }
        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    Task { @MainActor in _ = self.addFiles([url]) }
                } else if let url = item as? URL {
                    Task { @MainActor in _ = self.addFiles([url]) }
                }
            }
        }
        return true
    }

    public func triggerSearch() {
        guard !searchQuery.isEmpty else { return }
        Task { await runSearch(query: searchQuery, yearHint: nil) }
    }

    public func runAdvancedSearch() {
        // Cancel any pending debounce task
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        
        // Cancel previous search if still running
        currentSearchTask?.cancel()
        currentSearchTask = nil
        
        // Clear previous search state
        searchResults = []
        selectedSearchResult = nil
        selectedResultDetails = nil
        searchError = nil
        
        // Build query from search fields (text only - year is passed as hint separately)
        var components: [String] = []
        if !searchTitle.isEmpty { components.append(searchTitle) }
        if !searchStudio.isEmpty { components.append(searchStudio) }
        if !searchActors.isEmpty { components.append(searchActors) }
        if !searchDirectors.isEmpty { components.append(searchDirectors) }
        if !searchAirDate.isEmpty { components.append(searchAirDate) }
        
        // Build query string
        let query = components.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate query is not empty
        guard !query.isEmpty else {
            status = "Please enter at least one search field"
            isSearching = false
            return
        }
        
        // Get year hint (use from year if available, otherwise to year)
        // Year is used for sorting/ranking results, not as part of the query string
        let yearHint = Int(searchYearFrom) ?? Int(searchYearTo)
        
        // Run search immediately (no debouncing for button clicks)
        currentSearchTask = Task { @MainActor in
            await runSearch(query: query, yearHint: yearHint)
        }
    }
    
    /// Debounced search for text input changes
    /// - Parameter delay: Debounce delay in seconds (default: 0.5)
    public func runAdvancedSearchDebounced(delay: TimeInterval = 0.5) {
        // Cancel previous debounce task
        searchDebounceTask?.cancel()
        
        // Create new debounce task
        searchDebounceTask = Task { @MainActor in
            // Wait for debounce delay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            // Execute search
            runAdvancedSearch()
        }
    }
    
    public func loadMetadataFromFile(_ url: URL) async {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            await MainActor.run {
                self.status = "File not found: \(url.lastPathComponent)"
            }
            await statusStream.add("File not found: \(url.path)")
            return
        }
        
        // Validate file type
        let ext = url.pathExtension.lowercased()
        guard ["mp4", "m4v", "m4a", "mov", "mkv"].contains(ext) else {
            await MainActor.run {
                self.status = "Unsupported file type: \(ext). Supported: MP4, M4V, M4A, MOV, MKV"
            }
            await statusStream.add("Unsupported file type: \(ext)")
            return
        }
        
        await MainActor.run {
            self.status = "Reading metadata from \(url.lastPathComponent)..."
        }
        
        let mp4Handler = SublerMP4Handler()
        
        do {
            // Read full metadata
            let metadata = try mp4Handler.readFullMetadata(at: url)
            
            // Extract artwork (best effort - don't fail if artwork extraction fails)
            let artworkURL = try? mp4Handler.extractArtwork(from: url)
            
            await MainActor.run {
                self.droppedFile = url
                self.droppedFileMetadata = metadata
                self.droppedFileArtworkURL = artworkURL
                
                // Auto-populate search fields (only if they're empty to preserve user input)
                if let metadata = metadata {
                    if self.searchTitle.isEmpty {
                        self.searchTitle = metadata.title
                    }
                    if self.searchStudio.isEmpty, let studio = metadata.studio {
                        self.searchStudio = studio
                    }
                    if self.searchYearFrom.isEmpty || self.searchYearTo.isEmpty,
                       let releaseDate = metadata.releaseDate {
                        let year = Calendar.current.component(.year, from: releaseDate)
                        if self.searchYearFrom.isEmpty {
                            self.searchYearFrom = String(year)
                        }
                        if self.searchYearTo.isEmpty {
                            self.searchYearTo = String(year)
                        }
                    }
                    if self.searchActors.isEmpty, !metadata.performers.isEmpty {
                        self.searchActors = metadata.performers.joined(separator: ", ")
                    }
                }
                
                self.status = "Metadata loaded from \(url.lastPathComponent)"
            }
            
            await statusStream.add("Loaded metadata from \(url.lastPathComponent)")
        } catch {
            await MainActor.run {
                self.status = "Failed to read metadata: \(error.localizedDescription)"
                // Clear dropped file state on error
                self.droppedFile = nil
                self.droppedFileMetadata = nil
                self.droppedFileArtworkURL = nil
            }
            await statusStream.add("Failed to read metadata from \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    public func fetchResultDetails(for result: MetadataResult) async {
        // Cancel any existing fetch task
        currentFetchTask?.cancel()
        
        // Create new fetch task
        currentFetchTask = Task {
            await MainActor.run {
                self.status = "Fetching details for \(result.title)..."
                // Clear old details immediately
                self.selectedResultDetails = nil
            }
            
            // Get current settings for weights
            let currentSettings = await settingsStore.settings
            
            // Update unified search manager with current settings
            let updatedManager = UnifiedSearchManager(
                modernProviders: searchProviders,
                includeAdult: adultEnabled,
                searchCache: searchCache,
                providerWeights: currentSettings.providerWeights
            )
            await MainActor.run {
                self.unifiedSearchManager = updatedManager
            }
            
            do {
                // Check cancellation before starting network request
                try Task.checkCancellation()
                
                // Use unified search manager to fetch details (tries modern first, then legacy)
                let details = try await updatedManager.fetchDetails(for: result)
                
                // Check cancellation again before updating UI
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.selectedResultDetails = details
                    self.status = "Details loaded for \(result.title)"
                }
                await statusStream.add("Loaded details for \(result.title)")
            } catch {
                // Don't update UI if task was cancelled (Task.checkCancellation throws CancellationError)
                if error is CancellationError {
                    return
                }
                
                // Fallback to direct provider lookup if unified manager fails
                let providerID = result.source ?? ""
                if let provider = searchProviders.first(where: { $0.id == providerID }) {
                    do {
                        let details = try await provider.fetchDetails(for: result.id)
                        await MainActor.run {
                            self.selectedResultDetails = details
                            self.status = "Details loaded for \(result.title)"
                        }
                        await statusStream.add("Loaded details for \(result.title)")
                        return
                    } catch {
                        // Continue to error handling
                    }
                }
                
                await MainActor.run {
                    self.status = "Failed to fetch details: \(error.localizedDescription)"
                }
                await statusStream.add("Failed to fetch details for \(result.title): \(error.localizedDescription)")
            }
        }
        
        await currentFetchTask?.value
    }
    
    public func applySelectedMetadata(to file: URL) async {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: file.path) else {
            await MainActor.run {
                self.status = "File not found: \(file.lastPathComponent)"
            }
            await statusStream.add("File not found: \(file.path)")
            return
        }
        
        guard let details = selectedResultDetails else {
            await MainActor.run {
                self.status = "No metadata selected to apply"
            }
            await statusStream.add("No metadata selected to apply")
            return
        }
        
        await MainActor.run {
            self.status = "Applying metadata to \(file.lastPathComponent)..."
        }
        
        do {
            try await pipeline.writeResolved(details: details, to: file)
            await MainActor.run {
                self.status = "Metadata applied successfully"
                // Trigger artwork picker display
                self.showArtworkPicker = true
            }
            await statusStream.add("Metadata applied to \(file.lastPathComponent)")
        } catch {
            await MainActor.run {
                self.status = "Failed to apply metadata: \(error.localizedDescription)"
            }
            await statusStream.add("Failed to apply metadata to \(file.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    public func applyArtwork(to file: URL, artworkURL: URL) async {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: file.path) else {
            await MainActor.run {
                self.status = "File not found: \(file.lastPathComponent)"
            }
            await statusStream.add("File not found: \(file.path)")
            return
        }
        
        // Validate artwork URL exists
        guard FileManager.default.fileExists(atPath: artworkURL.path) else {
            await MainActor.run {
                self.status = "Artwork file not found"
            }
            await statusStream.add("Artwork file not found: \(artworkURL.path)")
            return
        }
        
        await MainActor.run {
            self.status = "Applying artwork to \(file.lastPathComponent)..."
        }
        
        // Read artwork data
        guard let artworkData = try? Data(contentsOf: artworkURL) else {
            await MainActor.run {
                self.status = "Failed to read artwork data"
            }
            await statusStream.add("Failed to read artwork data from \(artworkURL.path)")
            return
        }
        
            // Apply artwork using existing method
        do {
            let mp4Handler = SublerMP4Handler()
            
            // Read existing metadata or use selected result details
            let metadata: MetadataDetails
            if let existingMetadata = try? mp4Handler.readFullMetadata(at: file) {
                metadata = existingMetadata
            } else if let selectedDetails = selectedResultDetails {
                metadata = selectedDetails
            } else {
                metadata = MetadataDetails(id: file.absoluteString, title: file.deletingPathExtension().lastPathComponent)
            }
            
            // Create tags with artwork
            let tags = mp4TagUpdates(from: metadata, coverData: artworkData)
            
            // Write metadata with artwork
            try mp4Handler.writeMetadata(metadata, tags: tags, to: file)
            
            await MainActor.run {
                self.status = "Artwork applied successfully"
                // Clear artwork picker state
                self.showArtworkPicker = false
            }
            await statusStream.add("Artwork applied to \(file.lastPathComponent)")
        } catch {
            await MainActor.run {
                self.status = "Failed to apply artwork: \(error.localizedDescription)"
            }
            await statusStream.add("Failed to apply artwork to \(file.lastPathComponent): \(error.localizedDescription)")
        }
    }

    public func enrich(file url: URL) {
        Task {
            do {
                status = "Enriching \(url.lastPathComponent)"
                let details = try await pipeline.enrich(file: url, includeAdult: adultEnabled, preference: providerPreference, onAmbiguous: { choices in
                    let match = AmbiguousMatch(file: url, choices: choices)
                    if let auto = self.autoResolve(match: match) {
                        return auto
                    }
                    await MainActor.run { [weak self] in
                        self?.pendingAmbiguity = match
                        self?.ambiguityQueue.append(match)
                        self?.showAmbiguitySheet = true
                        self?.status = "Ambiguous match for \(url.lastPathComponent); pick a result"
                    }
                    return nil // defer resolution
                })
                if let details = details {
                    let coverURL = artworkOverrides[url] ?? details.coverURL
                    let cover = await artworkCache.fetchArtwork(from: coverURL)
                    _ = mp4TagUpdates(from: details, coverData: cover)
                    status = "Updated metadata for \(details.title)"
                    await MainActor.run { self.fileMetadata[url] = details }
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

    // Batch via JobQueue
    public func enqueueCurrentSelection() {
        let targets: [URL]
        if let selectedFile {
            targets = [selectedFile]
        } else {
            targets = mediaFiles
        }
        guard !targets.isEmpty else {
            status = "No files to enqueue"
            return
        }
        enqueueBatch(urls: targets)
        status = "Queued \(targets.count) file\(targets.count == 1 ? "" : "s") for batch"
    }

    public func openSettings() {
        // placeholder for future deep links
    }

    public func openHelp() {
        if let url = URL(string: "https://github.com/roto31/SublerPlus/wiki") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openWebUIInBrowser() {
        if let url = URL(string: "http://127.0.0.1:8080/") {
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
                fileMetadata[match.file] = choice
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
                        let details = try await self.pipeline.enrich(file: job.url, includeAdult: self.adultEnabled, preference: self.providerPreference, onAmbiguous: { choices in
                            let match = AmbiguousMatch(file: job.url, choices: choices)
                            if let auto = await MainActor.run(body: { self.autoResolve(match: match) }) { return auto }
                            await MainActor.run { [weak self] in
                                self?.ambiguityQueue.append(match)
                                self?.pendingAmbiguity = match
                                self?.showAmbiguitySheet = true
                                self?.status = "Ambiguous match for \(job.url.lastPathComponent); pick a result"
                            }
                            return nil // defer
                        })
                        if let details = details {
                            let coverURL = await MainActor.run { self.artworkOverrides[job.url] ?? details.coverURL }
                            let cover = await self.artworkCache.fetchArtwork(from: coverURL)
                            _ = mp4TagUpdates(from: details, coverData: cover)
                            await self.jobQueue.update(jobID: job.id, status: .succeeded, message: details.title)
                            await MainActor.run { self.fileMetadata[job.url] = details }
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

    public func job(for url: URL) -> Job? {
        jobs.last { $0.url == url }
    }

    public func tracks(for url: URL) -> [MediaTrack]? {
        fileTracks[url]
    }

    public func chapters(for url: URL) -> [Chapter]? {
        fileChapters[url]
    }

    // Subtitle candidates (last fetched per file)
    private var subtitleCandidates: [URL: [SubtitleCandidate]] = [:]

    public func subtitles(for url: URL) -> [SubtitleCandidate]? {
        subtitleCandidates[url]
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
        let show = choice.show?.lowercased()
        if let show {
            return AmbiguityResolutionKey(title: show, year: choice.seasonNumber, studio: studio)
        }
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

    public func clearArtworkCache() {
        Task {
            await artworkCache.clear()
            await MainActor.run { self.status = "Artwork cache cleared" }
        }
    }

    public func refreshArtwork(for url: URL) {
        Task {
            guard let details = fileMetadata[url] else { return }
            await artworkCache.clear()
            let coverURL = artworkOverrides[url] ?? details.coverURL
            _ = await artworkCache.fetchArtwork(from: coverURL)
            await MainActor.run { self.status = "Artwork refreshed for \(url.lastPathComponent)" }
        }
    }

    public func applyArtwork(for url: URL, to artworkURL: URL) {
        Task {
            guard let details = fileMetadata[url] else { return }
            artworkOverrides[url] = artworkURL
            let updated = details.withCover(artworkURL)
            do {
                try await pipeline.writeResolved(details: updated, to: url)
                let cover = await artworkCache.fetchArtwork(from: artworkURL)
                _ = mp4TagUpdates(from: updated, coverData: cover)
                await MainActor.run {
                    self.fileMetadata[url] = updated
                    self.status = "Applied artwork for \(url.lastPathComponent)"
                }
            } catch {
                await MainActor.run { self.status = "Artwork apply failed: \(error.localizedDescription)" }
            }
        }
    }

    // MARK: - Track inspection
    
    private func fourCCToString(_ code: FourCharCode) -> String {
        var result = ""
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        for byte in bytes {
            if byte >= 32 && byte <= 126 {
                result.append(Character(UnicodeScalar(byte)))
            } else {
                result.append("?")
            }
        }
        return result
    }

    private func inspectTracks(url: URL) async -> [MediaTrack] {
        do {
            let asset = AVURLAsset(url: url)
            _ = try await asset.load(.duration) // warm load
            var collected: [MediaTrack] = []

            for track in try await asset.load(.tracks) {
                let kind = mapKind(track.mediaType)
                let codec = track.formatDescriptions
                    .map { $0 as! CMFormatDescription }
                    .map { fourCCToString(CMFormatDescriptionGetMediaSubType($0)) }
                    .first
                let lang = try? await track.load(.languageCode)
                let bitrate = Int(track.estimatedDataRate)
                let isDefault = track.isEnabled
                let isForced = false
                var resolution: String?
                var hdr = false
                if kind == .video {
                    let dims = try? await track.load(.naturalSize)
                    if let dims {
                        resolution = "\(Int(dims.width))x\(Int(dims.height))"
                    }
                    // Check for HDR by examining format descriptions
                    if let desc = track.formatDescriptions.first {
                        let formatDesc = desc as! CMFormatDescription
                        let fourCC = CMFormatDescriptionGetMediaSubType(formatDesc)
                        // Check for HDR codecs: hev1, hvc1 (HEVC), or av01 (AV1)
                        let codecString = fourCCToString(fourCC)
                        if codecString == "hev1" || codecString == "hvc1" || codecString == "av01" {
                            // Additional HDR check: look for HDR metadata in format extensions
                            if let extensions = CMFormatDescriptionGetExtensions(formatDesc) as? [String: Any] {
                                // Check for HDR-related keys
                                if extensions["CVImageBufferTransferFunction"] != nil ||
                                   extensions["CVImageBufferColorPrimaries"] != nil {
                                    hdr = true
                                }
                            }
                        }
                    }
                }
                collected.append(
                    MediaTrack(
                        kind: kind,
                        codec: codec,
                        language: lang,
                        bitrate: bitrate,
                        isDefault: isDefault,
                        isForced: isForced,
                        resolution: resolution,
                        hdr: hdr
                    )
                )
            }
            return collected
        } catch {
            await statusStream.add("Track inspection failed: \(error.localizedDescription)")
            return []
        }
    }

    private func mapKind(_ mediaType: AVMediaType) -> MediaTrack.Kind {
        switch mediaType {
        case .video: return .video
        case .audio: return .audio
        case .subtitle, .text, .closedCaption: return .subtitle
        case .timecode: return .timecode
        case .metadata: return .metadata
        default: return .unknown
        }
    }

    // MARK: - Chapters

    private func inspectChapters(url: URL) async -> [Chapter] {
        do {
            let asset = AVURLAsset(url: url)
            let groups = try await asset.loadChapterMetadataGroups(withTitleLocale: Locale.current)
            var collected: [Chapter] = []
            for group in groups {
                let titleItem = AVMetadataItem.metadataItems(from: group.items, filteredByIdentifier: .commonIdentifierTitle).first
                let title = titleItem?.stringValue ?? "Chapter"
                let start = CMTimeGetSeconds(group.timeRange.start)
                collected.append(Chapter(title: title, startSeconds: start))
            }
            return collected.sorted { $0.startSeconds < $1.startSeconds }
        } catch {
            await statusStream.add("Chapter inspection failed: \(error.localizedDescription)")
            return []
        }
    }

    public func importChapters(for url: URL) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let path = panel.url {
            do {
                let content = try String(contentsOf: path)
                let parsed = parseChapters(text: content)
                fileChapters[url] = parsed
                status = "Imported \(parsed.count) chapters"
            } catch {
                status = "Chapter import failed: \(error.localizedDescription)"
            }
        }
    }

    public func exportChapters(for url: URL) {
        guard let chapters = fileChapters[url], !chapters.isEmpty else {
            status = "No chapters to export"
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + ".chapters.txt"
        if panel.runModal() == .OK, let dest = panel.url {
            let lines = chapters
                .sorted { $0.startSeconds < $1.startSeconds }
                .map { chapter in "\(formatTime(chapter.startSeconds)) \(chapter.title)" }
            do {
                try lines.joined(separator: "\n").write(to: dest, atomically: true, encoding: .utf8)
                status = "Exported chapters"
            } catch {
                status = "Chapter export failed: \(error.localizedDescription)"
            }
        }
    }

    private func parseChapters(text: String) -> [Chapter] {
        var chapters: [Chapter] = []
        let lines = text.split(whereSeparator: \.isNewline)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = [.pad]

        for line in lines {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count >= 1 else { continue }
            let timeString = String(parts[0])
            let title = parts.count == 2 ? String(parts[1]) : "Chapter \(chapters.count + 1)"
            if let seconds = parseTime(timeString) {
                chapters.append(Chapter(title: title, startSeconds: seconds))
            }
        }
        return chapters
    }

    private func parseTime(_ str: String) -> Double? {
        let parts = str.split(separator: ":").reversed()
        var total: Double = 0
        for (idx, part) in parts.enumerated() {
            guard let val = Double(part) else { return nil }
            total += val * pow(60, Double(idx))
        }
        return total
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

    // MARK: - Subtitles (OpenSubtitles)
    private var subtitleManager: SubtitleManager? {
        let key = apiKeys.loadOpenSubtitlesKey()
        return SubtitleManager(subtitles: OpenSubtitlesProvider(apiKey: key), language: defaultSubtitleLanguage)
    }

    public func searchSubtitles(for url: URL) {
        Task {
            let title = url.deletingPathExtension().lastPathComponent
            let year = fileMetadata[url]?.releaseDate.flatMap { Calendar.current.dateComponents([.year], from: $0).year }
            let results = await subtitleManager?.search(title: title, year: year) ?? []
            await MainActor.run {
                self.subtitleCandidates[url] = results
                self.status = results.isEmpty ? "No subtitles found" : "Found \(results.count) subtitles"
            }
        }
    }

    public func downloadAndAttachSubtitle(for url: URL, candidate: SubtitleCandidate) {
        Task {
            guard let manager = subtitleManager else {
                await MainActor.run { self.status = "OpenSubtitles key not set" }
                return
            }
            await MainActor.run { self.status = "Downloading subtitles..." }
            guard let sub = await manager.download(candidate: candidate) else {
                await MainActor.run { self.status = "Subtitle download failed" }
                return
            }
            do {
                try await manager.muxSubtitle(into: url, subtitle: sub)
                let tracks = await inspectTracks(url: url)
                await MainActor.run {
                    self.fileTracks[url] = tracks
                    self.status = "Subtitle attached (\(candidate.language))"
                }
            } catch {
                await MainActor.run { self.status = "Subtitle attach failed: \(error.localizedDescription)" }
            }
        }
    }

    // MARK: - Muxing
    
    @Published public var muxingProgress: Double = 0.0
    @Published public var isMuxing: Bool = false
    
    public func remuxFile(_ url: URL, outputURL: URL? = nil) {
        Task {
            await MainActor.run {
                isMuxing = true
                muxingProgress = 0.0
                status = "Remuxing \(url.lastPathComponent)..."
            }
            
            let output = outputURL ?? url.deletingLastPathComponent().appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)_remuxed.mp4")
            
            do {
                try await Muxer.remux(
                    sourceURL: url,
                    outputURL: output,
                    progressHandler: { progress in
                        Task { @MainActor in
                            self.muxingProgress = progress
                        }
                    }
                )
                
                await MainActor.run {
                    isMuxing = false
                    muxingProgress = 1.0
                    status = "Remuxing complete: \(output.lastPathComponent)"
                }
            } catch {
                await MainActor.run {
                    isMuxing = false
                    status = "Remuxing failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    public func muxTracks(_ tracks: [TrackSelection], outputURL: URL) {
        Task {
            await MainActor.run {
                isMuxing = true
                muxingProgress = 0.0
                status = "Muxing tracks..."
            }
            
            do {
                try await Muxer.mux(
                    tracks: tracks,
                    outputURL: outputURL,
                    progressHandler: { progress in
                        Task { @MainActor in
                            self.muxingProgress = progress
                        }
                    }
                )
                
                await MainActor.run {
                    isMuxing = false
                    muxingProgress = 1.0
                    status = "Muxing complete: \(outputURL.lastPathComponent)"
                }
            } catch {
                await MainActor.run {
                    isMuxing = false
                    status = "Muxing failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Search

    /// Executes a search query with proper error handling and state management
    /// 
    /// Threading: Network operations run off main thread, UI updates on MainActor
    private func runSearch(query: String, yearHint: Int?) async {
        // Update UI state on main thread
        await MainActor.run {
            self.isSearching = true
            self.status = "Searching..."
            self.searchError = nil
        }
        
        // Check for cancellation before starting
        guard !Task.isCancelled else {
            await MainActor.run {
                self.isSearching = false
                self.status = "Search cancelled"
            }
            return
        }
        
        // Get current settings for weights (off main thread)
        let currentSettings = await settingsStore.settings
        
        // Check for cancellation after async call
        guard !Task.isCancelled else {
            await MainActor.run {
                self.isSearching = false
                self.status = "Search cancelled"
            }
            return
        }
        
        // Update unified search manager with current settings (on main thread for @Published)
        await MainActor.run {
            self.unifiedSearchManager = UnifiedSearchManager(
                modernProviders: searchProviders,
                includeAdult: adultEnabled,
                searchCache: searchCache,
                providerWeights: currentSettings.providerWeights
            )
        }
        
        // Determine search type from query context (simplified - could be enhanced)
        // For now, default to movie search, but could analyze query to detect TV shows
        let searchType: UnifiedSearchManager.SearchType = .movie
        
        let options = UnifiedSearchManager.SearchOptions(
            query: query,
            type: searchType,
            language: nil, // Could use user preference
            providerName: nil, // Use all providers
            yearHint: yearHint
        )
        
        // Execute search off main thread
        do {
            // Check cancellation before network call
            try Task.checkCancellation()
            
            // Perform search (runs on background thread)
            let results = try await unifiedSearchManager.search(options: options)
            
            // Check cancellation after search completes
            try Task.checkCancellation()
            
            // Update UI on main thread
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
                self.searchError = nil
                
                if results.isEmpty {
                    self.status = "No results found"
                } else {
                    self.status = "Found \(results.count) result\(results.count == 1 ? "" : "s")"
                }
                
                // Clear selection and details when new search results arrive
                self.selectedSearchResult = nil
                self.selectedResultDetails = nil
            }
            
            await statusStream.add("Search completed: \(results.count) results")
            
        } catch is CancellationError {
            // Search was cancelled, update UI
            await MainActor.run {
                self.isSearching = false
                self.status = "Search cancelled"
                self.searchError = nil
            }
            await statusStream.add("Search cancelled by user")
            
        } catch {
            // Search failed, update UI with error
            let errorMessage = error.localizedDescription
            await MainActor.run {
                self.isSearching = false
                self.status = "Search failed"
                self.searchError = errorMessage
                self.searchResults = []
            }
            await statusStream.add("Search failed: \(errorMessage)")
            AppLog.error(AppLog.providers, "Search failed: \(errorMessage)")
        }
    }

    private func annotate(_ results: [MetadataResult], providerID: String) -> [MetadataResult] {
        results.map { res in
            MetadataResult(
                id: res.id,
                title: res.title,
                score: res.score,
                year: res.year,
                source: res.source ?? providerID
            )
        }
    }

    // MARK: - Folder monitoring

    public func updateWatchFolders(_ urls: [URL]) {
        let unique = Array(Set(urls.filter { $0.hasDirectoryPath }))
        let current = Set(folderMonitors.keys)
        let desired = Set(unique)

        // Stop removed monitors
        let toStop = current.subtracting(desired)
        for folder in toStop {
            folderMonitors[folder]?.stop()
            folderMonitors.removeValue(forKey: folder)
        }

        // Start new monitors
        for folder in desired where folderMonitors[folder] == nil {
            let monitor = FolderMonitor()
            do {
                try monitor.startMonitoring(url: folder) { [weak self] in
                    Task { @MainActor in self?.handleFolderEvent(folder) }
                }
                folderMonitors[folder] = monitor
                handleFolderEvent(folder) // initial scan
                Task { await statusStream.add("Watching folder: \(folder.lastPathComponent)") }
            } catch {
                status = "Failed to watch \(folder.lastPathComponent): \(error.localizedDescription)"
            }
        }
        watchFolders = unique
    }

    private func handleFolderEvent(_ folder: URL) {
        Task { [weak self] in
            guard let self else { return }
            let files = collectMediaFiles(at: folder)
            await MainActor.run {
                let newFiles = files.filter { !self.watchedKnownFiles.contains($0) }
                guard !newFiles.isEmpty else { return }
                newFiles.forEach { self.watchedKnownFiles.insert($0) }

                let unseenInUI = newFiles.filter { !self.mediaFiles.contains($0) }
                if !unseenInUI.isEmpty {
                    self.mediaFiles.append(contentsOf: unseenInUI)
                }
                self.enqueueBatch(urls: newFiles)
                self.status = "Queued \(newFiles.count) file\(newFiles.count == 1 ? "" : "s") from \(folder.lastPathComponent)"
            }
        }
    }
}

private let supportedMediaExtensions: Set<String> = ["mp4", "m4v", "mov"]

private func collectMediaFiles(at folder: URL) -> [URL] {
    var results: [URL] = []
    if let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) {
        for case let file as URL in enumerator {
            if supportedMediaExtensions.contains(file.pathExtension.lowercased()) {
                results.append(file)
            }
        }
    }
    return results
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
    @Published public var generateNFO: Bool = false
    @Published public var nfoOutputDirectory: URL?
    @Published public var tvNamingTemplate: String = "S%02dE%02d - %t"
    @Published public var watchFolders: [URL] = []
    @Published public var openSubtitlesKey: String = ""
    @Published public var defaultSubtitleLanguage: String = "eng"
    @Published public var autoSubtitleLookup: Bool = false
    @Published public var iTunesCountry: String = "us"
    @Published public var preferHighResArtwork: Bool = true
    @Published public var enableMusicMetadata: Bool = true
    @Published public var musixmatchKey: String = ""
    @Published public var providerWeights: [String: Double] = [:]

    private let settingsStore: SettingsStore
    private let apiKeys: APIKeyManager
    private let pipeline: MetadataPipeline
    private var lastRotation: Date?

    public init(settingsStore: SettingsStore, apiKeys: APIKeyManager, pipeline: MetadataPipeline) {
        self.settingsStore = settingsStore
        self.apiKeys = apiKeys
        self.pipeline = pipeline
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
        generateNFO = settings.generateNFO
        nfoOutputDirectory = settings.nfoOutputDirectory.flatMap { URL(fileURLWithPath: $0) }
        tvNamingTemplate = settings.tvNamingTemplate
        watchFolders = settings.watchFolders.compactMap { URL(string: $0) ?? URL(fileURLWithPath: $0) }
        openSubtitlesKey = apiKeys.loadOpenSubtitlesKey() ?? ""
        defaultSubtitleLanguage = settings.defaultSubtitleLanguage
        autoSubtitleLookup = settings.autoSubtitleLookup
        iTunesCountry = settings.iTunesCountry
        preferHighResArtwork = settings.preferHighResArtwork
        enableMusicMetadata = settings.enableMusicMetadata
        musixmatchKey = apiKeys.loadMusixmatchKey() ?? ""
        providerWeights = settings.providerWeights.weights
    }

    public func save() {
        Task {
            await settingsStore.update { settings in
                settings.adultEnabled = adultEnabled
                settings.tpdbConfidence = tpdbConfidence
                settings.lastKeyRotation = lastRotation
                settings.retainOriginals = retainOriginals
                settings.outputDirectory = outputDirectory?.path
                settings.generateNFO = generateNFO
                settings.nfoOutputDirectory = nfoOutputDirectory?.path
                settings.tvNamingTemplate = tvNamingTemplate
                settings.watchFolders = watchFolders.map { $0.path }
                settings.defaultSubtitleLanguage = defaultSubtitleLanguage
                settings.autoSubtitleLookup = autoSubtitleLookup
                settings.iTunesCountry = iTunesCountry
                settings.preferHighResArtwork = preferHighResArtwork
                settings.enableMusicMetadata = enableMusicMetadata
                settings.providerWeights = ProviderWeights(weights: providerWeights)
            }
            pipeline.retainOriginals = retainOriginals
            pipeline.outputDirectory = outputDirectory
            pipeline.generateNFO = generateNFO
            pipeline.nfoOutputDirectory = nfoOutputDirectory
            pipeline.tvNamingTemplate = tvNamingTemplate
            pipeline.autoSubtitleLookup = autoSubtitleLookup
            apiKeys.saveTPDBKey(tpdbKey)
            apiKeys.saveTMDBKey(tmdbKey)
            apiKeys.saveTVDBKey(tvdbKey)
            if !webToken.isEmpty {
                apiKeys.saveWebToken(webToken)
            }
            if !openSubtitlesKey.isEmpty {
                apiKeys.saveOpenSubtitlesKey(openSubtitlesKey)
            }
            if !musixmatchKey.isEmpty {
                apiKeys.saveMusixmatchKey(musixmatchKey)
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

    public func pickNFOOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            nfoOutputDirectory = url
        }
    }

    public func addWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            let urls = panel.urls
            let existing = Set(watchFolders)
            let merged = existing.union(urls)
            watchFolders = Array(merged)
        }
    }

    public func removeWatchFolder(_ url: URL) {
        watchFolders.removeAll { $0 == url }
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

