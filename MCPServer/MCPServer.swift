import Foundation
import SublerPlusCore
import Swifter

/// MCP (Model Context Protocol) Server for SublerPlus
/// Provides resources and tools for AI assistants to interact with SublerPlus
public final class MCPServer {
    private let pipeline: MetadataPipeline
    private let registry: ProvidersRegistry
    private let statusStream: StatusStream
    private let jobQueue: JobQueue
    private let server: HttpServer
    private let port: UInt16
    private let authToken: String?
    
    public init(
        pipeline: MetadataPipeline,
        registry: ProvidersRegistry,
        statusStream: StatusStream,
        jobQueue: JobQueue,
        port: UInt16 = 8081,
        authToken: String? = nil
    ) {
        self.pipeline = pipeline
        self.registry = registry
        self.statusStream = statusStream
        self.jobQueue = jobQueue
        self.port = port
        self.authToken = authToken
        self.server = HttpServer()
    }
    
    public func start() throws {
        setupResources()
        setupTools()
        setupProtocol()
        
        try server.start(port, forceIPv4: true)
        Task {
            await statusStream.add("MCP Server started on http://127.0.0.1:\(port)")
        }
    }
    
    public func stop() {
        server.stop()
    }
    
    // MARK: - MCP Protocol Setup
    
    private func setupProtocol() {
        // MCP Protocol endpoints
        server["/mcp/v1/initialize"] = { [weak self] req in
            guard let self else { return .internalServerError }
            guard self.authorized(req) else { return self.errorResponse(401, "Unauthorized") }
            
            struct InitializeResponse: Codable {
                let protocolVersion: String
                let capabilities: ServerCapabilities
                let serverInfo: ServerInfo
            }
            
            struct ServerCapabilities: Codable {
                let resources: ResourceCapabilities
                let tools: ToolCapabilities
            }
            
            struct ResourceCapabilities: Codable {
                let subscribe: Bool
                let listChanged: Bool
            }
            
            struct ToolCapabilities: Codable {
                let listChanged: Bool
            }
            
            struct ServerInfo: Codable {
                let name: String
                let version: String
            }
            
            let response = InitializeResponse(
                protocolVersion: "2024-11-05",
                capabilities: ServerCapabilities(
                    resources: ResourceCapabilities(subscribe: true, listChanged: true),
                    tools: ToolCapabilities(listChanged: true)
                ),
                serverInfo: ServerInfo(name: "SublerPlus MCP Server", version: "0.4.0")
            )
            
            return self.jsonResponse(response)
        }
        
        // Health check
        server["/mcp/v1/health"] = { [weak self] req in
            guard let self else { return .internalServerError }
            return .ok(.text("ok"))
        }
    }
    
    // MARK: - Resources
    
    private func setupResources() {
        // List available resources
        server["/mcp/v1/resources/list"] = { [weak self] req in
            guard let self else { return .internalServerError }
            guard self.authorized(req) else { return self.errorResponse(401, "Unauthorized") }
            
            struct Resource: Codable {
                let uri: String
                let name: String
                let description: String
                let mimeType: String?
            }
            
            struct ResourceListResponse: Codable {
                let resources: [Resource]
            }
            
            let resources = [
                Resource(
                    uri: "sublerplus://status",
                    name: "Status Events",
                    description: "Recent status events from SublerPlus",
                    mimeType: "application/json"
                ),
                Resource(
                    uri: "sublerplus://jobs",
                    name: "Job Queue",
                    description: "Current job queue status and statistics",
                    mimeType: "application/json"
                ),
                Resource(
                    uri: "sublerplus://providers",
                    name: "Metadata Providers",
                    description: "Available metadata providers and their configuration",
                    mimeType: "application/json"
                ),
                Resource(
                    uri: "sublerplus://settings",
                    name: "Application Settings",
                    description: "Current application settings and configuration",
                    mimeType: "application/json"
                )
            ]
            
            return self.jsonResponse(ResourceListResponse(resources: resources))
        }
        
        // Read resource
        server["/mcp/v1/resources/read"] = { [weak self] req in
            guard let self else { return .internalServerError }
            guard self.authorized(req) else { return self.errorResponse(401, "Unauthorized") }
            
            guard let uri = req.queryParams.first(where: { $0.0 == "uri" })?.1 else {
                return self.errorResponse(400, "Missing uri parameter")
            }
            
            return self.blockingResponse {
                try await self.handleResourceRead(uri: uri)
            }
        }
    }
    
