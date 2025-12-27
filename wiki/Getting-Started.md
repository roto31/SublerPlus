# Getting Started

## Requirements
- macOS 12+; Swift 5.9+
- API keys: TPDB (adult, optional), TMDB, TVDB, OpenSubtitles (via RapidAPI, optional)

## Build & Test
```bash
swift build
swift test
```

## Run (example with env keys)
```bash
WEBUI_TOKEN=yourtoken TPDB_API_KEY=... TMDB_API_KEY=... TVDB_API_KEY=... OPENSUBTITLES_API_KEY=... swift run SublerPlusApp
```
- Keys can also be set in-app (Keychain).
- Optional WebUI token is recommended.

## CLI
```bash
# Basic usage
swift run sublerplus-cli /path/to/file.mp4

# With options
swift run sublerplus-cli --no-adult --auto-best /path/to/file.mp4
```

## Key Features
- **Metadata Enrichment**: Automatic lookup from TMDB, TVDB, TPDB, and local sources
- **Watch Folders**: Auto-process new files from monitored directories
- **Subtitle Support**: Search and download subtitles via OpenSubtitles
- **NFO Generation**: Create .nfo sidecars for media center applications
- **Output Control**: Retain originals with custom output directories
- **TV Naming**: Customizable naming templates for TV episodes

