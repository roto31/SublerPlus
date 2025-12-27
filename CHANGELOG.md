# SublerPlus Changelog

## Overview

This document provides a comprehensive history of changes, features, and improvements made to SublerPlus across all versions. Each version section includes detailed information about new features, bug fixes, and technical improvements.

### Quick Navigation

- [Version 0.3.0b](#version-030b) - Latest beta release
- [Version 0.2.3b](#version-023b)
- [Version 0.2.2b](#version-022b)
- [Version 0.2.1b](#version-021b)
- [Version 0.2.0-beta1](#version-020-beta1)
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

## Version 0.3.0b

**Release Date:** December 2024

### Major Features

#### Drag-and-Drop Metadata Search and Apply (New Feature)
- **File Drop Support**: Drag and drop media files directly onto the Advanced Search pane
- **Automatic Metadata Extraction**: Automatically reads and displays existing metadata from dropped files
- **Sidebar Metadata Display**: New resizable sidebar showing:
  - File name and artwork
  - Title, studio, year, performers
  - Synopsis (if available)
  - TV show information (show, season, episode)
- **Auto-Populate Search Fields**: Automatically populates search fields from file metadata (preserves user input)
- **Enhanced Search Results**: Selectable results list with detailed metadata preview
- **Result Details View**: Full metadata display for selected search results including:
  - Title, year, studio, rating
  - Short and long descriptions
  - Performers and directors
  - TV show details
- **Apply Workflow**: Confirmation dialog before applying metadata, then automatic artwork picker
- **Artwork Integration**: Seamless artwork selection after metadata application
- **Visual Feedback**: Drag-and-drop visual indicators and loading states

#### TV Show Metadata Extraction from MP4 Atoms (Enhancement)
- **Direct Atom Parsing**: Reads TV show metadata directly from MP4 atoms (tvsh, tvsn, tves, tven)
- **Rating Extraction**: Extracts content rating (rtng) from MP4 atoms
- **Comprehensive Metadata Reading**: Enhanced `readFullMetadata` method that combines:
  - AVFoundation metadata (title, synopsis, studio, etc.)
  - MP4 atom metadata (TV show info, rating, track/disc numbers, etc.)
- **Atom Codec Enhancement**: New `readIlst` method in AtomCodec for parsing MP4 metadata atoms
- **Data Atom Parser**: Supports multiple data types:
  - UTF-8 strings (tvsh, ©nam, etc.)
  - Signed integers (tvsn, tves, rtng, etc.)
  - Pairs (trkn, disk)
  - Image data (covr)
- **Robust Error Handling**: Graceful fallback to AVFoundation if atom parsing fails
- **Edge Case Handling**: Comprehensive bounds checking and malformed atom handling

### Technical Improvements

- **AtomCodec.readIlst**: New method for reading and parsing ilst atoms from MP4 files
- **AtomCodec.parseDataAtom**: Enhanced data atom parser with type-specific handling
- **MetadataManager.readFullMetadata**: Enhanced to extract metadata from both AVFoundation and MP4 atoms
- **ViewModels.loadMetadataFromFile**: New method for loading metadata from dropped files
- **AdvancedSearchView**: Complete UI overhaul with drag-drop, sidebar, and enhanced results display
- **Error Handling**: Comprehensive error handling for unsupported files, network errors, and edge cases

### Bug Fixes

- Fixed compilation errors related to non-existent AVMetadataIdentifier constants
- Improved metadata extraction reliability
- Enhanced file type validation
- Better error messages for unsupported file types

### Documentation

- Updated user guide with drag-and-drop feature documentation
- Enhanced technical documentation with atom parsing details
- Added troubleshooting sections for common issues

---

## Version 0.2.3b

**Release Date:** December 2024

### Major Features

#### Complete Video Codec Support (Phase 13)
- **Extended Codec Detection**: Added support for legacy and advanced video codecs:
  - MPEG-1 Video (mp1v)
  - MPEG-2 Video (mp2v)
  - Theora (XiTh)
  - DV variants (dvc, dvcp, dv5n, dv5p, dvhp, dvhq, dvh6, dvh5, dvh3, dvh2)
  - ProRes variants (ap4h, apch, apcn, apcs, apco, aprn)
  - XAVC Long GOP (xalg)
- **FourCC Code Mapping**: Enhanced `FFmpegCodecDetector` with comprehensive FFmpeg codec name to FourCC mapping
- **Passthrough Support**: All detected codecs now support passthrough muxing
- **Codec Validation**: Added codec-specific validation in muxing pipeline

#### Complete Audio Codec Support & MLP Conversion (Phase 14)
- **MLP Support**: Added Meridian Lossless Packing (MLP) codec support
- **MLP→AC3 Conversion**: Implemented automatic MLP to AC3 conversion via FFmpeg for compatibility
- **Enhanced Audio Detection**: Verified and enhanced detection for all audio codecs:
  - ALAC, E-AC3, DTS, Opus, Vorbis, FLAC, TrueHD, MPEG Layer 1/2/3, Linear PCM
- **Audio Conversion Engine**: Improved audio conversion with better edge case handling

#### FairPlay Subtitle & Closed Caption Support (Phase 15)
- **FairPlay Detection**: Added detection for FairPlay-encrypted subtitles (drmt codec)
- **FairPlay Closed Captions**: Added detection for FairPlay CEA-608 closed captions (p608 codec)
- **FairPlay Handlers**: Created `FairPlaySubtitleHandler` and `FairPlayCCHandler` for proper handling
- **User Messaging**: Appropriate error messages for FairPlay-protected content (passthrough only)
- **UI Indicators**: Added UI indicators for FairPlay-protected tracks

#### Complete ATSC Closed Caption Implementation (Phase 16)
- **ATSC Extraction**: Full implementation of ATSC caption extraction from transport streams (TS/M2TS files)
- **ATSC→TX3G Conversion**: Complete conversion pipeline from ATSC format to TX3G samples
- **Format Detection**: Enhanced format detection for TS, M2TS, and MTS files
- **Alternative Extraction**: Multiple extraction methods for maximum compatibility

#### Advanced Dolby Vision RPU Handling (Phase 17)
- **RPU Parsing**: Complete parsing of Dolby Vision Reference Processing Unit (RPU) data structure
- **Metadata Extraction**: Extract Dolby Vision metadata (profile, level, dynamic metadata) from dvcC, dvvC, and dvwC atoms
- **Enhancement Layer Support**: Full support for Dolby Vision enhancement layer (EL) and base layer (BL) tracks
- **Track Grouping**: Support for Dolby Vision track grouping to maintain proper relationships
- **RPU Preservation**: Preserve RPU data in sample buffers during muxing operations

#### Explicit HDR Metadata Injection (Phase 18)
- **HDR Metadata Creation**: Create HDR10 and HLG metadata from parameters
- **Metadata Injection**: Inject Mastering Display Color Volume and Content Light Level Info metadata
- **Format Description Enhancement**: Enhanced CMFormatDescription creation with HDR extensions
- **HDR10 Support**: Full support for HDR10 metadata with maxCLL and maxFALL parameters
- **HLG Support**: Support for Hybrid Log-Gamma (HLG) metadata injection

#### Preset Import/Export (Phase 19)
- **Preset Export**: Export presets to JSON or PLIST format
- **Preset Import**: Import presets from JSON or PLIST files with validation
- **Conflict Resolution**: Three conflict resolution strategies:
  - Skip conflicting presets
  - Overwrite existing presets
  - Rename imported presets automatically
- **Preset Validation**: Comprehensive validation of imported preset structure
- **Import Results**: Detailed import results showing added, updated, skipped, and invalid presets

#### Enhanced Queue Statistics & Advanced Editing (Phase 20)
- **Queue Statistics**: Comprehensive statistics tracking:
  - Total jobs processed
  - Success and failure counts
  - Average processing time per job
  - Current queue size and running count
  - Estimated time remaining
- **Queue Reordering**: Drag-and-drop reordering of queue items
- **Job Editing**: Edit job settings and actions before processing
- **Bulk Modification**: Bulk modify multiple queue items simultaneously
- **Job Duplication**: Duplicate existing queue items
- **Queue Filtering**: Filter queue by status or URL pattern
- **Queue Sorting**: Multiple sort options (URL ascending/descending, status, added first/last)

### Technical Improvements

- **FFmpegCodecDetector**: Enhanced with comprehensive codec-to-FourCC mapping for all supported formats
- **ContainerImporter**: Improved codec detection with FourCC code support
- **AudioConverter**: Added MLP conversion support and improved conversion pipeline
- **ClosedCaptionHandler**: Complete ATSC support with multiple extraction methods
- **DolbyVisionHandler**: Full RPU parsing and enhancement layer preservation
- **HDRMetadataHandler**: Explicit HDR metadata injection capabilities
- **PresetManager**: Import/export functionality with conflict resolution
- **JobQueue**: Statistics tracking and advanced editing capabilities

### Bug Fixes

- Fixed codec detection for legacy formats
- Improved passthrough muxing for unsupported codecs
- Enhanced error handling for FairPlay-protected content
- Fixed ATSC caption extraction edge cases
- Improved Dolby Vision metadata preservation

### Documentation

- Updated technical documentation with new codec support
- Enhanced user guide with new features
- Added documentation for preset import/export
- Updated queue operations documentation

---

## Version 0.2.2b

**Release Date:** December 2024

### Features

- Additional bug fixes and stability improvements
- Performance optimizations

---

## Version 0.2.1b

**Release Date:** December 2024

### Features

- Additional bug fixes and stability improvements
- Performance optimizations

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

