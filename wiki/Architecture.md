# Architecture

- SwiftUI app (macOS 12+), Swifter WebUI, CLI.
- Core pipeline: `MetadataPipeline` + `ProvidersRegistry` + `SublerMP4Handler` + `AtomCodec`.
- Providers: TPDB (adult), TMDB, TVDB, Subler local; retry/backoff + circuit breakers.
- Actors for shared state: SettingsStore, StatusStream, ArtworkCache, JobQueue, PresetManager.
- Disambiguation: modal sheet; cached choices (filename + studio + year).
- WebUI: 127.0.0.1, optional token, CORS locked, size/type checks, rate limiting.
- Logging: os.Logger; secret scrubbing; `LOG_LEVEL=minimal`.
- Codec Support: AVFoundation + FFmpeg for comprehensive codec detection and conversion.
- Muxing: Full muxing/remuxing with audio conversion, subtitle embedding, HDR/Dolby Vision preservation.
- Tests: provider retries, circuit breaker, CORS/auth/limits, input validation, logging scrub, ambiguity cache, job queue.

