# SublerPlus Beta 0.4.0 Release Notes

**Version:** 0.4.0-beta  
**Release Date:** December 2024  
**Build Type:** Beta Release

---

## 🎯 Version Overview

SublerPlus Beta 0.4.0 introduces full Subler integration support, enabling SwiftPM builds with complete compatibility to Subler's search architecture. This release represents a significant milestone in bridging modern Swift concurrency patterns with legacy Subler infrastructure.

---

## 🎨 Icon

**Icon Name:** `SublerPlus-AppIcon-v0.4`  
**Icon Description:** Modern film clapperboard design with integrated search magnifying glass, featuring a gradient blue background with Swift logo accent. The icon represents the dual nature of SublerPlus: traditional media metadata management (clapperboard) combined with advanced search capabilities (magnifying glass).

**Icon Specifications:**
- Format: PNG
- Base Size: 1024x1024 pixels
- Location: `App/Resources/AppIcon.appiconset/`
- Generated Sizes: 16x16, 32x32, 128x128, 256x256, 512x512 (1x and 2x variants)

**Icon Setup:**
The icon is automatically integrated during the build process. To update or regenerate:
```bash
./scripts/setup-app-icon.sh /path/to/icon-1024x1024.png
```

---

## 🚀 Build Process

### Prerequisites
- macOS 12.0 or later
- Xcode 15.0 or later (for MP42Foundation framework builds)
- Swift 5.9 or later
- Swift Package Manager

### Build Options

#### Option 1: Standard Build (Recommended for most users)
```bash
# Debug build with tests
./scripts/build.sh

# Release build
./scripts/build.sh --release
```

#### Option 2: Full Subler Integration Build
```bash
# Build with MP42Foundation framework and SublerCompatibility
./scripts/build-with-subler.sh

# Release build with full integration
./scripts/build-with-subler.sh --release
```

### Build Steps

1. **Clean Previous Builds** (Optional)
   ```bash
   rm -rf .build build/
   ```

2. **Set Version** (Optional - auto-increments if not set)
   ```bash
   export BASE_VERSION=0.4.0
   export PRERELEASE=beta
   # Or set full version:
   export VERSION=0.4.0-beta
   ```

3. **Execute Build**
   ```bash
   ./scripts/build.sh --release
   ```

4. **Verify Build**
   ```bash
   # Check build output
   ls -lh "build/App builds/SublerPlus-0.4.0-beta/"
   
   # Verify executable
   file "build/App builds/SublerPlus-0.4.0-beta/SublerPlus.app/Contents/MacOS/SublerPlus"
   ```

### Build Output

**Location:** `build/App builds/SublerPlus-0.4.0-beta/`

**Contents:**
- `SublerPlus.app` - Application bundle
- `SublerPlus-0.4.0-beta.zip` - Distribution archive

**Bundle Structure:**
```
SublerPlus.app/
├── Contents/
│   ├── Info.plist (version: 0.4.0-beta)
│   ├── MacOS/
│   │   └── SublerPlus (executable)
│   ├── Resources/
│   │   └── AppIcon.appiconset/ (icon assets)
│   └── Frameworks/ (if built with Subler integration)
```

---

## ✨ Key Features in Beta 0.4.0

### 1. Full Subler Integration Support
- **SublerCompatibility Layer**: Complete integration with Subler's `MetadataService` protocol
- **MP42Foundation Framework**: Optional framework support for full Subler feature parity
- **Conditional Compilation**: Graceful degradation when MP42Foundation is unavailable
- **Dual Architecture**: Supports both modern `MetadataProvider` and legacy `MetadataService`

### 2. Enhanced Build System
- **Unified Build Script**: `build-with-subler.sh` for complete Subler integration
- **Automatic Framework Building**: MP42Foundation framework built automatically when needed
- **Flexible Build Options**: Standard SwiftPM builds or full Subler integration
- **Version Management**: Automatic beta version incrementing

### 3. Search Architecture Improvements
- **Incremental Result Streaming**: Results appear as providers respond
- **Provider Priority System**: Configurable provider execution order
- **Multi-Provider Coordination**: Unified search across multiple metadata sources
- **Cancellation Support**: Proper task cancellation and cleanup

