# Apple Open Source MCP Integration Plan

## Overview

This plan details the integration of the Apple Open Source GitHub organization (https://github.com/apple-open-source) into a Model Context Protocol (MCP) server. The MCP server will provide unified access to documentation, code examples, and repository information from Apple's open source projects.

## Objectives

1. Create a Swift-based MCP server for Apple Open Source repositories
2. Index and search across multiple Apple open source projects
3. Provide access to documentation, README files, and code examples
4. Enable repository discovery and information retrieval
5. Integrate seamlessly with Cursor AI alongside existing MCP servers

## Architecture

### Design Principles

**Modularity:**
- Each component is isolated with clear interfaces
- Actor-based concurrency for thread safety
- Dependency injection for testability
- Single Responsibility Principle per component

**Performance:**
- Aggressive caching to minimize API calls
- Lazy loading of repository data
- Background indexing tasks
- Efficient search algorithms

**Security:**
- No hardcoded credentials
- Environment variable-based authentication
- Input validation and sanitization
- Secure error handling without information leakage

**Deterministic Symbol Tracing:**
- Clear module boundaries
- Explicit public APIs
- Type-safe interfaces
- Comprehensive error types

### Server Structure

```
AppleOpenSourceMCP/
├── AppleOpenSourceMCP/
│   ├── AppleOpenSourceStdioServer.swift    # Main stdio server (MCP protocol)
│   ├── RepositoryManager.swift              # Manages repository access (actor)
│   ├── RepositoryIndexer.swift              # Indexes repositories (actor)
│   ├── DocumentationParser.swift            # Parses docs and READMEs (actor)
│   ├── CodeExampleExtractor.swift           # Extracts code examples (actor)
│   ├── GitHubAPIClient.swift                # GitHub API integration (actor)
│   └── JSONRPC.swift                        # JSON-RPC 2.0 structures
├── AppleOpenSourceMCPExecutable/
│   └── main.swift                           # Entry point
└── Package.swift                            # Swift Package Manager config
```

### Key Components

1. **AppleOpenSourceStdioServer**: Main MCP protocol handler, implements JSON-RPC 2.0
2. **RepositoryManager**: Handles repository discovery, caching, and updates (actor-isolated)
3. **RepositoryIndexer**: Builds searchable indexes of repository content (actor-isolated)
4. **DocumentationParser**: Extracts and parses documentation from various formats (actor-isolated)
5. **CodeExampleExtractor**: Identifies and extracts code examples (actor-isolated)
6. **GitHubAPIClient**: Interfaces with GitHub API with rate limiting and authentication (actor-isolated)

### Component Interactions

```
┌─────────────────────┐
│  MCP Stdio Server   │
│  (Protocol Handler) │
└──────────┬──────────┘
           │
    ┌──────┴──────┐
    │             │
┌───▼───┐    ┌───▼──────────┐
│ Repo  │    │ Documentation│
│Manager│    │   Parser     │
└───┬───┘    └───┬──────────┘
    │            │
    └──────┬─────┘
           │
    ┌──────▼──────┐
    │  Indexer    │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │ GitHub API  │
    │   Client    │
    └─────────────┘
```

**Data Flow:**
1. MCP Server receives JSON-RPC request
2. Routes to appropriate component (RepositoryManager, DocumentationParser, etc.)
3. Components interact with GitHubAPIClient for API calls
4. Results are indexed and cached
5. Response sent back through MCP protocol

## Implementation Phases

### Phase 1: Project Setup and Infrastructure

#### 1.1 Create Project Structure

```bash
mkdir -p AppleOpenSourceMCP/AppleOpenSourceMCP
mkdir -p AppleOpenSourceMCP/AppleOpenSourceMCPExecutable
```

#### 1.2 Create Package.swift

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppleOpenSourceMCP",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "AppleOpenSourceMCP", targets: ["AppleOpenSourceMCP"]),
        .executable(name: "AppleOpenSourceMCPExecutable", targets: ["AppleOpenSourceMCPExecutable"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "AppleOpenSourceMCP",
            dependencies: [],
            path: "AppleOpenSourceMCP"
        ),
        .executableTarget(
            name: "AppleOpenSourceMCPExecutable",
            dependencies: ["AppleOpenSourceMCP"],
            path: "AppleOpenSourceMCPExecutable",
            sources: ["main.swift"]
        )
    ]
)
```

#### 1.3 Create JSON-RPC Structures

Reuse the JSON-RPC implementation pattern from existing MCP servers:
- `JSONRPCRequest`, `JSONRPCResponse`, `JSONRPCError`
- `JSONValue` enum for flexible JSON handling

### Phase 2: GitHub API Integration

#### 2.1 Implement GitHubAPIClient

**File**: `AppleOpenSourceMCP/GitHubAPIClient.swift`

**Security and Modularity Requirements:**
- Use actor isolation for thread-safe operations
- Implement deterministic error handling
- Support token authentication via environment variable
- Implement rate limit detection and handling

```swift
import Foundation