    private func handleResourceRead(uri: String) async throws -> HttpResponse {
        switch uri {
        case "sublerplus://status":
            return try await readStatusResource()
        case "sublerplus://jobs":
            return try await readJobsResource()
        case "sublerplus://providers":
            return try await readProvidersResource()
        case "sublerplus://settings":
            return try await readSettingsResource()
        default:
            return errorResponse(404, "Resource not found: \(uri)")
        }
    }
    
    private func readStatusResource() async throws -> HttpResponse {
        struct StatusResource: Codable {
            let events: [StatusEvent]
            let count: Int
            let latest: StatusEvent?
        }
        
        let events = await statusStream.recent(limit: 100)
        let resource = StatusResource(
            events: events,
            count: events.count,
            latest: events.last
        )
        
        return jsonResponse(resource)
    }
    
    private func readJobsResource() async throws -> HttpResponse {
        struct JobResource: Codable {
            let jobs: [JobInfo]
            let statistics: JobStatistics
        }
        
        struct JobInfo: Codable {
            let id: String
            let url: String
            let status: String
            let message: String
        }
        
        struct JobStatistics: Codable {
            let totalProcessed: Int
            let successCount: Int
            let failureCount: Int
            let averageTime: TimeInterval?
            let queueLength: Int
            let runningCount: Int
        }
        
        let stats = await jobQueue.getStatistics()
        let jobs = await jobQueue.snapshot()
        
        let jobInfos = jobs.map { job in
            JobInfo(
                id: job.id.uuidString,
                url: job.url.path,
                status: job.status.rawValue,
                message: job.message
            )
        }
        
        let resource = JobResource(
            jobs: jobInfos,
            statistics: JobStatistics(
                totalProcessed: stats.totalProcessed,
                successCount: stats.successCount,
                failureCount: stats.failureCount,
                averageTime: stats.averageProcessingTime > 0 ? stats.averageProcessingTime : nil,
                queueLength: stats.currentQueueSize,
                runningCount: stats.runningCount
            )
        )
        
        return jsonResponse(resource)
    }
    
    private func readProvidersResource() async throws -> HttpResponse {
        struct ProviderInfo: Codable {
            let id: String
            let name: String
            let isAdult: Bool
            let isConfigured: Bool
        }
        
        struct ProvidersResource: Codable {
            let providers: [ProviderInfo]
            let count: Int
        }
        
        let providers = registry.all(includeAdult: true)
        let providerInfos = providers.map { provider in
            ProviderInfo(
                id: provider.id,
                name: provider.id,
                isAdult: provider.isAdult,
                isConfigured: true // TODO: Add isConfigured check to providers
            )
        }
        
        let resource = ProvidersResource(
            providers: providerInfos,
            count: providerInfos.count
        )
        
        return jsonResponse(resource)
    }
    
    private func readSettingsResource() async throws -> HttpResponse {
        // This would need access to SettingsStore - placeholder for now
        struct SettingsResource: Codable {
            let message: String
        }
        
        let resource = SettingsResource(
            message: "Settings resource requires SettingsStore integration"
        )
        
        return jsonResponse(resource)
    }
    
    // MARK: - Tools
    
