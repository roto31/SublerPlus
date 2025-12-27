# SublerPlus Changelog

## Overview

This document provides a comprehensive history of changes, features, and improvements made to SublerPlus across all versions. Each version section includes detailed information about new features, bug fixes, and technical improvements.

### Quick Navigation

- [Version 0.2.0-beta1](#version-020-beta1) - Latest beta release
- [Version 0.1.16b](#version-0116b)
- [Version 0.1.15b](#version-0115b)
- [Version 0.1.14b](#version-0114b)
- [Version 0.1.13b](#version-0113b)
- [Version 0.1.12b](#version-0112b)
- [Version 0.1.11b](#version-0111b)
- [Version 0.1.10b](#version-0110b)
- [Version 0.1.9b](#version-019b)
- [Version 0.1.8b](#version-018b)
- [Version 0.1.7b](#version-017b)
- [Version 0.1.6b](#version-016b)
- [Version 0.1.5b](#version-015b)
- [Version 0.1.4b](#version-014b)
- [Version 0.1.3b](#version-013b)
- [Version 0.1.2b](#version-012b)
- [Version 0.1.1b](#version-011b)
- [Version 0.1.0b](#version-010b) - Initial beta release

---

## Version 0.2.0-beta1

**Release Date:** December 2024

### Major Features

#### Track-Level UI Enhancements
- **Enhanced Track Display**: Completely redesigned track information display with organized sections for Video, Audio, Subtitles, and Other tracks
- **Detailed Track Information**: Each track now displays:
  - Codec information with visual emphasis
  - Language tags with globe icon
  - Resolution for video tracks
  - Bitrate information with gauge icon
  - HDR indicators with visual badges
  - Default and Forced track indicators with color-coded badges
- **Visual Organization**: Tracks are now grouped by type with clear section headers and improved visual hierarchy
- **Better Visual Feedback**: Tracks are displayed in styled containers with improved readability

#### Batch Queue UX Improvements
- **Queue Statistics**: Added real-time statistics display showing:
  - Total jobs count
  - Queued jobs with clock icon
  - Running jobs with spinner and blue indicator
  - Succeeded jobs with green checkmark
  - Failed jobs with red warning icon
- **Enhanced Job Display**: 
  - Status icons for each job state
  - Progress indicators for running jobs
  - Color-coded status badges with background highlights
  - Improved job card layout with better spacing and visual hierarchy
- **Empty State**: Added helpful message when no jobs are in queue
- **Better Visual Feedback**: Jobs are displayed in styled containers with improved contrast and readability

#### WebUI Enhancements
- **Improved Artwork Display**: 
  - Larger thumbnail size (80x80px) for better visibility
  - Placeholder display for missing artwork
  - Better image loading with lazy loading support
  - Enhanced shadow and border styling
- **Status Pill Improvements**:
  - Enhanced visual design with better padding and styling
  - Improved state indicators (Live, Reconnecting)
  - Better color coding for different states
  - Smooth transitions between states
- **Status Display**: 
  - Limited status display to most recent 10 items for better readability
  - Activity log shows last 20 items
  - Improved error handling and connection status feedback

#### Subtitle Integration
- **OpenSubtitles Integration**: Full integration with OpenSubtitles RapidAPI
  - Search functionality for subtitles by title and year
  - Download and automatic muxing of subtitles into MP4 files
  - Support for multiple subtitle languages
  - Default language configuration (defaults to "eng")
- **Subtitle Management UI**: 
  - Search button in file detail view
  - Display of subtitle candidates with language and score
  - One-click download and attach functionality
  - Automatic track inspection after subtitle attachment

### Technical Improvements

- **Enhanced Track Inspection**: Improved AVFoundation-based track inspection with better codec detection
- **Chapter Support**: Full chapter inspection, import, and export functionality
- **Metadata Expansion**: Extended metadata support including:
  - TV show information (show, season, episode)
  - Media kind classification
  - Sort titles and artists
  - Track and disc numbers
  - HD/HEVC/HDR flags
  - Content ratings
  - Lyrics support
  - Gapless and compilation flags
- **Artwork Management**: 
  - Artwork cache clearing functionality
  - Artwork refresh for selected files
  - Alternate artwork selection and application
- **Folder Monitoring**: Enhanced folder monitoring with automatic file detection and batch processing

### Bug Fixes

- Fixed track display formatting issues
- Improved job status update reliability
- Enhanced WebUI connection status handling
- Fixed artwork loading edge cases

### Documentation

- Updated user guide with new features
- Enhanced technical documentation
- Added subtitle integration documentation

---

## Version 0.1.16b

**Release Date:** December 2024

### Features

- Enhanced metadata provider integration
- Improved ambiguity resolution caching
- Better error handling in batch processing
- Performance optimizations for large file sets

### Bug Fixes

- Fixed memory leaks in job queue
- Improved stability during concurrent operations
- Fixed artwork cache persistence issues

---

## Version 0.1.15b

**Release Date:** December 2024

### Features

- Advanced search functionality with multiple criteria
- Provider preference settings
- Enhanced metadata merging logic
- Improved TV show detection and naming

### Technical Improvements

- Optimized provider API calls
- Better retry logic with exponential backoff
- Enhanced circuit breaker implementation

---

## Version 0.1.14b

**Release Date:** December 2024

### Features

- Folder monitoring and automatic processing
- Watch folder configuration in settings
- Recursive folder scanning
- Automatic file detection and enqueueing

### Bug Fixes

- Fixed folder monitoring edge cases
- Improved file detection reliability
- Fixed duplicate file handling

---

## Version 0.1.13b

**Release Date:** December 2024

### Features

- NFO file generation support
- Configurable NFO output directory
- TV naming template system
- Enhanced metadata export options

### Technical Improvements

- Improved metadata serialization
- Better file I/O error handling
- Enhanced logging for debugging

---

## Version 0.1.12b

**Release Date:** December 2024

### Features

- Preset system for metadata exports
- Apple TV tag support
- Enhanced MP4 atom writing
- Support for additional metadata fields

### Bug Fixes

- Fixed atom writing edge cases
- Improved metadata preservation
- Fixed tag encoding issues

---

## Version 0.1.11b

**Release Date:** December 2024

### Features

- Chapter import/export functionality
- Chapter text file parsing
- Chapter metadata inspection
- Time-based chapter formatting

### Technical Improvements

- Enhanced AVFoundation integration
- Better chapter metadata handling
- Improved time parsing and formatting

---

## Version 0.1.10b

**Release Date:** December 2024

### Features

- Track inspection functionality
- Video, audio, and subtitle track detection
- Codec information display
- Track language and bitrate information
- HDR detection for video tracks

### Technical Improvements

- AVFoundation track loading
- Format description parsing
- Enhanced media file inspection

---

## Version 0.1.9b

**Release Date:** December 2024

### Features

- Enhanced WebUI dashboard
- Improved search results display
- Artwork thumbnail support in WebUI
- Better status polling and display

### Bug Fixes

- Fixed WebUI authentication issues
- Improved CORS handling
- Fixed status update reliability

---

## Version 0.1.8b

**Release Date:** December 2024

### Features

- Batch processing improvements
- Job queue enhancements
- Better job status tracking
- Retry functionality for failed jobs

### Technical Improvements

- Actor-based job queue implementation
- Improved concurrency handling
- Better error propagation

---

## Version 0.1.7b

**Release Date:** December 2024

### Features

- Ambiguity resolution UI
- Choice caching system
- Automatic resolution based on history
- Enhanced metadata matching

### Bug Fixes

- Fixed ambiguity resolution edge cases
- Improved choice persistence
- Better cache key generation

---

## Version 0.1.6b

**Release Date:** December 2024

### Features

- Artwork cache management
- Artwork download and caching
- Alternate artwork selection
- Artwork refresh functionality

### Technical Improvements

- Async artwork fetching
- Improved cache persistence
- Better image handling

---

## Version 0.1.5b

**Release Date:** December 2024

### Features

- Settings view implementation
- API key management in Keychain
- WebUI token configuration
- Adult content toggle
- Provider confidence settings

### Security Improvements

- Secure keychain storage
- Token rotation reminders
- Enhanced key management

---

## Version 0.1.4b

**Release Date:** December 2024

### Features

- WebUI implementation with Swifter
- Localhost-only server binding
- CORS security implementation
- File upload via WebUI
- Search functionality in WebUI

### Security Improvements

- Localhost-only binding
- CORS restrictions
- Token-based authentication
- Rate limiting

---

## Version 0.1.3b

**Release Date:** December 2024

### Features

- CLI implementation
- Command-line file processing
- Batch processing support
- Recursive folder processing
- CLI flags for adult content and auto-selection

### Technical Improvements

- Shared pipeline between app and CLI
- Better error handling
- Improved logging

---

## Version 0.1.2b

**Release Date:** December 2024

### Features

- Metadata pipeline implementation
- Provider registry system
- Metadata merging logic
- MP4 atom writing via AtomCodec

### Technical Improvements

- Pure Swift MP4 manipulation
- Enhanced atom codec
- Better metadata mapping

---

## Version 0.1.1b

**Release Date:** December 2024

### Features

- Multiple metadata provider support
- ThePornDB integration
- TMDB integration
- TVDB integration
- Subler local metadata provider

### Technical Improvements

- Provider abstraction layer
- Retry logic with exponential backoff
- Circuit breaker implementation
- Enhanced error handling

---

## Version 0.1.0b

**Release Date:** December 2024

### Initial Release Features

#### Core Functionality
- **SwiftUI macOS Application**: Modern SwiftUI-based interface for macOS 12+
- **MP4 Metadata Tagging**: Full support for reading and writing MP4 metadata atoms
- **Pure Swift Implementation**: 100% Swift codebase, no Objective-C dependencies
- **SwiftPM Package**: Modern Swift Package Manager structure

#### Metadata Providers
- **ThePornDB Provider**: Adult content metadata provider with confidence scoring
- **TMDB Provider**: The Movie Database integration for movies and TV shows
- **TVDB Provider**: The TV Database integration for television content
- **Subler Local Provider**: Reads existing metadata from MP4 files

#### MP4 Tagging
- **AtomCodec**: Pure Swift implementation for MP4 atom manipulation
- **Comprehensive Tag Support**: 
  - Title (©nam)
  - Artist/Performers (©ART)
  - Genre/Tags (©gen)
  - Release Date (©day)
  - Cover Artwork (covr)
  - Additional metadata atoms

#### User Interface
- **File List View**: Drag-and-drop file support
- **File Detail View**: Comprehensive metadata display
- **Advanced Search**: Multi-criteria search functionality
- **Settings View**: Configuration and API key management
- **Accessibility**: Full accessibility support with labels and hints

#### Security Features
- **Keychain Integration**: Secure storage of API keys
- **Localhost-Only WebUI**: Web interface bound to 127.0.0.1 only
- **CORS Protection**: Restricted cross-origin requests
- **Token Authentication**: Optional token-based WebUI authentication
- **Secret Scrubbing**: Automatic scrubbing of sensitive data in logs

#### Architecture
- **Actor-Based Concurrency**: Modern Swift concurrency with actors
- **Job Queue**: Actor-backed queue for batch processing
- **Status Stream**: Structured status logging
- **Artwork Cache**: Async artwork caching system
- **Settings Store**: Actor-based settings persistence

#### Developer Features
- **CLI Tool**: Command-line interface for headless operation
- **Comprehensive Tests**: Unit tests for core functionality
- **Security Lane**: Automated security testing
- **Documentation**: Technical and user documentation

### Technical Details

- **Platform**: macOS 12.0+
- **Language**: Swift 5.9+
- **Dependencies**: 
  - Swifter (WebUI server)
  - Alamofire (HTTP client)
- **Build System**: Swift Package Manager
- **Architecture**: MVVM with SwiftUI

---

## Notes

- All versions are beta releases and may contain bugs or incomplete features
- API keys are required for full functionality (TPDB, TMDB, TVDB)
- WebUI token is optional but recommended for security
- Some features may require specific API access or subscriptions

---

## Contributing

For information about contributing to SublerPlus, please see the [CONTRIBUTING.md](Subler/CONTRIBUTING.md) file.

## License

SublerPlus is licensed under the same license as Subler. See [LICENSE](Subler/LICENSE) for details.

