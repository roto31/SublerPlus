# Copilot Instructions for SublerPlus

## Project Overview

SublerPlus is a SwiftUI macOS application (12+) for MP4 metadata enrichment. It provides:
- MP4 tagging via AVFoundation + pure-Swift AtomCodec
- Multiple metadata providers (TMDB, TVDB, TPDB, Subler local)
- Embedded WebUI server (Swifter) on localhost
- CLI interface for headless operations
- Advanced codec support and muxing capabilities
- Secure defaults with Keychain storage and localhost-only server

## Architecture

- **Pure Swift**: 100% Swift codebase, macOS 12+
- **SwiftPM**: Package.swift with three targets:
  - `SublerPlusCore`: Core library with models, controllers
  - `SublerPlusApp`: SwiftUI application target
  - `SublerPlusCLI`: Command-line interface target
- **Concurrency**: Heavy use of Swift actors for thread-safe state management
- **Key Modules**:
  - `MetadataPipeline`: Orchestrates provider → MP4 writing flow
  - `ProvidersRegistry`: Pluggable provider system
  - `JobQueue` actor: Bounded concurrency for batch processing
  - `WebServer`: Localhost HTTP API with embedded assets
  - `AtomCodec`: Pure-Swift MP4 ilst read/write
  - `FFmpegWrapper`: Advanced codec detection and conversion

## Build and Test Commands

```bash
# Build the project
swift build

# Run all tests
swift test

# Run security tests (required before PRs)
make security

# Run the app
swift run SublerPlusApp

# Run the CLI
swift run SublerPlusCLI /path/to/file.mp4
```

## Code Style and Conventions

### Swift Style
- Use Swift's modern concurrency features (async/await, actors)
- Mark actor classes with `actor` keyword
- Use `@MainActor` for view models and UI code
- All public types and functions should have public access control explicitly declared
- Use `Sendable` conformance for types passed between actors
- Prefer `struct` over `class` for models unless reference semantics needed

### Naming Conventions
- Types: PascalCase (e.g., `MediaFile`, `MetadataPipeline`)
- Functions/variables: camelCase (e.g., `displayName`, `validateContentType`)
- Private properties: No underscore prefix
- Constants: camelCase for local, PascalCase for static/global

### File Organization
- Models in `App/Models/`
- Controllers/business logic in `App/Controllers/`
- Views in `App/Views/`
- Tests in `Tests/`
- One primary type per file, named after the type

### Concurrency Patterns
- Use actors for mutable shared state: `SettingsStore`, `ArtworkCacheManager`, `JobQueue`, `StatusStream`
- Use `@MainActor` for UI-related code and view models
- Background work via `Task` or `Task.detached`
- Bounded concurrency with `AsyncSemaphore` in batch operations

## Security Practices

### Critical Security Rules
1. **Never log secrets**: Use `scrubSecrets()` before logging any user input or API responses
2. **Keychain for credentials**: Always store API keys in Keychain via `KeychainController`
3. **Localhost-only WebUI**: WebServer must bind to 127.0.0.1 only
4. **CORS restrictions**: Only allow http://127.0.0.1:8080 origin
5. **Input validation**: Validate all user input, especially file paths and metadata
6. **Temp file handling**: Use temp + atomic replace for file writes (never modify originals in-place)

### Security Testing
- Run `make security` before all PRs (warnings-as-errors + security tests)
- Add tests for any authentication/authorization code in `Tests/WebServerSecurityTests.swift`
- Add tests for input validation in `Tests/MetadataInputValidationTests.swift`

### Logging Security
- Use `AppLog.info()` or `AppLog.error()` from `Logging.swift`
- Never use `print()` for production logging
- All logs are automatically scrubbed via `scrubSecrets()` function
- Support `LOG_LEVEL=minimal` environment variable to reduce PII

Example:
```swift
AppLog.info(AppLog.providers, "Fetching metadata for: \(filename)")
AppLog.error(AppLog.network, "Request failed: \(error.localizedDescription)")
```

## Testing Practices

### Test Structure
- Use XCTest framework
- One test file per production file when possible
- Test files in `Tests/` directory
- Name pattern: `[TypeName]Tests.swift`

### Test Conventions
```swift
final class AtomCodecTests: XCTestCase {
    private var tempFile: URL!
    
    override func setUp() {
        super.setUp()
        // Setup resources
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
    }
    
    override func tearDown() {
        // Cleanup resources
        try? FileManager.default.removeItem(at: tempFile)
        super.tearDown()
    }
    
    func testSpecificBehavior() {
        // Test implementation
        XCTAssertEqual(actual, expected)
    }
}
```

### What to Test
- Public APIs and business logic (required)
- Security-critical code paths (required)
- Error handling and edge cases (recommended)
- Provider integration with mocks (see `MockURLProtocol.swift`)
- Circuit breakers and retry logic
- CORS and WebServer security