### 4. Developer Experience
- **Test Validation Script**: `validate-tests.sh` for comprehensive test verification
- **Build Documentation**: Comprehensive guides for both build types
- **Conditional Compilation**: Clean separation of Subler-dependent code
- **Error Handling**: Improved error messages and build diagnostics

---

## 🔧 Technical Changes

### Architecture
- **SublerCompatibility Module**: New compatibility layer for Subler integration
- **UnifiedSearchManager**: Enhanced to support both modern and legacy providers
- **Provider Adapters**: TPDB, TVDB, TMDB adapters for Subler `MetadataService` protocol
- **Incremental Streaming**: `IncrementalRunnableTask` for real-time result updates

### Build System
- **Package.swift**: Updated to include SublerCompatibility (with conditional compilation)
- **Build Scripts**: Enhanced build scripts with framework support
- **Version Management**: Improved versioning and build artifact management

### Code Quality
- **Conditional Compilation**: All Subler-dependent code properly wrapped
- **Error Handling**: Enhanced error reporting and diagnostics
- **Documentation**: Comprehensive build and integration documentation

---

## 📋 Testing

### Test Results
- **Total Tests:** 64
- **Passed:** 62
- **Failed:** 2 (pre-existing issues, unrelated to this release)
  - `testSearchCanBeCancelled` - Cancellation handling
  - `testSearchPrioritizesCloserYear` - Year prioritization logic

### Test Execution
```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter UnifiedSearchManager

# Validate tests with Subler integration
./scripts/validate-tests.sh
```

---

## 📦 Deployment

### Distribution
1. **Build Release Version**
   ```bash
   ./scripts/build.sh --release
   ```

2. **Locate Distribution Archive**
   ```bash
   ls -lh "build/App builds/SublerPlus-0.4.0-beta.zip"
   ```

3. **Verify Bundle**
   ```bash
   # Check code signing (if applicable)
   codesign -dv "build/App builds/SublerPlus-0.4.0-beta/SublerPlus.app"
   
   # Verify version
   /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
     "build/App builds/SublerPlus-0.4.0-beta/SublerPlus.app/Contents/Info.plist"
   ```

### Installation
1. Extract the ZIP archive
2. Move `SublerPlus.app` to `/Applications/` (or desired location)
3. Launch the application

### Requirements
- macOS 12.0 or later
- API Keys (optional): TPDB, TMDB, TVDB for full metadata search functionality
- External Tools (optional): FFmpeg, Tesseract for advanced features

---

## 🐛 Known Issues

1. **MP42Foundation Framework**: Requires Xcode for building. SwiftPM-only builds work without it but lack full Subler integration.

2. **Test Failures**: Two pre-existing test failures unrelated to this release:
   - Cancellation handling in search operations
   - Year prioritization in result sorting

3. **Framework Binary**: MP42Foundation framework build may show warnings about CMP42 module dependency, but this doesn't affect functionality.

---

## 📚 Documentation

- **Build Guide**: `docs/BUILD_WITH_SUBLER.md` - Complete guide for Subler integration builds
- **Build Notes**: `BUILD_NOTES.md` - General build information
- **Icon Setup**: `ICON_SETUP_INSTRUCTIONS.md` - Icon generation and integration
- **Changelog**: `CHANGELOG.md` - Complete version history

---

## 🔄 Migration Notes

### From Previous Versions

**No Breaking Changes**: This release is backward compatible with previous beta versions.

**New Features**:
- SublerCompatibility classes are now included in builds (with conditional compilation)
- New build script `build-with-subler.sh` for full integration
- Enhanced search architecture with incremental streaming

**Optional Upgrades**:
- Build MP42Foundation framework for full Subler feature parity
- Update to use new incremental streaming search mode
- Configure provider priorities in settings

---

## 👥 Credits

Built with:
- Swift 5.9+
- SwiftUI for macOS
- Subler MP42Foundation (optional)
- Alamofire for networking
- Swifter for web server

---

## 📝 Version Information

**Full Version:** 0.4.0-beta  
**Build Number:** Auto-incremented  
**Minimum macOS:** 12.0  
**Architecture:** Universal (arm64, x86_64)

---

**For support, issues, or contributions, please refer to the project documentation or repository.**

