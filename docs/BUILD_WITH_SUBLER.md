# Building SublerPlus with Full Subler Integration

This document explains how to build SublerPlus with full Subler integration, including the `MP42Foundation` framework and `SublerCompatibility` classes.

## Overview

SublerPlus can be built in two ways:

1. **Standard SwiftPM Build** (without Subler integration)
   - Uses modern `MetadataProvider` protocol only
   - `SublerCompatibility` classes are excluded
   - Works out of the box with `swift build`

2. **Full Subler Integration Build** (with MP42Foundation)
   - Includes `SublerCompatibility` classes
   - Uses Subler's `MetadataService` protocol
   - Requires building `MP42Foundation` framework first
   - Provides full compatibility with Subler's search architecture

## Quick Start

To build with full Subler integration:

```bash
./scripts/build-with-subler.sh
```

For a release build:

```bash
./scripts/build-with-subler.sh --release
```

## How It Works

### Step 1: Build MP42Foundation Framework

The script builds the `MP42Foundation` framework from the Subler Xcode project:

```bash
xcodebuild build \
    -project "Subler/MP42Foundation/MP42Foundation.xcodeproj" \
    -scheme "MP42Foundation" \
    -configuration Release
```

The framework is placed in `Frameworks/MP42Foundation.framework/`.

### Step 2: Include SublerCompatibility Classes

`Package.swift` no longer excludes `SublerCompatibility` classes. These files use conditional compilation:

```swift
#if canImport(MP42Foundation)
import MP42Foundation
// SublerCompatibility code
#endif
```

This means:
- **With MP42Foundation**: All SublerCompatibility classes are compiled and available
- **Without MP42Foundation**: These classes are skipped (graceful degradation)

### Step 3: Build SublerPlus

The script builds SublerPlus using SwiftPM with framework linking flags:

```bash
swift build \
    -Xswiftc -F \
    -Xswiftc "Frameworks" \
    -Xlinker -F \
    -Xlinker "Frameworks" \
    -Xlinker -framework \
    -Xlinker MP42Foundation
```

## Build Script Options

```bash
./scripts/build-with-subler.sh [options]
```

Options:
- `--release`: Build in release mode (default: debug)
- `--skip-tests`: Skip running tests
- `--skip-mp42`: Skip MP42Foundation build (use existing framework)
- `-h, --help`: Show help message

## Directory Structure

After building, you'll have:

```
SublerPlus/
├── Frameworks/
│   └── MP42Foundation.framework/    # Built framework
├── build/
│   ├── MP42Foundation/              # Xcode build artifacts
│   └── ...                          # SwiftPM build artifacts
└── App/
    └── Controllers/
        └── SublerCompatibility/     # Now included in builds
```

## Troubleshooting

### Framework Not Found

If you see errors about `MP42Foundation` not being found:

1. Ensure the framework was built successfully:
   ```bash
   ls -la Frameworks/MP42Foundation.framework
   ```

2. Rebuild the framework:
   ```bash
   ./scripts/build-with-subler.sh --skip-mp42  # Remove this flag to rebuild
   ```

### Compilation Errors in SublerCompatibility

If `SublerCompatibility` files fail to compile:

1. Check that `MP42Foundation` framework exists
2. Verify the framework structure:
   ```bash
   file Frameworks/MP42Foundation.framework/MP42Foundation
   ```

3. The framework should contain a binary (not just headers)

### Linker Errors

If you see linker errors:

1. Ensure framework search paths are set correctly
2. Check that the framework binary is present
3. Try rebuilding from scratch:
   ```bash
   rm -rf Frameworks/ build/
   ./scripts/build-with-subler.sh
   ```

## Integration with CI/CD

For continuous integration, you can use:

```bash
# Build MP42Foundation once
./scripts/build-with-subler.sh --release --skip-tests

# In subsequent builds, skip MP42Foundation build
./scripts/build-with-subler.sh --skip-mp42
```

## Differences from Standard Build

| Feature | Standard Build | With Subler Integration |
|---------|---------------|---------------------------|
| SublerCompatibility | ❌ Excluded | ✅ Included |
| MP42Foundation | ❌ Not available | ✅ Available |
| Subler Search Architecture | ❌ Not available | ✅ Full support |
| Incremental Streaming | ❌ Limited | ✅ Full support |
| Provider Priorities | ✅ Available | ✅ Available |

## Code Usage

In your code, use conditional compilation to handle both cases:

```swift
#if canImport(MP42Foundation)
import MP42Foundation

// Use SublerCompatibility classes
let adapter = SublerMetadataServiceAdapter(provider: myProvider)
#else
// Fallback to modern providers only
#endif
```

## Notes

- The `Frameworks/` directory is git-ignored (contains built artifacts)
- MP42Foundation requires Xcode to build (uses `xcodebuild`)
- The framework is architecture-specific (arm64 or x86_64)
- For universal binaries, you may need to build for both architectures

## See Also

- [BUILD_NOTES.md](../BUILD_NOTES.md) - General build information
- [SEARCH_ARCHITECTURE_TESTING.md](SEARCH_ARCHITECTURE_TESTING.md) - Search architecture details