    private func setupTools() {
        // List available tools
        server["/mcp/v1/tools/list"] = { [weak self] req in
            guard let self else { return .internalServerError }
            guard self.authorized(req) else { return self.errorResponse(401, "Unauthorized") }
            
            struct Tool: Codable {
                let name: String
                let description: String
                let inputSchema: ToolInputSchema
            }
            
            struct ToolInputSchema: Codable {
                let type: String
                let properties: [String: PropertySchema]
                let required: [String]?
            }
            
            struct PropertySchema: Codable {
                let type: String
                let description: String
                let enumValues: [String]?
                
                enum CodingKeys: String, CodingKey {
                    case type, description
                    case enumValues = "enum"
                }
            }
            
            struct ToolListResponse: Codable {
                let tools: [Tool]
            }
            
            let tools = [
                Tool(
                    name: "search_metadata",
                    description: "Search for metadata across all configured providers",
                    inputSchema: ToolInputSchema(
                        type: "object",
                        properties: [
                            "query": PropertySchema(
                                type: "string",
                                description: "Search query (title, show name, etc.)",
                                enumValues: nil
                            ),
                            "includeAdult": PropertySchema(
                                type: "boolean",
                                description: "Include adult content providers in search",
                                enumValues: nil
                            ),
                            "year": PropertySchema(
                                type: "integer",
                                description: "Optional year to narrow search results",
                                enumValues: nil
                            )
                        ],
                        required: ["query"]
                    )
                ),
                Tool(
                    name: "enrich_file",
                    description: "Enrich a media file with metadata from providers",
                    inputSchema: ToolInputSchema(
                        type: "object",
                        properties: [
                            "filePath": PropertySchema(
                                type: "string",
                                description: "Path to the media file to enrich",
                                enumValues: nil
                            ),
                            "includeAdult": PropertySchema(
                                type: "boolean",
                                description: "Include adult content providers",
                                enumValues: nil
                            ),
                            "preference": PropertySchema(
                                type: "string",
                                description: "Provider preference strategy",
                                enumValues: ["balanced", "scoreFirst", "yearFirst"]
                            )
                        ],
                        required: ["filePath"]
                    )
                ),
                Tool(
                    name: "get_job_status",
                    description: "Get status of a specific job by ID",
                    inputSchema: ToolInputSchema(
                        type: "object",
                        properties: [
                            "jobId": PropertySchema(
                                type: "string",
                                description: "UUID of the job",
                                enumValues: nil
                            )
                        ],
                        required: ["jobId"]
                    )
                ),
                Tool(
                    name: "queue_file",
                    description: "Add a file to the processing queue",
                    inputSchema: ToolInputSchema(
                        type: "object",
                        properties: [
                            "filePath": PropertySchema(
                                type: "string",
                                description: "Path to the media file to queue",
                                enumValues: nil
                            )
                        ],
                        required: ["filePath"]
                    )
                ),
                Tool(
                    name: "get_status_events",
                    description: "Get recent status events",
                    inputSchema: ToolInputSchema(
                        type: "object",
                        properties: [
                            "limit": PropertySchema(
                                type: "integer",
                                description: "Maximum number of events to return",
                                enumValues: nil
                            )
                        ],
                        required: nil
                    )
                )
            ]
            
            return self.jsonResponse(ToolListResponse(tools: tools))
        }
        
        // Call tool
        server["/mcp/v1/tools/call"] = { [weak self] req in
            guard let self else { return .internalServerError }
            guard self.authorized(req) else { return self.errorResponse(401, "Unauthorized") }
            guard self.validateContentType(req) else { return self.errorResponse(415, "Unsupported Media Type") }
            
            let data = Data(req.body)
            guard let toolCall = try? JSONDecoder().decode(ToolCallRequest.self, from: data) else {
                return self.errorResponse(400, "Invalid request body")
            }
            
            return self.blockingResponse {
                try await self.handleToolCall(toolCall)
            }
        }
    }
    
