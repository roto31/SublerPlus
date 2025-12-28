import SwiftUI
import SublerPlusCore

@main
struct SublerPlusApp: App {
    @StateObject private var dependencyManager = DependencyManager()
    private let dependencies = AppDependencies.build()
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize file logging at app startup
        initializeFileLogging()
    }

    var body: some Scene {
        WindowGroup {
            RootShellView(viewModel: dependencies.appViewModel, settingsViewModel: dependencies.settingsViewModel, statusStream: dependencies.statusStream)
                .frame(minWidth: 840, minHeight: 540)
                .environmentObject(dependencies.appViewModel)
                .sheet(isPresented: $dependencyManager.showDependencyCheck) {
                    DependencyCheckView {
                        dependencyManager.markAsChecked()
                    }
                }
                .task {
                    dependencyManager.checkIfNeeded()
                    // Initialize AppleScript support after dependencies are ready
                    appDelegate.initialize(jobQueue: dependencies.jobQueue, statusStream: dependencies.statusStream)
                    AppleScriptBridge.shared.initialize(jobQueue: dependencies.jobQueue, statusStream: dependencies.statusStream)
                    AppleScriptBridge.shared.registerScriptCommands()
                }
        }
        Settings {
            SettingsView(viewModel: dependencies.settingsViewModel)
                .frame(width: 520, height: 320)
                .environmentObject(dependencies.appViewModel)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Files") {
                    dependencies.appViewModel.presentFilePicker()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            CommandMenu("View") {
                Button("Open Web UI in Browser") {
                    dependencies.appViewModel.openWebUIInBrowser()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandMenu("Actions") {
                Button("Enrich Selected") {
                    dependencies.appViewModel.enrichSelected()
                }
                .keyboardShortcut("e", modifiers: [.command])

                Button("Refresh Status") {
                    Task { await dependencies.appViewModel.refreshJobs() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            CommandMenu("Help") {
                Button("Open Help (Wiki)") {
                    dependencies.appViewModel.openHelp()
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }
    }
}

struct AppDependencies {
    let appViewModel: AppViewModel
    let settingsViewModel: SettingsViewModel
    let webServer: WebServer?
    let statusStream: StatusStream
    let jobQueue: JobQueue

    @MainActor
    static func build() -> AppDependencies {
        return buildSync()
    }
    
    @MainActor
    static func buildSync() -> AppDependencies {
        let keychain = KeychainController()
        let apiKeys = APIKeyManager(store: keychain)
        let settingsStore = SettingsStore(keychain: keychain)

        let tpdbKey = keychain.get(key: "tpdb") ??
            ProcessInfo.processInfo.environment["TPDB_API_KEY"] ?? ""
        let tpdbClient = TPDBClient(apiKey: tpdbKey)
        let tpdbProvider = ThePornDBProvider(client: tpdbClient)
        let tmdbKey = keychain.get(key: "tmdb") ?? ProcessInfo.processInfo.environment["TMDB_API_KEY"]
        let tmdbProvider = StandardMetadataProvider(apiKey: tmdbKey)
        let tvdbKey = keychain.get(key: "tvdb") ?? ProcessInfo.processInfo.environment["TVDB_API_KEY"]
        let tvdbProvider = TVDBProvider(apiKey: tvdbKey)

        let adapter = SearchProviderAdapter(
            provider: tpdbProvider,
            selector: { results, _ in
                results.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.first
            },
            minimumConfidence: 0.5
        )

        let mp4 = SublerMP4Handler()
        let sublerProvider = SublerProvider(mp4Handler: mp4)

        var providerList: [PipelineMetadataProvider] = [adapter]
        if let tmdbProvider {
            let tmdbAdapter = SearchProviderAdapter(
                provider: tmdbProvider,
                selector: { results, hint in
                    // Pick best by score, then closest year to hint
                    let sorted = results.sorted {
                        let lhsScore = $0.score ?? 0
                        let rhsScore = $1.score ?? 0
                        if lhsScore == rhsScore, let hy = hint.year, let ly = $0.year, let ry = $1.year {
                            return abs(hy - ly) < abs(hy - ry)
                        }
                        return lhsScore > rhsScore
                    }
                    return sorted.first
                }
            )
            providerList.append(tmdbAdapter)
        }
        if let tvdbProvider {
            let tvdbAdapter = SearchProviderAdapter(
                provider: tvdbProvider,
                selector: { results, hint in
                    let sorted = results.sorted {
                        let lhsScore = $0.score ?? 0
                        let rhsScore = $1.score ?? 0
                        if lhsScore == rhsScore, let hy = hint.year, let ly = $0.year, let ry = $1.year {
                            return abs(hy - ly) < abs(hy - ry)
                        }
                        return lhsScore > rhsScore
                    }
                    return sorted.first
                }
            )
            providerList.append(tvdbAdapter)
        }
        providerList.append(sublerProvider)

        let registry = ProvidersRegistry(providers: providerList)
        let artworkCache = ArtworkCacheManager()
        
        // Create SubtitleManager for automatic subtitle lookup
        let openSubtitlesKey = keychain.get(key: "opensubtitles") ?? ProcessInfo.processInfo.environment["OPENSUBTITLES_API_KEY"]
        // Use default language "eng" initially, will be updated from settings
        let subtitleManager = SubtitleManager(
            subtitles: OpenSubtitlesProvider(apiKey: openSubtitlesKey),
            language: "eng"
        )
        
        let pipeline = MetadataPipeline(registry: registry, mp4Handler: mp4, artwork: artworkCache, subtitleManager: subtitleManager)
        Task {
            let settingsSnapshot = await settingsStore.settings
            pipeline.retainOriginals = settingsSnapshot.retainOriginals
            if let outputPath = settingsSnapshot.outputDirectory {
                pipeline.outputDirectory = URL(fileURLWithPath: outputPath)
            }
            pipeline.generateNFO = settingsSnapshot.generateNFO
            if let nfoPath = settingsSnapshot.nfoOutputDirectory {
                pipeline.nfoOutputDirectory = URL(fileURLWithPath: nfoPath)
            }
            pipeline.tvNamingTemplate = settingsSnapshot.tvNamingTemplate
            pipeline.autoSubtitleLookup = settingsSnapshot.autoSubtitleLookup
        }
        let statusStream = StatusStream()
        let jobQueue = JobQueue(concurrency: 2, statusStream: statusStream)
        let webToken = keychain.get(key: "webui_token") ?? ProcessInfo.processInfo.environment["WEBUI_TOKEN"]
        // Require authentication by default for security
        let requireAuth = true
        let webServer = WebServer(
            pipeline: pipeline,
            registry: registry,
            status: statusStream,
            authToken: webToken,
            requireAuth: requireAuth
        )
        Task {
            do {
                try webServer.start(port: 8080)
                if webToken == nil || webToken?.isEmpty == true {
                    await statusStream.add("SECURITY WARNING: WebUI authentication is required but no token is set. Please set WEBUI_TOKEN in Settings.")
                } else {
                    await statusStream.add("WebUI started with authentication enabled on http://127.0.0.1:8080")
                }
            } catch {
                await statusStream.add("WebUI server failed: \(error.localizedDescription)")
            }
        }

        var searchProviders: [MetadataProvider] = [tpdbProvider]
        if let tmdbProvider { searchProviders.append(tmdbProvider) }
        if let tvdbProvider { searchProviders.append(tvdbProvider) }

        let appVM = AppViewModel(
            settingsStore: settingsStore,
            pipeline: pipeline,
            adultProvider: tpdbProvider,
            searchProviders: searchProviders,
            artworkCache: artworkCache,
            apiKeys: apiKeys,
            jobQueue: jobQueue,
            statusStream: statusStream,
            tpdbProvider: tpdbProvider,
            tvdbProvider: tvdbProvider,
            tmdbProvider: tmdbProvider
        )
        let settingsVM = SettingsViewModel(settingsStore: settingsStore, apiKeys: apiKeys, pipeline: pipeline)

        return AppDependencies(appViewModel: appVM, settingsViewModel: settingsVM, webServer: webServer, statusStream: statusStream, jobQueue: jobQueue)
    }
}

