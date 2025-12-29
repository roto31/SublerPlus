# Changelog

All notable changes to SublerPlus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.2-beta] - 2025-12-29

### Added
- **Apple Human Interface Guidelines (HIG) Compliance**
  - Standard macOS menu structure (App, File, Window, Help menus)
  - About window showing app version, copyright, and credits
  - Comprehensive accessibility labels, hints, and values across all views
  - ErrorPresenter utility for user-friendly error dialogs
  - Validation feedback for required fields (Web UI token with red border)
  - Window menu with Minimize (⌘M) and Zoom commands
  - Enhanced TokenField accessibility support for VoiceOver and keyboard navigation

### Changed
- **Keyboard Shortcuts**: Fixed conflicts and ensured standard macOS conventions
  - ⌘Q: Quit (standard)
  - ⌘W: Close Window (standard)
  - ⌘, (comma): Preferences (standard)
  - ⌘N: Add Files
  - ⌘E: Enrich Selected
  - ⌘F: Search
  - ⌘⇧O: Open Web UI in Browser
- **Button Hierarchy**: Ensured proper button styles following HIG
  - Primary actions: `.borderedProminent`
  - Secondary actions: `.bordered`
  - Destructive actions: `role: .destructive`
- **Form Structure**: Enhanced SettingsView with proper accessibility and validation
- **Build System**: Fixed MCPServer build issues
  - Added Swifter dependency to MCPServer target
  - Included MCPServer.swift and MCPIntegration.swift in Package.swift

### Fixed
- ErrorPresenter onChange issue with Equatable Error wrapper
- MCPServer compilation errors (missing HttpServer/HttpResponse types)
- Package.swift configuration for MCPServer module

## [0.4.1-beta] - 2025-12-28

### Added
- MCP Server integration for AI assistant support
- Enhanced metadata search with incremental streaming
- Advanced search interface with multiple provider support

### Changed
- Improved search architecture with better provider coordination
- Enhanced error handling and user feedback

## [0.4.0-beta] - 2025-12-27

### Added
- Initial beta release with full Subler integration
- MP42Foundation framework support
- SwiftUI-based user interface
- Metadata providers: TPDB, TMDB, TVDB, Subler local
- Web UI for remote access
- CLI tool for batch processing
- Job queue with bounded concurrency
- Artwork caching and management
- Subtitle support with OpenSubtitles integration
- Watch folder monitoring
- AppleScript support

### Changed
- Complete rewrite from Objective-C to Swift
- Modern SwiftUI architecture with actor-based concurrency
- Improved codec detection and support

---

[0.4.2-beta]: https://github.com/roto31/SublerPlus/compare/v0.4.1-beta...v0.4.2-beta
[0.4.1-beta]: https://github.com/roto31/SublerPlus/compare/v0.4.0-beta...v0.4.1-beta
[0.4.0-beta]: https://github.com/roto31/SublerPlus/releases/tag/v0.4.0-beta