### What NOT to Test
- UI code (SwiftUI views)
- Private implementation details
- Third-party library behavior

## Dependencies

### Current Dependencies
- **Swifter** (1.5.0+): Embedded HTTP server
- **Alamofire** (5.6.4+): HTTP client for provider APIs

### Adding Dependencies
1. Update `Package.swift` dependencies array
2. Add to appropriate target's dependencies
3. Run `swift package resolve`
4. Verify build: `swift build`
5. Add tests if adding new functionality

### Optional Runtime Dependencies
- **FFmpeg**: Advanced codec detection and conversion (via shell execution)
- **Tesseract**: Bitmap subtitle OCR (via shell execution)
- Not required for basic MP4 tagging functionality

## Common Patterns

### Provider Pattern
All metadata providers conform to protocol and register with `ProvidersRegistry`:
```swift
public protocol MetadataProvider {
    func search(query: String) async throws -> [MetadataResult]
    func fetchMetadata(id: String) async throws -> Metadata
}
```

### Retry/Backoff Pattern
Use exponential backoff for network requests (see `ProviderRetryTests.swift`):
```swift
var delay = 1.0
for attempt in 0..<maxRetries {
    do {
        return try await operation()
    } catch {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        delay *= 2.0
    }
}
```

### Circuit Breaker Pattern
Implement circuit breakers for external services (see `CircuitBreakerTests.swift`)

### Actor-based State Management
```swift
public actor SettingsStore {
    private var settings: [String: Any] = [:]
    
    public func get(_ key: String) -> Any? {
        return settings[key]
    }
    
    public func set(_ key: String, value: Any) {
        settings[key] = value
    }
}
```

## MP4 Tagging

### Tag Mapping
- Title → `©nam`
- Artist/Performers → `©ART`
- Genre/Tags → `©gen`
- Release Date → `©day`
- Cover Art → `covr`
- TV Show → `tvsh`
- Season → `tvsn`
- Episode → `tves`
- Media Type → `stik`
- HD Video → `hdvd`

### Writing Process
1. Read existing metadata via AVFoundation
2. Export to temp file via AVAssetExportSession
3. Write ilst atoms via `AtomCodec.writeIlstAtoms()`
4. Atomic replace original file

## WebUI Development

### Server Configuration
- Bind address: 127.0.0.1 only (never 0.0.0.0)
- Default port: 8080
- Optional token authentication via `WEBUI_TOKEN` env var
- CORS: Restricted to same origin
- Rate limiting: Enforced per endpoint

### Security Headers
- `X-Content-Type-Options: nosniff`
- Content-Type validation for POST requests
- Body size limits enforced
- No credentials in frontend requests

## Codec Support

### Supported Formats
- **Video**: H.264, HEVC, AV1, VVC, VP8, VP9, ProRes, MPEG-1/2
- **Audio**: AAC, AC3, E-AC3, DTS, Opus, FLAC, TrueHD, MP3, PCM, ALAC
- **Subtitles**: SRT, WebVTT, TX3G, SSA/ASS, PGS, VobSub
- **Closed Captions**: CEA-608, CEA-708

### Detection Priority
1. AVFoundation for standard codecs
2. FFmpeg/ffprobe for advanced codecs
3. FourCC mapping fallback

## Documentation

### Key Documentation Files
- `README.md`: Quick start and overview
- `docs/USER_GUIDE.md`: End-user documentation
- `docs/TECHNICAL.md`: Architecture deep-dive
- `CHANGELOG.md`: Version history

### Code Documentation
- Add doc comments for public APIs
- Use `///` for documentation comments
- Include parameters and return values
- Example:
```swift
/// Fetches metadata from the provider.
/// - Parameter id: The unique identifier for the media item
/// - Returns: Metadata object with title, artists, genres, etc.
/// - Throws: NetworkError if request fails
public func fetchMetadata(id: String) async throws -> Metadata
```

## Common Issues and Solutions

### Build Issues
- Ensure Swift 5.9+ is installed
- Run `swift package clean` and rebuild
- Check that all dependencies resolved: `swift package resolve`

### Test Failures
- Check for leftover temp files from previous test runs
- Ensure Keychain access is not blocked (may prompt during tests)
- Network tests use `MockURLProtocol` to avoid real network calls

### Security Test Failures
- Review `make security` output for warnings
- Fix all compiler warnings (warnings-as-errors enabled)
- Ensure security tests pass in `Tests/WebServerSecurityTests.swift`

## Before Submitting PRs

1. Run tests: `swift test`
2. Run security validation: `make security`
3. Verify no secrets in logs or code
4. Check that Keychain is used for credentials
5. Ensure WebUI remains localhost-only
6. Update documentation if behavior changes
7. Add tests for new features or bug fixes

## Resources

- Swift Concurrency: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- MP4 Atom Structure: ISO/IEC 14496-12
- os.Logger: https://developer.apple.com/documentation/os/logger