    private func handleToolCall(_ request: ToolCallRequest) async throws -> HttpResponse {
        struct ToolCallResponse: Codable {
            let content: [ToolCallContent]
            let isError: Bool
        }
        
        struct ToolCallContent: Codable {
            let type: String
            let text: String
        }
        
        switch request.name {
        case "search_metadata":
            return try await handleSearchMetadata(request.arguments)
        case "enrich_file":
            return try await handleEnrichFile(request.arguments)
        case "get_job_status":
            return try await handleGetJobStatus(request.arguments)
        case "queue_file":
            return try await handleQueueFile(request.arguments)
        case "get_status_events":
            return try await handleGetStatusEvents(request.arguments)
        default:
            return errorResponse(400, "Unknown tool: \(request.name)")
        }
    }
    
    private func handleSearchMetadata(_ args: [String: Any]) async throws -> HttpResponse {
        guard let query = args["query"] as? String else {
            return errorResponse(400, "Missing required parameter: query")
        }
        
        let includeAdult = args["includeAdult"] as? Bool ?? false
        let year = args["year"] as? Int
        
        await statusStream.add("MCP: Searching metadata for '\(query)'")
        
        let providers = registry.all(includeAdult: includeAdult)
        let hint = MetadataHint(title: query, year: year)
        
        var results: [MetadataDetails] = []
        for provider in providers {
            do {
                let details = try await provider.fetch(
                    for: URL(fileURLWithPath: "/dev/null"),
                    hint: hint
                )
                results.append(details)
            } catch {
                // Continue with other providers
            }
        }
        
        struct SearchResult: Codable {
            let results: [MetadataResult]
            let count: Int
        }
        
        let mapped = results.map {
            MetadataResult(
                id: $0.id,
                title: $0.title,
                score: $0.rating,
                year: $0.releaseDate?.yearComponent,
                source: $0.source,
                coverURL: $0.coverURL
            )
        }
        
        let response = SearchResult(results: mapped, count: mapped.count)
        return jsonResponse(response)
    }
    
    private func handleEnrichFile(_ args: [String: Any]) async throws -> HttpResponse {
        guard let filePath = args["filePath"] as? String else {
            return errorResponse(400, "Missing required parameter: filePath")
        }
        
        let includeAdult = args["includeAdult"] as? Bool ?? false
        let preferenceString = args["preference"] as? String ?? "balanced"
        let preference = ProviderPreference(rawValue: preferenceString) ?? .balanced
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard isSupportedMedia(fileURL) else {
            return errorResponse(415, "Unsupported media type. Only MP4, M4V, and MOV files are supported.")
        }
        
        await statusStream.add("MCP: Enriching file '\(fileURL.lastPathComponent)'")
        
        do {
            let details = try await pipeline.enrich(
                file: fileURL,
                includeAdult: includeAdult,
                preference: preference
            )
            
            if let details {
                await statusStream.add("MCP: Successfully enriched '\(details.title)'")
                return jsonResponse(details)
            } else {
                await statusStream.add("MCP: Enrichment deferred for '\(fileURL.lastPathComponent)'")
                struct DeferredResponse: Codable {
                    let message: String
                    let status: String
                }
                return jsonResponse(DeferredResponse(
                    message: "Enrichment requires user disambiguation",
                    status: "deferred"
                ))
            }
        } catch {
            await statusStream.add("MCP: Enrichment failed: \(error.localizedDescription)")
            return errorResponse(500, "Enrichment failed: \(error.localizedDescription)")
        }
    }
    
    private func handleGetJobStatus(_ args: [String: Any]) async throws -> HttpResponse {
        guard let jobIdString = args["jobId"] as? String,
              let jobId = UUID(uuidString: jobIdString) else {
            return errorResponse(400, "Invalid or missing jobId parameter")
        }
        
        let jobs = await jobQueue.snapshot()
        guard let job = jobs.first(where: { $0.id == jobId }) else {
            return errorResponse(404, "Job not found")
        }
        
        struct JobStatusResponse: Codable {
            let id: String
            let url: String
            let status: String
            let message: String
        }
        
        let response = JobStatusResponse(
            id: job.id.uuidString,
            url: job.url.path,
            status: job.status.rawValue,
            message: job.message
        )
        
        return jsonResponse(response)
    }
    