public actor GitHubAPIClient {
    private let baseURL = "https://api.github.com"
    private let organization = "apple-open-source"
    private let session: URLSession
    private let token: String?
    
    public init(token: String? = nil) {
        // Support token from environment or parameter
        self.token = token ?? ProcessInfo.processInfo.environment["GITHUB_TOKEN"]
        
        let config = URLSessionConfiguration.default
        var headers: [String: String] = [
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "AppleOpenSourceMCP/1.0"
        ]
        
        // Add authentication header if token is available
        if let token = self.token, !token.isEmpty {
            headers["Authorization"] = "token \(token)"
        }
        
        config.httpAdditionalHeaders = headers
        self.session = URLSession(configuration: config)
    }
    
    /// Check rate limit status from response headers
    private func checkRateLimit(from response: HTTPURLResponse) -> RateLimitStatus {
        let limit = Int(response.value(forHTTPHeaderField: "X-RateLimit-Limit") ?? "0") ?? 0
        let remaining = Int(response.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "0") ?? 0
        let reset = TimeInterval(response.value(forHTTPHeaderField: "X-RateLimit-Reset") ?? "0") ?? 0
        
        return RateLimitStatus(limit: limit, remaining: remaining, resetDate: Date(timeIntervalSince1970: reset))
    }
    
    /// Fetch all repositories from apple-open-source organization
    public func fetchRepositories() async throws -> [GitHubRepository] {
        var allRepos: [GitHubRepository] = []
        var page = 1
        let perPage = 100
        
        while true {
            let url = URL(string: "\(baseURL)/orgs/\(organization)/repos?page=\(page)&per_page=\(perPage)")!
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch repositories"])
            }
            
            let repos = try JSONDecoder().decode([GitHubRepository].self, from: data)
            if repos.isEmpty { break }
            
            allRepos.append(contentsOf: repos)
            page += 1
        }
        
        return allRepos
    }
    
    /// Fetch repository details
    public func fetchRepositoryDetails(name: String) async throws -> GitHubRepository {
        let url = URL(string: "\(baseURL)/repos/\(organization)/\(name)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch repository"])
        }
        
        return try JSONDecoder().decode(GitHubRepository.self, from: data)
    }
    
    /// Fetch README content
    public func fetchREADME(repository: String, branch: String = "main") async throws -> String {
        let url = URL(string: "\(baseURL)/repos/\(organization)/\(repository)/readme")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch README"])
        }
        
        let readmeResponse = try JSONDecoder().decode(READMEResponse.self, from: data)
        guard let contentData = Data(base64Encoded: readmeResponse.content, options: .ignoreUnknownCharacters),
              let content = String(data: contentData, encoding: .utf8) else {
            throw NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode README"])
        }
        
        return content
    }
}

public struct GitHubRepository: Codable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String?
    public let language: String?
    public let stars: Int
    public let forks: Int
    public let defaultBranch: String
    public let createdAt: Date
    public let updatedAt: Date
    public let topics: [String]
    public let homepage: String?
    public let license: LicenseInfo?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, language, topics, homepage, license
        case fullName = "full_name"
        case stars = "stargazers_count"
        case forks = "forks_count"
        case defaultBranch = "default_branch"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct LicenseInfo: Codable {
    public let key: String
    public let name: String
    public let spdxId: String?
    
    enum CodingKeys: String, CodingKey {
        case key, name
        case spdxId = "spdx_id"
    }
}

