import Foundation
import SublerPlusCore

@main
struct SublerPlusCLI {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        guard let first = args.first else {
            print("Usage: sublerplus-cli <media-file>")
            return
        }
        let fileURL = URL(fileURLWithPath: first)
        let keychain = KeychainController()
        let mp4 = SublerMP4Handler()
        let tpdbKey = keychain.get(key: "tpdb") ??
            ProcessInfo.processInfo.environment["TPDB_API_KEY"] ?? ""
        let tpdbProvider = ThePornDBProvider(client: TPDBClient(apiKey: tpdbKey))
        let adapter = SearchProviderAdapter(
            provider: tpdbProvider,
            selector: { results, _ in results.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.first }
        )

        let tmdbKey = ProcessInfo.processInfo.environment["TMDB_API_KEY"]
        let tmdbProvider = StandardMetadataProvider(apiKey: tmdbKey)
        var providers: [PipelineMetadataProvider] = [adapter]
        if let tmdbProvider {
            let tmdbAdapter = SearchProviderAdapter(
                provider: tmdbProvider,
                selector: { results, _ in results.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.first }
            )
            providers.append(tmdbAdapter)
        }
        providers.append(SublerProvider(mp4Handler: mp4))
        let registry = ProvidersRegistry(providers: providers)
        let pipeline = MetadataPipeline(registry: registry, mp4Handler: mp4)

        do {
            let details = try await pipeline.enrich(file: fileURL, includeAdult: true)
            if let details {
                print("Updated metadata for \(details.title)")
            } else {
                print("Ambiguous match for \(fileURL.lastPathComponent); please resolve in app.")
            }
        } catch {
            print("Failed: \(error)")
        }
    }
}

