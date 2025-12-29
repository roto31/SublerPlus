import SwiftUI
import SublerPlusCore
import MCPServer

@main
struct SublerPlusApp: App {
    @StateObject private var dependencyManager = DependencyManager()
    @State private var dependencies: AppDependencies?
    @State private var showAboutWindow = false
    @State private var isInitializing = false
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize file logging at app startup
        initializeFileLogging()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let dependencies = dependencies {
                    RootShellView(viewModel: dependencies.appViewModel, settingsViewModel: dependencies.settingsViewModel, statusStream: dependencies.statusStream)
                        .frame(minWidth: 840, minHeight: 540)
                        .environmentObject(dependencies.appViewModel)
                        .sheet(isPresented: $dependencyManager.showDependencyCheck) {
                            DependencyCheckView {
                                dependencyManager.markAsChecked()
                            }
                        }
                        .sheet(isPresented: $showAboutWindow) {
                            AboutView()
                        }
                } else {
                    ProgressView("Loading...")
                }
            }
            .task {
                // Prevent concurrent initialization
                guard !isInitializing, dependencies == nil else { return }
                isInitializing = true
                defer { isInitializing = false }
                
                dependencies = await AppDependencies.build()
                
                if let dependencies = dependencies {
                    dependencyManager.checkIfNeeded()
                    // Initialize AppleScript support after dependencies are ready
                    appDelegate.initialize(
                        jobQueue: dependencies.jobQueue,
                        statusStream: dependencies.statusStream,
                        webServer: dependencies.webServer,
                        mcpServer: dependencies.mcpServer
                    )
                    AppleScriptBridge.shared.initialize(jobQueue: dependencies.jobQueue, statusStream: dependencies.statusStream)
                }
                AppleScriptBridge.shared.registerScriptCommands()
            }
        }
        Settings {
            if let dependencies = dependencies {
                SettingsView(viewModel: dependencies.settingsViewModel)
                    .frame(minWidth: 600, minHeight: 400)
                    .environmentObject(dependencies.appViewModel)
            }
        }
        
        .commands {
            // App menu: About, Preferences, Quit
            CommandGroup(replacing: .appInfo) {
                Button("About SublerPlus") {
                    showAboutWindow = true
                }
            }
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Preferences...") {
                    NSApplication.shared.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            
            // File menu: New, Open, Close
            CommandGroup(replacing: .newItem) {
                Button("Add Files") {
                    dependencies?.appViewModel.presentFilePicker()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
            // Note: "Add Files" uses ⌘O (standard Open shortcut)
            // "Open Web UI" uses ⌘⇧O to avoid conflict
            CommandGroup(replacing: .saveItem) {}
            CommandGroup(after: .saveItem) {
                Divider()
                Button("Close Window") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: [.command])
            }
            
            // Edit menu: Standard items are provided by SwiftUI automatically
            
            // View menu
            CommandMenu("View") {
                Button("Open Web UI in Browser") {
                    dependencies?.appViewModel.openWebUIInBrowser()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .accessibilityLabel("Open Web UI in Browser")
            }
            
            // Window menu
            CommandGroup(replacing: .windowSize) {}
            CommandGroup(after: .windowArrangement) {
                Divider()
                Button("Minimize") {
                    NSApplication.shared.keyWindow?.miniaturize(nil)
                }
                .keyboardShortcut("m", modifiers: [.command])
                Button("Zoom") {
                    NSApplication.shared.keyWindow?.zoom(nil)
                }
            }
            
            // Actions menu
            CommandMenu("Actions") {
                Button("Enrich Selected") {
                    dependencies?.appViewModel.enrichSelected()
                }
                .keyboardShortcut("e", modifiers: [.command])

                Button("Refresh Status") {
                    Task { await dependencies?.appViewModel.refreshJobs() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            
            // Help menu
            CommandMenu("Help") {
                Button("Open Help (Wiki)") {
                    dependencies?.appViewModel.openHelp()
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
    let mcpServer: MCPServer?
    let statusStream: StatusStream
    let jobQueue: JobQueue

    @MainActor
    static func build() async -> AppDependencies {
        return await buildSync()
    }
    
    @MainActor
    static func buildSync() async -> AppDependencies {
        let keychain = KeychainController()
        let apiKeys = APIKeyManager(store: keychain)
        let settingsStore = SettingsStore(keychain: keychain)

        // Initialize TPDB provider only if API key is available
        let tpdbKey = keychain.get(key: "tpdb") ??
            ProcessInfo.processInfo.environment["TPDB_API_KEY"] ?? ""
        let tpdbProvider: ThePornDBProvider?
        if !tpdbKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let tpdbClient = TPDBClient(apiKey: tpdbKey)
            tpdbProvider = ThePornDBProvider(client: tpdbClient)
            AppLog.info(AppLog.providers, "TPDB provider initialized with API key")
        } else {
            tpdbProvider = nil
            AppLog.info(AppLog.providers, "⚠️ TPDB provider not initialized: API key not found in keychain or environment")
        }
        let tmdbKey = keychain.get(key: "tmdb") ?? ProcessInfo.processInfo.environment["TMDB_API_KEY"]
        let tmdbProvider = StandardMetadataProvider(apiKey: tmdbKey)
        let tvdbKey = keychain.get(key: "tvdb") ?? ProcessInfo.processInfo.environment["TVDB_API_KEY"]
        let tvdbProvider = TVDBProvider(apiKey: tvdbKey)

        let mp4 = SublerMP4Handler()
        let sublerProvider = SublerProvider(mp4Handler: mp4)

        var providerList: [PipelineMetadataProvider] = []
        
        // Add TPDB adapter only if provider is available and configured
        if let tpdbProvider = tpdbProvider, tpdbProvider.isConfigured {
            let adapter = SearchProviderAdapter(
                provider: tpdbProvider,
                selector: { results, _ in
                    results.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.first
                },
                minimumConfidence: 0.5
            )
            providerList.append(adapter)
            AppLog.info(AppLog.providers, "TPDB adapter added to provider list")
        } else {
            AppLog.info(AppLog.providers, "TPDB adapter skipped: provider not configured")
        }
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
        
        // Get initial settings for pipeline
        let initialSettings = await settingsStore.settings
        let pipeline = MetadataPipeline(registry: registry, mp4Handler: mp4, artwork: artworkCache, subtitleManager: subtitleManager, settings: initialSettings)
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
            pipeline.tvNamingTokens = settingsSnapshot.tvNamingTokens
            pipeline.autoSubtitleLookup = settingsSnapshot.autoSubtitleLookup
            pipeline.updateSettings(settingsSnapshot)
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
        
        // Start MCP Server if enabled
        let mcpToken = keychain.get(key: "mcp_token") ?? ProcessInfo.processInfo.environment["MCP_TOKEN"]
        let mcpEnabled = ProcessInfo.processInfo.environment["MCP_ENABLED"] == "true" || mcpToken != nil
        var mcpServer: MCPServer? = nil
        if mcpEnabled {
            do {
                mcpServer = try MCPIntegration.startMCPServer(
                    pipeline: pipeline,
                    registry: registry,
                    statusStream: statusStream,
                    jobQueue: jobQueue,
                    port: 8081,
                    authToken: mcpToken
                )
                await statusStream.add("MCP Server started on http://127.0.0.1:8081")
            } catch {
                await statusStream.add("MCP Server failed to start: \(error.localizedDescription)")
            }
        }

        // Build search providers list - only include configured providers
        var searchProviders: [MetadataProvider] = []
        if let tpdbProvider = tpdbProvider, tpdbProvider.isConfigured {
            searchProviders.append(tpdbProvider)
            AppLog.info(AppLog.providers, "TPDB added to search providers list")
        } else {
            AppLog.info(AppLog.providers, "TPDB not added to search providers: not configured")
        }
        if let tmdbProvider { searchProviders.append(tmdbProvider) }
        if let tvdbProvider { searchProviders.append(tvdbProvider) }

        let appVM = AppViewModel(
            settingsStore: settingsStore,
            pipeline: pipeline,
            adultProvider: tpdbProvider ?? ThePornDBProvider(client: TPDBClient(apiKey: "")),
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

        return AppDependencies(appViewModel: appVM, settingsViewModel: settingsVM, webServer: webServer, mcpServer: mcpServer, statusStream: statusStream, jobQueue: jobQueue)
    }
}