public struct READMEResponse: Codable {
    public let name: String
    public let content: String
    public let encoding: String
}

public struct RateLimitStatus {
    public let limit: Int
    public let remaining: Int
    public let resetDate: Date
    
    public var isExceeded: Bool {
        remaining <= 0
    }
    
    public var timeUntilReset: TimeInterval {
        max(0, resetDate.timeIntervalSinceNow)
    }
}
```

#### 2.2 Rate Limiting and Caching

**Rate Limit Handling:**
- GitHub API: 60 requests/hour unauthenticated, 5000/hour authenticated
- Implement rate limit detection from response headers:
  - `X-RateLimit-Limit`: Total requests allowed
  - `X-RateLimit-Remaining`: Requests remaining
  - `X-RateLimit-Reset`: Unix timestamp when limit resets
- Implement exponential backoff on rate limit errors (429 status)
- Cache API responses aggressively to minimize API calls
- Support GitHub token authentication via environment variable `GITHUB_TOKEN`

**Security Considerations:**
- Never log or expose GitHub tokens
- Use environment variables only, never hardcode credentials
- Validate token format before use
- Implement token rotation support

**Caching Strategy:**
- Cache repository list for 24 hours
- Cache README content for 7 days
- Use ETags for conditional requests when available
- Implement cache invalidation on explicit refresh requests

### Phase 3: Repository Management

#### 3.1 Implement RepositoryManager

**File**: `AppleOpenSourceMCP/RepositoryManager.swift`

```swift
import Foundation

public actor RepositoryManager {
    private let gitHubClient: GitHubAPIClient
    private let cacheDirectory: URL
    private var repositories: [String: GitHubRepository] = [:]
    
    public init(gitHubClient: GitHubAPIClient, cacheDirectory: URL? = nil) {
        self.gitHubClient = gitHubClient
        let defaultCache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".apple-open-source-mcp")
            .appendingPathComponent("repositories")
        self.cacheDirectory = cacheDirectory ?? defaultCache
        
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Refresh repository list from GitHub
    public func refreshRepositories() async throws {
        let repos = try await gitHubClient.fetchRepositories()
        for repo in repos {
            repositories[repo.name] = repo
        }
        await saveRepositoryCache()
    }
    
    /// Get all repositories
    public func getAllRepositories() async -> [GitHubRepository] {
        return Array(repositories.values)
    }
    
    /// Get repository by name
    public func getRepository(name: String) async -> GitHubRepository? {
        return repositories[name]
    }
    
    /// Search repositories by query
    public func searchRepositories(query: String) async -> [GitHubRepository] {
        let lowerQuery = query.lowercased()
        return repositories.values.filter { repo in
            repo.name.lowercased().contains(lowerQuery) ||
            repo.description?.lowercased().contains(lowerQuery) ?? false ||
            repo.topics.contains { $0.lowercased().contains(lowerQuery) }
        }
    }
    
    /// Load repository cache from disk
    public func loadRepositoryCache() async throws {
        let cacheFile = cacheDirectory.appendingPathComponent("repositories.json")
        guard FileManager.default.fileExists(atPath: cacheFile.path) else { return }
        
        let data = try Data(contentsOf: cacheFile)
        let repos = try JSONDecoder().decode([GitHubRepository].self, from: data)
        for repo in repos {
            repositories[repo.name] = repo
        }
    }
    
    /// Save repository cache to disk
    private func saveRepositoryCache() async {
        let cacheFile = cacheDirectory.appendingPathComponent("repositories.json")
        let repos = Array(repositories.values)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(repos)
            try data.write(to: cacheFile, options: .atomic)
        } catch {
            // Log error but don't fail
        }
    }
}
```

### Phase 4: Documentation Parsing

#### 4.1 Implement DocumentationParser

**File**: `AppleOpenSourceMCP/DocumentationParser.swift`

```swift
import Foundation

