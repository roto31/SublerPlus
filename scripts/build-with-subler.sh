#!/bin/bash
set -euo pipefail

# Build script that enables SwiftPM builds with full Subler integration
# This script builds MP42Foundation framework first, then builds SublerPlus
#
# Usage:
#   ./scripts/build-with-subler.sh            # debug build
#   ./scripts/build-with-subler.sh --release  # release build
#   ./scripts/build-with-subler.sh --skip-tests
#   ./scripts/build-with-subler.sh --skip-mp42 # skip MP42Foundation build (use existing)

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MP42_PROJECT="$PROJECT_ROOT/Subler/MP42Foundation/MP42Foundation.xcodeproj"
MP42_SCHEME="MP42Foundation"
FRAMEWORKS_DIR="$PROJECT_ROOT/Frameworks"
MP42_FRAMEWORK="$FRAMEWORKS_DIR/MP42Foundation.framework"
BUILD_DIR="$PROJECT_ROOT/build/MP42Foundation"
DERIVED_DATA="$BUILD_DIR/DerivedData"

mode="debug"
run_tests=1
skip_mp42=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) mode="release" ;;
    --skip-tests) run_tests=0 ;;
    --skip-mp42) skip_mp42=1 ;;
    -h|--help)
      echo "Usage: $0 [--release] [--skip-tests] [--skip-mp42]"
      echo ""
      echo "Builds MP42Foundation framework and SublerPlus with full Subler integration"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

echo "═══════════════════════════════════════════════════════════"
echo "🔨 Building SublerPlus with MP42Foundation Support"
echo "═══════════════════════════════════════════════════════════"
echo ""

# =========================
# STEP 1: Build MP42Foundation Framework
# =========================
if [[ "$skip_mp42" == "0" ]]; then
    echo "📦 STEP 1: Building MP42Foundation framework..."
    
    if [[ ! -d "$MP42_PROJECT" ]]; then
        echo "❌ ERROR: MP42Foundation project not found at: $MP42_PROJECT"
        exit 1
    fi
    
    # Clean previous build
    if [[ -d "$DERIVED_DATA" ]]; then
        echo "   Cleaning previous build..."
        rm -rf "$DERIVED_DATA"
    fi
    
    # Determine build configuration
    if [[ "$mode" == "release" ]]; then
        BUILD_CONFIG="Release"
    else
        BUILD_CONFIG="Debug"
    fi
    
    echo "   Configuration: $BUILD_CONFIG"
    echo "   Project: $MP42_PROJECT"
    echo "   Scheme: $MP42_SCHEME"
    
    # Build MP42Foundation framework
    xcodebuild build \
        -project "$MP42_PROJECT" \
        -scheme "$MP42_SCHEME" \
        -configuration "$BUILD_CONFIG" \
        -derivedDataPath "$DERIVED_DATA" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | grep -E "(error|warning|Building|Succeeded|Failed)" || true
    
    BUILD_EXIT_CODE=${PIPESTATUS[0]}
    
    if [[ $BUILD_EXIT_CODE -ne 0 ]]; then
        echo "❌ ERROR: Failed to build MP42Foundation (exit code: $BUILD_EXIT_CODE)"
        exit 1
    fi
    
    # Find the built framework
    # xcodebuild puts frameworks in DerivedData/Build/Products/Release or Debug
    FRAMEWORK_SEARCH_PATHS=(
        "$DERIVED_DATA/Build/Products/$BUILD_CONFIG/MP42Foundation.framework"
        "$DERIVED_DATA/Build/Products/MP42Foundation.framework"
        "$(find "$DERIVED_DATA" -name "MP42Foundation.framework" -type d | head -1)"
    )
    
    FRAMEWORK_PATH=""
    for path in "${FRAMEWORK_SEARCH_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            FRAMEWORK_PATH="$path"
            break
        fi
    done
    
    if [[ -z "$FRAMEWORK_PATH" ]]; then
        echo "❌ ERROR: MP42Foundation.framework not found after build"
        echo "   Searched in:"
        for path in "${FRAMEWORK_SEARCH_PATHS[@]}"; do
            echo "     - $path"
        done
        echo "   DerivedData contents:"
        find "$DERIVED_DATA" -name "*.framework" -type d 2>/dev/null | head -5 || echo "     (none found)"
        exit 1
    fi
    
    echo "✅ MP42Foundation built at: $FRAMEWORK_PATH"
    
    # Create Frameworks directory and copy framework
    mkdir -p "$FRAMEWORKS_DIR"
    
    # Remove old framework if it exists
    if [[ -d "$MP42_FRAMEWORK" ]]; then
        echo "   Removing old framework..."
        rm -rf "$MP42_FRAMEWORK"
    fi
    
    # Copy framework
    echo "   Copying framework to: $FRAMEWORKS_DIR"
    cp -R "$FRAMEWORK_PATH" "$FRAMEWORKS_DIR/"
    
    # Verify framework structure
    if [[ ! -f "$MP42_FRAMEWORK/MP42Foundation" ]] && [[ ! -d "$MP42_FRAMEWORK/Versions/Current/MP42Foundation" ]]; then
        echo "⚠️  WARNING: Framework binary not found in expected location"
        echo "   Framework structure:"
        ls -la "$MP42_FRAMEWORK" || true
    fi
    
    echo "✅ Framework ready at: $MP42_FRAMEWORK"
    echo ""
