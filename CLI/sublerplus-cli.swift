import Foundation
import SublerPlusCore

@main
struct SublerPlusCLI {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        guard let first = args.first else {
            print("Usage: sublerplus-cli <media-file-or-folder>")
            return
        }
        let pathURL = URL(fileURLWithPath: first)
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

        let files = collectMediaFiles(at: pathURL)
        if files.isEmpty {
            print("No media files found at \(pathURL.path)")
            return
        }
        for fileURL in files {
            do {
                let details = try await pipeline.enrich(file: fileURL, includeAdult: true, preference: .balanced)
                if let details {
                    print("Updated metadata for \(fileURL.lastPathComponent): \(details.title)")
                } else {
                    print("Ambiguous match for \(fileURL.lastPathComponent); please resolve in app.")
                }
            } catch {
                print("Failed for \(fileURL.lastPathComponent): \(error)")
            }
        }
    }

    private static func collectMediaFiles(at url: URL) -> [URL] {
        var results: [URL] = []
        let exts = ["mp4","m4v","mov"]
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                for case let file as URL in enumerator {
                    if exts.contains(file.pathExtension.lowercased()) {
                        results.append(file)
                    }
                }
            }
        } else if exts.contains(url.pathExtension.lowercased()) {
            results.append(url)
        }
        return results
    }
}

