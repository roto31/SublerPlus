import Foundation
import Swifter
import SublerPlusCore

public final class WebServer {
    private let server = HttpServer()
    private let pipeline: MetadataPipeline
    private let registry: ProvidersRegistry

    public init(pipeline: MetadataPipeline, registry: ProvidersRegistry) {
        self.pipeline = pipeline
        self.registry = registry
    }

    public func start(port: in_port_t = 8080) throws {
        server["/health"] = { _ in .ok(.text("ok")) }
        server["/search"] = { [weak self] request in
            guard let self else { return .internalServerError }
            let query = request.queryParams.first(where: { $0.0 == "q" })?.1 ?? ""
            let providers = self.registry.all(includeAdult: true)
            let tasks = providers.map { provider in
                Task { try? await provider.fetch(for: URL(fileURLWithPath: "/dev/null"), hint: MetadataHint(title: query)) }
            }
            let results = tasks.compactMap { task -> MetadataDetails? in try? await task.value }
            let payload = (try? JSONEncoder().encode(results.map { $0.title })) ?? Data("[]".utf8)
            return .ok(.data(payload, contentType: "application/json"))
        }
        try server.start(port)
    }

    public func stop() {
        server.stop()
    }
}