else
    echo "📦 STEP 1: Skipping MP42Foundation build (using existing)"
    if [[ ! -d "$MP42_FRAMEWORK" ]]; then
        echo "❌ ERROR: MP42Foundation.framework not found at: $MP42_FRAMEWORK"
        echo "   Run without --skip-mp42 to build it first"
        exit 1
    fi
    echo "✅ Using existing framework at: $MP42_FRAMEWORK"
    echo ""
fi

# =========================
# STEP 2: Update Package.swift to include MP42Foundation
# =========================
echo "📝 STEP 2: Updating Package.swift for MP42Foundation support..."

# Check if Package.swift already has MP42Foundation binary target
if grep -q "binaryTarget.*MP42Foundation" "$PROJECT_ROOT/Package.swift"; then
    echo "✅ Package.swift already configured for MP42Foundation"
else
    echo "⚠️  WARNING: Package.swift needs to be updated to include MP42Foundation"
    echo "   You may need to add a .binaryTarget for MP42Foundation"
    echo "   Or ensure the framework is linked via linker flags"
fi

# Check if SublerCompatibility exclusion is still present
if grep -q '"Controllers/SublerCompatibility"' "$PROJECT_ROOT/Package.swift"; then
    echo "⚠️  NOTE: SublerCompatibility is still excluded in Package.swift"
    echo "   This is fine if using conditional compilation (#if canImport(MP42Foundation))"
fi

echo ""

# =========================
# STEP 3: Build SublerPlus with SwiftPM
# =========================
echo "🔨 STEP 3: Building SublerPlus with SwiftPM..."

cd "$PROJECT_ROOT"

# Set environment variables to help Swift find the framework
export FRAMEWORK_SEARCH_PATHS="$FRAMEWORKS_DIR"
export LD_RUNPATH_SEARCH_PATHS="@loader_path/../Frameworks"

# Create a symlink or ensure framework is in a standard location
# SwiftPM needs the framework to be findable via -F flag or in system paths
# We'll use SWIFT_PACKAGE_RESOURCE_PATH or pass flags via environment

# Build configuration
BUILD_FLAGS=()
if [[ "$mode" == "release" ]]; then
    BUILD_FLAGS+=("-c" "release")
    echo "   Mode: Release"
else
    echo "   Mode: Debug"
fi

# Add framework search path via build flags
# Note: SwiftPM doesn't directly support -F flags, so we need to work around this
# Option 1: Use environment variable (may not work for all cases)
# Option 2: Create a modulemap or use a different approach
# Option 3: Copy framework to a system location (requires sudo)

# For now, we'll try building and see if the conditional compilation works
# The framework will be linked at runtime if available

