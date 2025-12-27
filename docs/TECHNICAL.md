# SublerPlus Technical Overview

## Architecture
- 100% Swift, macOS 12+. SwiftUI app, Swifter WebUI, CLI target.
- Core modules:
  - `MetadataPipeline`: orchestrates providers → writes MP4 via `SublerMP4Handler`.
  - Providers: TPDB (adult), TMDB, TVDB, OpenSubtitles (subtitles), Subler local. Each pluggable via `ProvidersRegistry`.
  - Persistence: Keychain for API keys, Settings actor, Artwork cache actor.
  - JobQueue actor: bounded concurrency for batch/folder monitor.
  - StatusStream actor: structured status lines (also via `os.Logger`).
  - WebServer: localhost-only HTTP API, serves embedded WebUI assets.
  - AtomCodec: pure-Swift MP4 ilst read/write for richer tags.
  - FolderMonitor: watches directories for new files using DispatchSource.
  - SubtitleManager: searches and downloads subtitles via OpenSubtitles.
  - NFOGenerator: generates Kodi/Plex-compatible .nfo XML sidecar files.

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
- OpenSubtitles uses RapidAPI integration for subtitle search and download.
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

## Output Options
- **Retain Originals Mode**: When enabled, enriched files are written to a custom output directory, preserving the original files.
- **Output Directory**: Configurable destination for enriched media (stored in AppSettings).
- **File Operations**: Uses temporary files + atomic replace for safe writes.

## NFO Generation
- `NFOGenerator` creates XML sidecar files compatible with Kodi and Plex.
- Content includes: title, plot, studio, actors, genres from MetadataDetails.
- Output location: same directory as media or custom NFO directory.
- Controlled via `generateNFO` and `nfoOutputDirectory` settings.

## Subtitle Management
- `SubtitleManager` integrates with OpenSubtitles via RapidAPI.
- Search by title, year, and language (ISO 639-2 codes).
- Downloads SRT and VTT formats.
- Language preference stored in AppSettings (`defaultSubtitleLanguage`).

## Watch Folders
- `FolderMonitor` uses DispatchSource to watch directories for file system events.
- AppViewModel manages multiple monitors via `folderMonitors` dictionary.
- New files in watched folders are automatically added to processing queue.
- Tracks known files to avoid duplicate processing.

## TV Show Naming
- Customizable naming templates for TV episodes (e.g., `S%02dE%02d - %t`).
- Template placeholders:
  - `%02d`: Season/episode numbers with zero padding
  - `%t`: Episode title
- Applied during file write operations in MetadataPipeline.

## Tests
- Provider retry tests with mock URLProtocol.
- Job queue state tests, ambiguity cache Codable test, CORS preflight test.
- Security lane: `make security` (warnings as errors + `swift test --filter Security`).

## Building
- `swift build` / `swift test`
- Requires macOS 12+ toolchain, Swift 5.9+.

