# SublerPlus Technical Overview

## Architecture
- 100% Swift, macOS 12+. SwiftUI app, Swifter WebUI, CLI target.
- Core modules:
  - `MetadataPipeline`: orchestrates providers → writes MP4 via `SublerMP4Handler`.
  - Providers: TPDB (adult), TMDB, TVDB, Subler local. Each pluggable via `ProvidersRegistry`.
  - Persistence: Keychain for API keys, Settings actor, Artwork cache actor.
  - JobQueue actor: bounded concurrency for batch/folder monitor.
  - StatusStream actor: structured status lines (also via `os.Logger`).
  - WebServer: localhost-only HTTP API, serves embedded WebUI assets.
  - AtomCodec: pure-Swift MP4 ilst read/write for richer tags.

## Concurrency
- Actors: `SettingsStore`, `ArtworkCacheManager`, `JobQueue`, `StatusStream`.
- `@MainActor` view models; background work via `Task` / `Task.detached`.
- Bounded concurrency with `AsyncSemaphore` in batch flow.

## MP4 Tagging
- Read hints via AVFoundation.
- Write via AVAssetExportSession passthrough + `AtomCodec.writeIlstAtoms`.
- Mapping: title → ©nam, performers → ©ART, tags → ©gen, release → ©day, cover → covr.

## Providers
- TPDB/TMDB/TVDB use HTTPS-only, JSONDecoder, retry/backoff with exponential delay.
- SublerProvider uses local MP4 hint/metadata.
- Merge/disambiguation: pipeline collects candidates, picks best or defers to UI sheet. Cache remembers choices (filename+studio+year).

## WebUI
- Swifter server bound to 127.0.0.1:8080.
- CORS: allow only http://127.0.0.1:8080, GET/POST/OPTIONS, nosniff.
- Assets served from bundle path; directory traversal blocked.
- `main.js` uses same-origin, no credentials.

## Logging
- `os.Logger` categories in `Logging.swift`.
- StatusStream retains recent lines for UI and WebUI.

## Tests
- Provider retry tests with mock URLProtocol.
- Job queue state tests, ambiguity cache Codable test, CORS preflight test.
- Security lane: `make security` (warnings as errors + `swift test --filter Security`).

## Building
- `swift build` / `swift test`
- Requires macOS 12+ toolchain, Swift 5.9+.

