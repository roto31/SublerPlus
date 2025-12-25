import SwiftUI
import SublerPlusCore

@main
struct SublerPlusApp: App {
    private let dependencies = AppDependencies.build()

    var body: some Scene {
        WindowGroup {
            RootShellView(viewModel: dependencies.appViewModel, settingsViewModel: dependencies.settingsViewModel, statusStream: dependencies.statusStream)
                .frame(minWidth: 840, minHeight: 540)
                .environmentObject(dependencies.appViewModel)
        }
        Settings {
            SettingsView(viewModel: dependencies.settingsViewModel)
                .frame(width: 400, height: 220)
                .environmentObject(dependencies.appViewModel)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Files") {
                    dependencies.appViewModel.presentFilePicker()
                }
                .keyboardShortcut("n", modifiers: [.command])
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
        let keychain = KeychainController()
        let apiKeys = APIKeyManager(store: keychain)
        let settingsStore = SettingsStore(keychain: keychain)

        let tpdbKey = keychain.get(key: "tpdb") ??
            ProcessInfo.processInfo.environment["TPDB_API_KEY"] ?? ""
        let tpdbClient = TPDBClient(apiKey: tpdbKey)
        let tpdbProvider = ThePornDBProvider(client: tpdbClient)
        let tmdbKey = ProcessInfo.processInfo.environment["TMDB_API_KEY"]
        let tmdbProvider = StandardMetadataProvider(apiKey: tmdbKey)
        let tvdbKey = ProcessInfo.processInfo.environment["TVDB_API_KEY"]
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
        let pipeline = MetadataPipeline(registry: registry, mp4Handler: mp4, artwork: artworkCache)
        let statusStream = StatusStream()
        let jobQueue = JobQueue(concurrency: 2, statusStream: statusStream)
        let webToken = keychain.get(key: "webui_token") ?? ProcessInfo.processInfo.environment["WEBUI_TOKEN"]
        let webServer = WebServer(pipeline: pipeline, registry: registry, status: statusStream, authToken: webToken)
        Task {
            do {
                try webServer.start(port: 8080)
            } catch {
                await statusStream.add("WebUI server failed: \(error.localizedDescription)")
            }
        }

        let appVM = AppViewModel(
            settingsStore: settingsStore,
            pipeline: pipeline,
            adultProvider: tpdbProvider,
            artworkCache: artworkCache,
            apiKeys: apiKeys,
            jobQueue: jobQueue,
            statusStream: statusStream
        )
        let settingsVM = SettingsViewModel(settingsStore: settingsStore, apiKeys: apiKeys)

        return AppDependencies(appViewModel: appVM, settingsViewModel: settingsVM, webServer: webServer, statusStream: statusStream, jobQueue: jobQueue)
    }
}