public actor DocumentationParser {
    private let gitHubClient: GitHubAPIClient
    private var parsedDocs: [String: ParsedDocumentation] = [:]
    
    public init(gitHubClient: GitHubAPIClient) {
        self.gitHubClient = gitHubClient
    }
    
    /// Parse README from repository
    public func parseREADME(repository: String) async throws -> ParsedDocumentation {
        if let cached = parsedDocs[repository] {
            return cached
        }
        
        let readmeContent = try await gitHubClient.fetchREADME(repository: repository)
        let parsed = ParsedDocumentation(
            repository: repository,
            content: readmeContent,
            sections: extractSections(from: readmeContent),
            codeExamples: extractCodeExamples(from: readmeContent)
        )
        
        parsedDocs[repository] = parsed
        return parsed
    }
    
    /// Extract sections from markdown
    private func extractSections(from markdown: String) -> [DocumentationSection] {
        var sections: [DocumentationSection] = []
        let lines = markdown.components(separatedBy: .newlines)
        var currentSection: DocumentationSection?
        
        for line in lines {
            if line.hasPrefix("#") {
                if let section = currentSection {
                    sections.append(section)
                }
                let level = line.prefix(while: { $0 == "#" }).count
                let title = String(line.dropFirst(level).trimmingCharacters(in: .whitespaces))
                currentSection = DocumentationSection(level: level, title: title, content: "")
            } else if var section = currentSection {
                section.content += line + "\n"
                currentSection = section
            }
        }
        
        if let section = currentSection {
            sections.append(section)
        }
        
        return sections
    }
    
    /// Extract code examples from markdown
    private func extractCodeExamples(from markdown: String) -> [CodeExample] {
        var examples: [CodeExample] = []
        let codeBlockPattern = #"```(\w+)?\n(.*?)```"#
        let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: [.dotMatchesLineSeparators])
        
        if let regex = regex {
            let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
            let matches = regex.matches(in: markdown, options: [], range: range)
            
            for match in matches {
                if match.numberOfRanges >= 3 {
                    let languageRange = Range(match.range(at: 1), in: markdown) ?? markdown.startIndex..<markdown.startIndex
                    let codeRange = Range(match.range(at: 2), in: markdown) ?? markdown.startIndex..<markdown.startIndex
                    
                    let language = String(markdown[languageRange])
                    let code = String(markdown[codeRange])
                    
                    examples.append(CodeExample(language: language.isEmpty ? nil : language, code: code))
                }
            }
        }
        
        return examples
    }
    
    /// Search documentation across all parsed repos
    public func search(query: String, repository: String? = nil) async -> [ParsedDocumentation] {
        let lowerQuery = query.lowercased()
        let reposToSearch = repository != nil ? [repository!] : Array(parsedDocs.keys)
        
        return reposToSearch.compactMap { repo in
            guard let doc = parsedDocs[repo] else { return nil }
            if doc.content.lowercased().contains(lowerQuery) ||
               doc.sections.contains(where: { $0.title.lowercased().contains(lowerQuery) }) {
                return doc
            }
            return nil
        }
    }
}

public struct ParsedDocumentation: Codable {
    public let repository: String
    public let content: String
    public let sections: [DocumentationSection]
    public let codeExamples: [CodeExample]
}

public struct DocumentationSection: Codable {
    public let level: Int
    public let title: String
    public var content: String
}

public struct CodeExample: Codable {
    public let language: String?
    public let code: String
}
```

### Phase 5: Repository Indexing

#### 5.1 Implement RepositoryIndexer

**File**: `AppleOpenSourceMCP/RepositoryIndexer.swift`

```swift
import Foundation

