# SublerPlus

A modern macOS application for enriching MP4 media files with metadata from multiple providers, built with SwiftUI and full Subler integration.

## Features

- **Multi-Provider Metadata Search**: TPDB, TMDB, TVDB, and local Subler metadata
- **Modern SwiftUI Interface**: Native macOS app with full HIG compliance
- **Accessibility Support**: Comprehensive VoiceOver and keyboard navigation support
- **Web UI**: Embedded web interface for remote access (localhost only)
- **CLI Tool**: Command-line interface for batch processing
- **Job Queue**: Background processing with bounded concurrency
- **Subtitle Support**: Automatic subtitle lookup via OpenSubtitles
- **Watch Folders**: Automatic processing of new media files
- **AppleScript Support**: Automation and scripting capabilities
- **MCP Server**: Model Context Protocol server for AI assistant integration

## Requirements

- macOS 12.0 or later
- Swift 5.9+
- Xcode 14+ (for building from source)
- Optional: FFmpeg (for advanced codec support)
- Optional: Tesseract OCR (for bitmap subtitle conversion)

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/roto31/SublerPlus.git
cd SublerPlus
```

2. Build using the build script:
```bash
./scripts/build-with-subler.sh --release
```

The built app will be available at `build/SublerPlus.app`.

### API Keys

Set API keys for metadata providers:

- **TPDB**: ThePornDB API key (optional, for adult content)
- **TMDB**: The Movie Database API key
- **TVDB**: TheTVDB API key
- **OpenSubtitles**: OpenSubtitles API key (for subtitle lookup)

Keys can be set:
- In-app Settings (stored in Keychain)
- Environment variables: `TPDB_API_KEY`, `TMDB_API_KEY`, `TVDB_API_KEY`, `OPENSUBTITLES_API_KEY`

## Usage

### Main Application

1. **Add Files**: Use "Add Files" (⌘N) or drag-and-drop files into the app
2. **Enrich**: Select a file and click "Enrich" (⌘E) or use batch enqueue
3. **Search**: Use the Advanced Search view to find metadata manually
4. **Settings**: Configure providers, output directories, and preferences (⌘,)

### Keyboard Shortcuts

- ⌘N: Add Files
- ⌘E: Enrich Selected
- ⌘F: Search
- ⌘W: Close Window
- ⌘Q: Quit
- ⌘, (comma): Preferences
- ⌘⇧O: Open Web UI in Browser

### CLI Tool

```bash
./build/SublerPlusCLI /path/to/file.mp4
```

Options:
- `--no-adult`: Disable adult metadata providers
- `--auto-best`: Automatically select best match

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **Actors**: Thread-safe concurrency with `SettingsStore`, `ArtworkCacheManager`, `JobQueue`, `StatusStream`
- **MP42Foundation**: Full Subler integration for MP4 manipulation
- **Swifter**: Embedded web server for Web UI
- **Alamofire**: HTTP networking for metadata providers

See [docs/TECHNICAL.md](docs/TECHNICAL.md) for detailed architecture documentation.

## Documentation

- [User Guide](docs/USER_GUIDE.md) - Getting started and usage instructions
- [Technical Overview](docs/TECHNICAL.md) - Architecture and implementation details
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Security](docs/SECURITY.md) - Security features and best practices

## Contributing

Contributions are welcome! Please see [Subler/CONTRIBUTING.md](Subler/CONTRIBUTING.md) for guidelines.

## License

See [Subler/LICENSE](Subler/LICENSE) for license information.

## Acknowledgments

- Built on [Subler](https://github.com/lhc70000/subler) by Damiano Galassi
- Uses [MP42Foundation](https://github.com/lhc70000/subler) for MP4 manipulation
- Metadata providers: TPDB, TMDB, TVDB, OpenSubtitles

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

---

**Current Version**: 0.4.2-beta

