import Foundation
import SublerPlusCore

@main
struct SublerPlusCLI {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        var includeAdult = true
        var autoSelectBest = false
        var paths: [String] = []

        for arg in args {
            switch arg {
            case "--no-adult":
                includeAdult = false
            case "--auto-best":
                autoSelectBest = true
            default:
                paths.append(arg)
            }
        }

        guard !paths.isEmpty else {
            print("Usage: sublerplus-cli [--no-adult] [--auto-best] <media-file-or-folder> [...]")
            return
        }

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

        var allFiles: [URL] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            allFiles.append(contentsOf: collectMediaFiles(at: url))
        }
        let uniqueFiles = Array(Set(allFiles))
        if uniqueFiles.isEmpty {
            print("No media files found in provided paths.")
            return
        }

        print("Processing \(uniqueFiles.count) file(s) \(includeAdult ? "with" : "without") adult providers...")
        for fileURL in uniqueFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let details = try await pipeline.enrich(
                    file: fileURL,
                    includeAdult: includeAdult,
                    preference: .balanced,
                    onAmbiguous: { choices in
                        Self.logAmbiguity(file: fileURL, choices: choices, autoSelect: autoSelectBest)
                    }
                )
                if let details {
                    print("✓ \(fileURL.lastPathComponent) → \(details.title)")
                } else {
                    print("⚠️  Skipped \(fileURL.lastPathComponent) (ambiguous)")
                }
            } catch {
                print("✖︎ \(fileURL.lastPathComponent): \(error.localizedDescription)")
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

    private static func logAmbiguity(file: URL, choices: [MetadataDetails], autoSelect: Bool) -> MetadataDetails? {
        print("Ambiguous matches for \(file.lastPathComponent):")
        for (idx, choice) in choices.enumerated() {
            let year = choice.releaseDate.flatMap { Calendar.current.dateComponents([.year], from: $0).year }
            let provider = choice.source ?? "unknown"
            let score = choice.rating.map { String(format: "%.2f", $0) } ?? "–"
            if let year {
                print("  \(idx + 1). \(choice.title) (\(year)) [\(provider)] score: \(score)")
            } else {
                print("  \(idx + 1). \(choice.title) [\(provider)] score: \(score)")
            }
        }
        guard autoSelect else {
            print("  Skipping; rerun with --auto-best to pick the top match.")
            return nil
        }
        let best = choices.max { ($0.rating ?? 0) < ($1.rating ?? 0) } ?? choices.first
        if let best {
            print("  Auto-selecting: \(best.title)")
        }
        return best
    }
}

