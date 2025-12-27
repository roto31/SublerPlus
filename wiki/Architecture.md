# Architecture

- SwiftUI app (macOS 12+), Swifter WebUI, CLI.
- Core pipeline: `MetadataPipeline` + `ProvidersRegistry` + `SublerMP4Handler` + `AtomCodec`.
- Providers: TPDB (adult), TMDB, TVDB, OpenSubtitles (subtitles), Subler local; retry/backoff + circuit breakers.
- Actors for shared state: SettingsStore, StatusStream, ArtworkCache, JobQueue.
- Disambiguation: modal sheet; cached choices (filename + studio + year).
- Watch folders: FolderMonitor with DispatchSource for file system events; auto-enqueue new files.
- Output options: retain originals mode, custom output directories, NFO sidecar generation.
- Subtitle management: SubtitleManager with OpenSubtitles integration (SRT/VTT formats).
- TV naming: customizable templates for episode naming (e.g., S%02dE%02d - %t).
- WebUI: 127.0.0.1, optional token, CORS locked, size/type checks, rate limiting.
- Logging: os.Logger; secret scrubbing; `LOG_LEVEL=minimal`.
- Tests: provider retries, circuit breaker, CORS/auth/limits, input validation, logging scrub, ambiguity cache, job queue.