    private func handleQueueFile(_ args: [String: Any]) async throws -> HttpResponse {
        guard let filePath = args["filePath"] as? String else {
            return errorResponse(400, "Missing required parameter: filePath")
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard isSupportedMedia(fileURL) else {
            return errorResponse(415, "Unsupported media type. Only MP4, M4V, and MOV files are supported.")
        }
        
        let jobs = await jobQueue.enqueue([fileURL])
        await statusStream.add("MCP: Queued file '\(fileURL.lastPathComponent)'")
        
        struct QueueResponse: Codable {
            let message: String
            let filePath: String
        }
        
        return jsonResponse(QueueResponse(
            message: "File queued successfully",
            filePath: filePath
        ))
    }
    
    private func handleGetStatusEvents(_ args: [String: Any]) async throws -> HttpResponse {
        let limit = args["limit"] as? Int ?? 50
        let events = await statusStream.recent(limit: limit)
        
        struct StatusEventsResponse: Codable {
            let events: [StatusEvent]
            let count: Int
        }
        
        return jsonResponse(StatusEventsResponse(events: events, count: events.count))
    }
    
    // MARK: - Helpers
    
    private func jsonResponse<T: Encodable>(_ value: T) -> HttpResponse {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            return .raw(200, "OK", [
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            ]) { writer in
                try writer.write(data)
            }
        } catch {
            return .internalServerError
        }
    }
    
    private func blockingResponse(_ body: @escaping () async throws -> HttpResponse) -> HttpResponse {
        let sema = DispatchSemaphore(value: 0)
        var response: HttpResponse = .internalServerError
        Task {
            response = (try? await body()) ?? .internalServerError
            sema.signal()
        }
        sema.wait()
        return response
    }
    
    private func authorized(_ req: HttpRequest) -> Bool {
        if let token = authToken, !token.isEmpty {
            return req.headers["authorization"] == "Bearer \(token)" ||
                   req.headers["x-auth-token"] == token
        }
        return true // No auth required if no token set
    }
    
    private func validateContentType(_ req: HttpRequest) -> Bool {
        guard let type = req.headers["content-type"]?.lowercased() else { return false }
        return type.contains("application/json")
    }
    
    private func errorResponse(_ status: Int, _ message: String) -> HttpResponse {
        struct ErrorResponse: Codable {
            let error: String
            let status: Int
        }
        
        do {
            let data = try JSONEncoder().encode(ErrorResponse(error: message, status: status))
            return .raw(status, message, [
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            ]) { writer in
                try writer.write(data)
            }
        } catch {
            return .raw(status, message, ["Content-Type": "text/plain"]) { writer in
                try writer.write(Array(message.utf8))
            }
        }
    }
    
    private func isSupportedMedia(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "m4v", "mov"].contains(ext)
    }
}

// MARK: - Supporting Types

private struct ToolCallRequest: Codable {
    let name: String
    let arguments: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case name, arguments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        
        // Decode arguments as [String: Any]
        let argsContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .arguments)
        var args: [String: Any] = [:]
        for key in argsContainer.allKeys {
            if let value = try? argsContainer.decode(String.self, forKey: key) {
                args[key.stringValue] = value
            } else if let value = try? argsContainer.decode(Int.self, forKey: key) {
                args[key.stringValue] = value
            } else if let value = try? argsContainer.decode(Bool.self, forKey: key) {
                args[key.stringValue] = value
            } else if let value = try? argsContainer.decode(Double.self, forKey: key) {
                args[key.stringValue] = value
            }
        }
        arguments = args
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        // Arguments encoding would need custom handling
    }
}

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

private extension Date {
    var yearComponent: Int? {
        Calendar.current.dateComponents([.year], from: self).year
    }
}

