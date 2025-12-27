# SublerPlus Technical Overview

## Architecture
- 100% Swift, macOS 12+. SwiftUI app, Swifter WebUI, CLI target.
- Core modules:
  - `MetadataPipeline`: orchestrates providers → writes MP4 via `SublerMP4Handler`.
  - Providers: TPDB (adult), TMDB, TVDB, Subler local. Each pluggable via `ProvidersRegistry`.
  - Persistence: Keychain for API keys, Settings actor, Artwork cache actor.
  - JobQueue actor: bounded concurrency for batch/folder monitor with statistics tracking.
  - StatusStream actor: structured status lines (also via `os.Logger`).
  - WebServer: localhost-only HTTP API, serves embedded WebUI assets.
  - AtomCodec: pure-Swift MP4 ilst read/write for richer tags.
  - FFmpegCodecDetector: Advanced codec detection using FFmpeg/ffprobe.
  - AudioConverter: Audio conversion engine (AVFoundation for AAC, FFmpeg for others).
  - DolbyVisionHandler: Dolby Vision RPU parsing and enhancement layer support.
  - HDRMetadataHandler: HDR metadata extraction and injection.
  - PresetManager: Muxing preset management with import/export.

## Concurrency
- Actors: `SettingsStore`, `ArtworkCacheManager`, `JobQueue`, `StatusStream`.
- `@MainActor` view models; background work via `Task` / `Task.detached`.
- Bounded concurrency with `AsyncSemaphore` in batch flow.

## MP4 Tagging
- Read hints via AVFoundation.
- Write via AVAssetExportSession passthrough + `AtomCodec.writeIlstAtoms`.
- Mapping: title → ©nam, performers → ©ART, tags → ©gen, release → ©day, cover → covr.

## Codec Support
- **Video Codecs**: H.264, HEVC, AV1, VVC, VP8, VP9, MPEG-1/2, Theora, DV variants, ProRes, XAVC
- **Audio Codecs**: AAC, AC3, E-AC3, DTS, Opus, Vorbis, FLAC, TrueHD, MLP, MP3, MP2, MP1, PCM, ALAC
- **Subtitle Formats**: SRT, WebVTT, TX3G, SSA/ASS, PGS, VobSub, FairPlay (drmt)
- **Closed Captions**: CEA-608, CEA-708, ATSC, FairPlay CEA-608 (p608)
- **Detection**: AVFoundation for standard codecs, FFmpeg/ffprobe for advanced codecs
- **FourCC Mapping**: Comprehensive mapping from FFmpeg codec names to MP4 FourCC codes

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

## Muxing & Remuxing
- **Muxer**: Full muxing/remuxing support with track selection and conversion
- **Audio Conversion**: AVFoundation for AAC, FFmpeg for other codecs (FLAC, Vorbis, MP3, Opus, TrueHD, MLP)
- **Subtitle Conversion**: SSA/ASS to TX3G, bitmap subtitle OCR (PGS, VobSub)
- **HDR Preservation**: Automatic HDR10 and HLG metadata preservation
- **Dolby Vision**: RPU data parsing and enhancement layer preservation
- **Presets**: Configurable muxing presets with import/export support

## Queue Operations
- **Statistics**: Real-time statistics (total processed, success/failure counts, average time, estimated remaining)
- **Advanced Editing**: Reorder, edit, bulk modify, duplicate, filter, and sort queue items
- **Batch Actions**: Preferred track selection, language setting, fallback fixes, track name clearing, group organization

## Tests
- Provider retry tests with mock URLProtocol.
- Job queue state tests, ambiguity cache Codable test, CORS preflight test.
- Security lane: `make security` (warnings as errors + `swift test --filter Security`).

## Building
- `swift build` / `swift test`
- Requires macOS 12+ toolchain, Swift 5.9+.
- Optional dependencies: FFmpeg (for advanced codec support), Tesseract (for bitmap subtitle OCR)