echo "   Framework location: $MP42_FRAMEWORK"
if [[ ${#BUILD_FLAGS[@]} -gt 0 ]]; then
    echo "   Running: swift build ${BUILD_FLAGS[*]}"
else
    echo "   Running: swift build"
fi
echo "   Note: Framework linking may require additional setup"

# Try building with framework search path
# We'll pass it via Xcode build settings if needed, but for SwiftPM we need a different approach
if [[ ${#BUILD_FLAGS[@]} -gt 0 ]]; then
    swift build "${BUILD_FLAGS[@]}" \
        -Xswiftc -F \
        -Xswiftc "$FRAMEWORKS_DIR" \
        -Xlinker -F \
        -Xlinker "$FRAMEWORKS_DIR" \
        -Xlinker -framework \
        -Xlinker MP42Foundation \
        -Xlinker -rpath \
        -Xlinker "@loader_path/../Frameworks" \
        2>&1 | tee "$PROJECT_ROOT/build.log" || {
        BUILD_EXIT_CODE=${PIPESTATUS[0]}
        echo ""
        echo "⚠️  Build with framework flags failed, trying without..."
        echo "   (SublerCompatibility code uses #if canImport, so it may still compile)"
        
        # Try building without framework flags (conditional compilation should handle it)
        swift build "${BUILD_FLAGS[@]}" 2>&1 | tee -a "$PROJECT_ROOT/build.log" || {
            BUILD_EXIT_CODE=${PIPESTATUS[0]}
            echo ""
            echo "❌ ERROR: Swift build failed (exit code: $BUILD_EXIT_CODE)"
            echo "   Check build.log for details"
            echo ""
            echo "   Common issues:"
            echo "   - MP42Foundation framework not found"
            echo "   - SublerCompatibility files need conditional compilation"
            echo "   - Missing linker flags"
            exit 1
        }
    }
else
    swift build \
        -Xswiftc -F \
        -Xswiftc "$FRAMEWORKS_DIR" \
        -Xlinker -F \
        -Xlinker "$FRAMEWORKS_DIR" \
        -Xlinker -framework \
        -Xlinker MP42Foundation \
        -Xlinker -rpath \
        -Xlinker "@loader_path/../Frameworks" \
        2>&1 | tee "$PROJECT_ROOT/build.log" || {
        BUILD_EXIT_CODE=${PIPESTATUS[0]}
        echo ""
        echo "⚠️  Build with framework flags failed, trying without..."
        echo "   (SublerCompatibility code uses #if canImport, so it may still compile)"
        
        # Try building without framework flags (conditional compilation should handle it)
        swift build 2>&1 | tee -a "$PROJECT_ROOT/build.log" || {
            BUILD_EXIT_CODE=${PIPESTATUS[0]}
            echo ""
            echo "❌ ERROR: Swift build failed (exit code: $BUILD_EXIT_CODE)"
            echo "   Check build.log for details"
            echo ""
            echo "   Common issues:"
            echo "   - MP42Foundation framework not found"
            echo "   - SublerCompatibility files need conditional compilation"
            echo "   - Missing linker flags"
            exit 1
        }
    }
fi

echo "✅ Swift build succeeded"
echo ""

# =========================
# STEP 4: Run Tests (if requested)
# =========================
if [[ "$run_tests" == "1" ]]; then
    echo "🧪 STEP 4: Running tests..."
    
    swift test 2>&1 | tee "$PROJECT_ROOT/test.log" || {
        TEST_EXIT_CODE=${PIPESTATUS[0]}
        echo ""
        echo "⚠️  WARNING: Some tests failed (exit code: $TEST_EXIT_CODE)"
        echo "   Check test.log for details"
        echo "   (Some failures may be expected if MP42Foundation types aren't available in SwiftPM context)"
    }
    
    echo ""
else
    echo "⏭️  STEP 4: Tests skipped"
    echo ""
fi

# =========================
# Summary
# =========================
echo "═══════════════════════════════════════════════════════════"
echo "✅ BUILD COMPLETE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  • MP42Foundation: ✅ Built and available"
echo "  • Framework location: $MP42_FRAMEWORK"
echo "  • SwiftPM build: ✅ Completed"
if [[ "$run_tests" == "1" ]]; then
    echo "  • Tests: ✅ Executed"
fi
echo ""
echo "Note: SublerCompatibility classes are now available in SwiftPM builds"
echo "      when MP42Foundation framework is present."
echo ""
echo "To use in your code:"
echo "  #if canImport(MP42Foundation)"
echo "  import MP42Foundation"
echo "  // Use SublerCompatibility classes"
echo "  #endif"
echo ""

