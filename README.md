# SublerPlus

SwiftUI macOS app (12+) for MP4 metadata enrichment. Includes adult + standard providers, pure-Swift MP4 atom tagging, embedded WebUI (Swifter), CLI, secure defaults (Keychain, localhost-only server, retry/backoff + circuit breakers), and accessibility/HIG-aligned UI.

## Highlights
- MP4 tagging: AVFoundation passthrough + Swift AtomCodec (moov/udta/meta/ilst) for title/artist/genre/date/cover.
- Providers: TMDB, TVDB, TPDB (adult), OpenSubtitles (subtitles), Subler local. Retry/backoff and circuit breakers per provider.
- Disambiguation: modal picker; remembers choices (filename + studio + year) for batch auto-resolve.
- Jobs: actor-backed queue with bounded concurrency; drag/drop and batch ingest; activity feed.
- Watch folders: auto-enqueue new media files from monitored folders with bounded concurrency.
- Output options: retain originals (copy mode), custom output directories, NFO sidecar generation.
- TV show support: customizable naming templates (e.g., S%02dE%02d - %t) for TV episodes.
- Subtitles: search and download via OpenSubtitles; support for multiple languages.
- WebUI: Swifter on 127.0.0.1, optional token auth (`WEBUI_TOKEN`), CORS locked, size/type checks, rate limiting.
- CLI: same pipeline as the app for headless runs.
- Accessibility/HIG: labeled controls, keyboard shortcuts, reduce-motion/transparency aware.
- Logging: os.Logger; secret scrubbing; `LOG_LEVEL=minimal` to reduce PII.

## Requirements
- macOS 12+; Swift 5.9+.
- API keys: Stored in Keychain via Settings, or provided via env vars.
  - TPDB (adult content, optional)
  - TMDB (movies/TV)
  - TVDB (TV shows)
  - OpenSubtitles (subtitles, optional, requires RapidAPI key)

## Setup
```bash
# build & test
swift build
swift test

# run app (example with env keys)
WEBUI_TOKEN=yourtoken TPDB_API_KEY=... TMDB_API_KEY=... TVDB_API_KEY=... OPENSUBTITLES_API_KEY=... swift run SublerPlusApp

# run CLI
swift run sublerplus-cli /path/to/file.mp4

# CLI options
swift run sublerplus-cli --no-adult --auto-best /path/to/file.mp4
```
- In-app Settings can store keys in Keychain and manage WebUI token.
- Optional WebUI token is recommended for local API use.
- Watch folders can be configured in Settings to automatically process new media files.
- Retain originals mode writes enriched files to a custom output directory.

## Commands
- App: `swift run SublerPlusApp`
- CLI: `swift run sublerplus-cli /path/to/file.mp4`
- Security lane: `make security` (warnings-as-errors + `swift test --filter Security`)

## Security Posture
- Localhost-only WebUI with optional token auth.
- CORS restricted to 127.0.0.1; content-type/body-size checks; rate limiting.
- Keys in Keychain; logs scrub secrets; minimal log level supported.
- Atom writes use temp + replace; no native shims.

## Documentation
- `docs/USER_GUIDE.md` — usage and UI
- `docs/TECHNICAL.md` — architecture
- `docs/SECURITY.md` — threat model and hardening
- `docs/TROUBLESHOOTING.md` — common issues

## Contributing
- Keep SwiftPM build/tests green: `swift test`.
- Run `make security` before PRs.
- Do not log secrets; prefer Keychain for credentials.