public actor RepositoryIndexer {
    private var index: [String: IndexEntry] = [:]
    private let cacheDirectory: URL
    
    public init(cacheDirectory: URL? = nil) {
        let defaultCache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".apple-open-source-mcp")
            .appendingPathComponent("index")
        self.cacheDirectory = cacheDirectory ?? defaultCache
        
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Index a repository
    public func indexRepository(_ repo: GitHubRepository, documentation: ParsedDocumentation) async {
        let entry = IndexEntry(
            repository: repo.name,
            description: repo.description ?? "",
            language: repo.language ?? "",
            topics: repo.topics,
            documentation: documentation,
            indexedAt: Date()
        )
        
        index[repo.name] = entry
        await saveIndex()
    }
    
    /// Search index
    public func search(query: String) async -> [IndexEntry] {
        let lowerQuery = query.lowercased()
        return index.values.filter { entry in
            entry.repository.lowercased().contains(lowerQuery) ||
            entry.description.lowercased().contains(lowerQuery) ||
            entry.language.lowercased().contains(lowerQuery) ||
            entry.topics.contains(where: { $0.lowercased().contains(lowerQuery) }) ||
            entry.documentation.content.lowercased().contains(lowerQuery)
        }
    }
    
    /// Get index entry by repository name
    public func getEntry(repository: String) async -> IndexEntry? {
        return index[repository]
    }
    
    /// Save index to disk
    private func saveIndex() async {
        let indexFile = cacheDirectory.appendingPathComponent("index.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Array(index.values))
            try data.write(to: indexFile, options: .atomic)
        } catch {
            // Log error
        }
    }
    
    /// Load index from disk
    public func loadIndex() async throws {
        let indexFile = cacheDirectory.appendingPathComponent("index.json")
        guard FileManager.default.fileExists(atPath: indexFile.path) else { return }
        
        let data = try Data(contentsOf: indexFile)
        let entries = try JSONDecoder().decode([IndexEntry].self, from: data)
        
        for entry in entries {
            index[entry.repository] = entry
        }
    }
}

public struct IndexEntry: Codable {
    public let repository: String
    public let description: String
    public let language: String
    public let topics: [String]
    public let documentation: ParsedDocumentation
    public let indexedAt: Date
}
```

### Phase 6: MCP Server Implementation

#### 6.1 Implement AppleOpenSourceStdioServer

**File**: `AppleOpenSourceMCP/AppleOpenSourceStdioServer.swift`

Follow the same pattern as `SwiftLangStdioServer.swift` with strict adherence to Cursor AI MCP protocol:

**Protocol Compliance Requirements:**
- Implement JSON-RPC 2.0 protocol handlers with proper error codes
- Use protocol version `"2024-11-05"` in initialize response (per Cursor AI specification)
- Ensure all responses include request `id` for proper correlation
- Implement proper error handling with JSON-RPC error codes

**Initialize Handler:**
```swift
private func handleInitialize(_ request: JSONRPCRequest) async -> JSONRPCResponse {
    if case .object(let params) = request.params {
        clientInfo = params
    }
    
    isInitialized = true
    
    let capabilities: [String: JSONValue] = [
        "resources": .object([
            "subscribe": .bool(true),
            "listChanged": .bool(true)
        ]),
        "tools": .object([
            "listChanged": .bool(true)
        ])
    ]
    
    let serverInfo: [String: JSONValue] = [
        "name": .string("Apple Open Source MCP Server"),
        "version": .string("1.0.0")
    ]
    
    // CRITICAL: Use exact protocol version required by Cursor AI
    let result: [String: JSONValue] = [
        "protocolVersion": .string("2024-11-05"),
        "capabilities": .object(capabilities),
        "serverInfo": .object(serverInfo)
    ]
    
    return JSONRPCResponse(
        jsonrpc: "2.0",
        id: request.id,
        result: .object(result),
        error: nil
    )
}
```

**Resources:**
- `apple-opensource://repositories` - List of all repositories
- `apple-opensource://repository/{name}` - Repository details
- `apple-opensource://documentation/{name}` - Repository documentation

**Tools (with proper input schemas):**
- `search_repositories` - Search repositories by name, description, or topics
- `get_repository_info` - Get detailed repository information
- `get_documentation` - Get repository documentation and README
- `search_documentation` - Search across all repository documentation
- `get_code_examples` - Get code examples from repository

**Error Handling:**
- All error responses must include the request `id`
- Use standard JSON-RPC error codes:
  - `-32700`: Parse error
  - `-32600`: Invalid Request
  - `-32601`: Method not found
  - `-32602`: Invalid params
  - `-32603`: Internal error
  - `-32002`: Server not initialized
- Include descriptive error messages for debugging

### Phase 7: Executable Entry Point

#### 7.1 Create main.swift

**File**: `AppleOpenSourceMCPExecutable/main.swift`

