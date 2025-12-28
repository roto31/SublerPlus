#!/bin/bash
set -euo pipefail

# Creates an XCFramework from MP42Foundation for SwiftPM use
# This is called automatically by build-with-subler.sh

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MP42_PROJECT="$PROJECT_ROOT/Subler/MP42Foundation/MP42Foundation.xcodeproj"
MP42_SCHEME="MP42Foundation"
BUILD_DIR="$PROJECT_ROOT/build/MP42Foundation"
XCFRAMEWORK_DIR="$PROJECT_ROOT/Frameworks"
XCFRAMEWORK="$XCFRAMEWORK_DIR/MP42Foundation.xcframework"

echo "📦 Creating MP42Foundation XCFramework..."

# Clean previous builds
rm -rf "$BUILD_DIR"
rm -rf "$XCFRAMEWORK"

mkdir -p "$BUILD_DIR"
mkdir -p "$XCFRAMEWORK_DIR"

# Build for both architectures (if needed)
# For now, just build for current architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    ARCHS="arm64"
    SDK="macosx"
elif [[ "$ARCH" == "x86_64" ]]; then
    ARCHS="x86_64"
    SDK="macosx"
else
    ARCHS="arm64 x86_64"
    SDK="macosx"
fi

echo "   Building for: $ARCHS"
echo "   SDK: $SDK"

# Build framework
xcodebuild build \
    -project "$MP42_PROJECT" \
    -scheme "$MP42_SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -arch "$ARCHS" \
    -sdk "$SDK" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Find built framework
FRAMEWORK_PATH=$(find "$BUILD_DIR" -name "MP42Foundation.framework" -type d | head -1)

if [[ -z "$FRAMEWORK_PATH" ]]; then
    echo "❌ ERROR: Framework not found after build"
    exit 1
fi

echo "✅ Framework built at: $FRAMEWORK_PATH"

# Create XCFramework
# For single architecture, we can still create an XCFramework
# or just use the framework directly

# For SwiftPM, we can use the framework directly if it's in the right place
# Or create a simple XCFramework structure

echo "   Creating XCFramework structure..."

# Create XCFramework directory structure
mkdir -p "$XCFRAMEWORK/macos-${ARCHS}/MP42Foundation.framework"

# Copy framework into XCFramework
cp -R "$FRAMEWORK_PATH" "$XCFRAMEWORK/macos-${ARCHS}/"

# Create Info.plist for XCFramework
cat > "$XCFRAMEWORK/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AvailableLibraries</key>
    <array>
        <dict>
            <key>LibraryIdentifier</key>
            <string>macos-${ARCHS}</string>
            <key>LibraryPath</key>
            <string>MP42Foundation.framework</string>
            <key>SupportedArchitectures</key>
            <array>
                <string>${ARCHS}</string>
            </array>
            <key>SupportedPlatform</key>
            <string>macos</string>
        </dict>
    </array>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
    <key>XCFrameworkFormatVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF

echo "✅ XCFramework created at: $XCFRAMEWORK"

