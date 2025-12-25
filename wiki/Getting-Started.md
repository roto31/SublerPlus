# Getting Started

## Requirements
- macOS 12+; Swift 5.9+
- API keys: TPDB (adult), TMDB, TVDB

## Build & Test
```bash
swift build
swift test
```

## Run (example with env keys)
```bash
WEBUI_TOKEN=yourtoken TPDB_API_KEY=... TMDB_API_KEY=... TVDB_API_KEY=... swift run SublerPlusApp
```
- Keys can also be set in-app (Keychain).
- Optional WebUI token is recommended.

## CLI
```bash
swift run sublerplus-cli /path/to/file.mp4
```