```swift
import Foundation
import AppleOpenSourceMCP

@main
struct AppleOpenSourceMCPMain {
    static func main() async {
        // Initialize components
        let gitHubClient = GitHubAPIClient()
        let repoManager = RepositoryManager(gitHubClient: gitHubClient)
        let docParser = DocumentationParser(gitHubClient: gitHubClient)
        let indexer = RepositoryIndexer()
        
        // Load cached data
        try? await repoManager.loadRepositoryCache()
        try? await indexer.loadIndex()
        
        // Refresh repositories in background
        Task {
            try? await repoManager.refreshRepositories()
        }
        
        // Create stdio server
        let stdioServer = AppleOpenSourceStdioServer(
            repositoryManager: repoManager,
            documentationParser: docParser,
            indexer: indexer
        )
        
        // Start server
        let serverTask = Task {
            await stdioServer.run()
        }
        
        await serverTask.value
    }
}
```

### Phase 8: Integration with Cursor AI

#### 8.1 Update mcp.json

Add to `~/.cursor/mcp.json` following Cursor AI MCP specification:

```json
{
  "mcpServers": {
    "Apple Open Source": {
      "type": "stdio",
      "command": "swift",
      "args": [
        "run",
        "--package-path",
        "${workspaceFolder}/AppleOpenSourceMCP",
        "AppleOpenSourceMCPExecutable"
      ],
      "env": {
        "GITHUB_TOKEN": "${env:GITHUB_TOKEN}"
      }
    }
  }
}
```

**Configuration Details:**
- **`type`**: Explicitly set to `"stdio"` (required by Cursor AI for local command-line servers)
- **`command`**: Must be available on system PATH or use full path
- **`args`**: Array of arguments passed to command
- **`env`**: Environment variables with config interpolation support
  - Use `${env:VARIABLE_NAME}` for environment variable interpolation
  - GitHub token is optional but recommended for higher rate limits (5000/hour vs 60/hour)

**Alternative: Project-Specific Configuration**

For project-specific setup, create `.cursor/mcp.json` in project root:

```json
{
  "mcpServers": {
    "Apple Open Source": {
      "type": "stdio",
      "command": "swift",
      "args": [
        "run",
        "--package-path",
        "${workspaceFolder}/AppleOpenSourceMCP",
        "AppleOpenSourceMCPExecutable"
      ],
      "env": {
        "GITHUB_TOKEN": "${env:GITHUB_TOKEN}"
      },
      "envFile": "${workspaceFolder}/.env"
    }
  }
}
```

**Config Interpolation Variables:**
- `${env:NAME}` - Environment variables
- `${workspaceFolder}` - Project root directory
- `${userHome}` - User home directory
- `${workspaceFolderBasename}` - Project root name

#### 8.2 Update Configuration Template

Add to `docs/mcp.json.template`

#### 8.3 Create Documentation

Create `docs/APPLE_OPEN_SOURCE_MCP.md` with comprehensive documentation:

**Required Sections:**
1. **Installation Instructions**
   - Prerequisites (Swift toolchain, GitHub token setup)
   - Build process
   - Configuration steps

2. **Available Tools and Resources**
   - Complete tool list with parameters
   - Resource URIs and formats
   - Example requests and responses

3. **Usage Examples**
   - Basic repository search
   - Documentation retrieval
   - Code example extraction
   - Integration with Cursor AI workflows

4. **Troubleshooting Guide**
   - Common errors and solutions
   - How to access MCP logs in Cursor AI
   - GitHub API rate limit issues
   - Cache problems and solutions
   - Network connectivity issues

5. **Security Best Practices**
   - Token management
   - Environment variable setup
   - Safe configuration practices

6. **Performance Optimization**
   - Cache management
   - Rate limit strategies
   - Background indexing

## Error Handling and Logging

### Structured Error Responses

All MCP protocol errors must follow JSON-RPC 2.0 specification:

```swift
// Parse error
JSONRPCError(code: -32700, message: "Parse error", data: .string(details))

// Invalid request
JSONRPCError(code: -32600, message: "Invalid Request", data: nil)

// Method not found
JSONRPCError(code: -32601, message: "Method not found: \(method)", data: nil)

// Invalid params
JSONRPCError(code: -32602, message: "Invalid params: \(details)", data: .object(["field": .string("value")]))

// Internal error
JSONRPCError(code: -32603, message: "Internal error: \(error.localizedDescription)", data: nil)

// Server not initialized
JSONRPCError(code: -32002, message: "Server not initialized", data: nil)
```

### Logging Strategy

**Production-Tier Logging Requirements:**
- Log all MCP protocol errors with context
- Log GitHub API rate limit status
- Log cache hits/misses for performance monitoring
- Never log sensitive data (tokens, credentials)
- Use structured logging for deterministic tracing

**Logging Implementation:**
```swift
import os.log

private let logger = Logger(subsystem: "com.appleopensource.mcp", category: "server")

// Log errors
logger.error("MCP protocol error: \(error.localizedDescription, privacy: .public)")

// Log rate limit status
logger.info("GitHub API rate limit: \(remaining)/\(limit) remaining")

// Log cache operations
logger.debug("Cache hit for repository: \(repository, privacy: .public)")
```

### Debugging in Cursor AI

**Accessing MCP Logs:**
1. Open Output panel in Cursor: `Cmd+Shift+U` (macOS) or `Ctrl+Shift+U` (Windows/Linux)
2. Select "MCP Logs" from the dropdown
3. Review server initialization, tool calls, and error messages

**Common Issues to Log:**
- Server initialization failures
- GitHub API authentication errors
- Rate limit exceeded warnings
- Cache read/write failures
- JSON-RPC protocol violations

## Tool Approval and Auto-Run

### Default Behavior

Per Cursor AI MCP documentation:
- **Tool Approval**: Agent asks for approval before using MCP tools by default
- Users can see tool arguments before execution
- Tool responses are shown in chat with expandable views

### Auto-Run Configuration

Users can enable auto-run for MCP tools:
1. Open Settings: `Cmd+Shift+J` (macOS) or `Ctrl+Shift+J` (Windows/Linux)
2. Navigate to Features → Model Context Protocol
3. Enable auto-run for specific tools or all tools

**Considerations:**
- Auto-run should only be enabled for trusted tools
- Tools that make external API calls should remain approval-required by default
- Document auto-run implications in user documentation

### Tool Toggling

Users can enable/disable MCP tools from chat interface:
- Click tool name in tools list to toggle
- Disabled tools won't be loaded into context
- Useful for troubleshooting or reducing tool clutter

## Security Considerations

### Authentication

**GitHub Token Security:**
- Store tokens in environment variables only
- Never hardcode tokens in source code
- Use `${env:GITHUB_TOKEN}` interpolation in mcp.json
- Support token rotation without code changes
- Validate token format before use

### Data Handling

**Sensitive Data Protection:**
- Never log API tokens or credentials
- Sanitize error messages to avoid exposing sensitive paths
- Use privacy levels in logging (`.public` vs `.private`)
- Implement secret scrubbing for log output

### Network Security

**HTTPS Only:**
- All GitHub API calls must use HTTPS
- Validate SSL certificates
- Implement certificate pinning if required
- Never accept self-signed certificates in production

### Input Validation

**Production-Tier Safety:**
- Validate all user inputs before processing
- Sanitize repository names to prevent path traversal
- Limit query string lengths
- Validate JSON-RPC request structure
- Implement request size limits

### Access Control

**Modular Security:**
- Isolate GitHub API client from other components
- Use actor isolation for thread safety
- Implement request rate limiting per user
- Cache access should be restricted to authorized components

## Challenges and Considerations

### 1. Rate Limiting

**Challenge**: GitHub API has rate limits (60/hour unauthenticated, 5000/hour authenticated)

**Solution**:
- Implement aggressive caching
- Support GitHub token authentication
- Batch requests where possible
- Use conditional requests (ETags) to minimize API calls

### 2. Repository Scale

**Challenge**: Apple Open Source organization may have many repositories

**Solution**:
- Lazy loading: Only index repositories when accessed
- Incremental updates: Only refresh changed repositories
- Background indexing: Index in background tasks
- Prioritize popular/starred repositories

### 3. Documentation Formats

**Challenge**: Repositories may use different documentation formats

**Solution**:
- Support Markdown (primary)
- Support HTML documentation
- Support plain text READMEs
- Graceful degradation for unsupported formats

### 4. Code Example Extraction

**Challenge**: Extracting meaningful code examples from repositories

**Solution**:
- Parse markdown code blocks
- Extract from example directories
- Use heuristics to identify example files
- Support multiple languages

### 5. Cache Management

**Challenge**: Managing cache size and freshness

**Solution**:
- Implement cache expiration (e.g., 24 hours for repository list)
- Cache size limits
- Cache invalidation on updates
- Manual cache clearing tools

### 6. Network Dependencies

**Challenge**: Server requires internet access for GitHub API

**Solution**:
- Graceful offline mode using cached data
- Clear error messages when offline
- Retry logic with exponential backoff
- Connection status indicators

## Testing Strategy

### Unit Tests

- Test GitHub API client with mock responses
- Test documentation parsing with sample markdown
- Test repository indexing logic
- Test search functionality

### Integration Tests

- Test full MCP protocol flow
- Test with actual GitHub API (with rate limiting)
- Test cache persistence
- Test error handling

### Manual Testing

**Cursor AI Integration Testing:**
1. Verify MCP server starts correctly
2. Check MCP logs in Cursor AI (Cmd+Shift+U → "MCP Logs")
3. Test all tools in Cursor AI chat interface
4. Verify tool approval workflow
5. Test auto-run functionality (if enabled)
6. Verify resource access through Cursor AI
7. Test search functionality across repositories
8. Verify error handling and user feedback
9. Test with and without GitHub token
10. Verify offline mode with cached data

**Protocol Compliance Testing:**
- Verify protocol version "2024-11-05" in initialize response
- Test all JSON-RPC error codes
- Verify all responses include request `id`
- Test stdio communication stability
- Verify graceful shutdown on EOF

## Deployment

### Build Process

```bash
cd AppleOpenSourceMCP
swift build --product AppleOpenSourceMCPExecutable
```

### Verification

1. Build executable successfully
2. Test stdio communication
3. Verify GitHub API access
4. Test in Cursor AI

## Maintenance

### Regular Updates

- Refresh repository list daily
- Update indexes when repositories change
- Monitor GitHub API rate limits
- Update documentation as needed

### Monitoring

- Log API calls and rate limit status
- Monitor cache hit rates
- Track search performance
- Monitor error rates

## Success Criteria

**Functional Requirements:**
1. ✅ MCP server builds and runs successfully
2. ✅ Can list all Apple Open Source repositories
3. ✅ Can search repositories by name, description, topics
4. ✅ Can retrieve repository documentation
5. ✅ Can search across documentation
6. ✅ Can extract code examples
7. ✅ Integrates with Cursor AI

**Protocol Compliance:**
8. ✅ Uses protocol version "2024-11-05" in initialize response
9. ✅ All responses include request `id` for correlation
10. ✅ Proper JSON-RPC 2.0 error codes and messages
11. ✅ Explicit `type: "stdio"` in mcp.json configuration

**Production-Tier Requirements:**
12. ✅ Handles errors gracefully with proper error codes
13. ✅ Caches data effectively with expiration policies
14. ✅ Respects GitHub API rate limits with proper handling
15. ✅ Secure credential management (no hardcoded tokens)
16. ✅ Comprehensive logging without sensitive data exposure
17. ✅ Modular architecture with clear component boundaries
18. ✅ Deterministic symbol tracing and type safety
19. ✅ Thread-safe operations using Swift actors
20. ✅ Input validation and sanitization throughout

## Timeline Estimate

- **Phase 1-2**: 2-3 days (Setup + GitHub API)
- **Phase 3-4**: 3-4 days (Repository Management + Documentation)
- **Phase 5-6**: 2-3 days (Indexing + MCP Server)
- **Phase 7-8**: 1-2 days (Integration + Documentation)
- **Testing**: 2-3 days
- **Total**: 10-15 days

## Next Steps

1. Review and approve this plan
2. Set up project structure
3. Implement GitHub API client
4. Build repository management
5. Implement documentation parsing
6. Create MCP server
7. Integrate with Cursor AI
8. Test and refine

