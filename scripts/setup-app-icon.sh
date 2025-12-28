#!/usr/bin/env bash
# Script to set up app icon from a source image and rebuild the app
# Usage: ./scripts/setup-app-icon.sh <source-image.png>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ICON_DIR="$PROJECT_DIR/App/Resources/AppIcon.appiconset"
SOURCE_IMAGE="${1:-}"

if [[ -z "$SOURCE_IMAGE" ]]; then
    echo "Usage: $0 <source-image.png>"
    echo ""
    echo "This script will:"
    echo "1. Generate all required icon sizes from your source image"
    echo "2. Place them in App/Resources/AppIcon.appiconset/"
    echo "3. Rebuild the application"
    echo ""
    echo "Source image should be:"
    echo "  - Square (1024x1024 recommended)"
    echo "  - PNG format"
    echo "  - High quality"
    exit 1
fi

# Resolve source image path
if [[ ! "$SOURCE_IMAGE" =~ ^/ ]]; then
    SOURCE_IMAGE="$(cd "$(dirname "$SOURCE_IMAGE")" && pwd)/$(basename "$SOURCE_IMAGE")"
fi

if [[ ! -f "$SOURCE_IMAGE" ]]; then
    echo "Error: Source image not found: $SOURCE_IMAGE" >&2
    exit 1
fi

if ! command -v sips &> /dev/null; then
    echo "Error: sips command not found (macOS built-in tool)" >&2
    exit 1
fi

echo "=========================================="
echo "Setting up App Icon"
echo "=========================================="
echo "Source image: $SOURCE_IMAGE"
echo "Output directory: $ICON_DIR"
echo ""

# Verify source image dimensions
echo "Checking source image..."
IMAGE_INFO=$(sips -g pixelWidth -g pixelHeight "$SOURCE_IMAGE" 2>/dev/null)
WIDTH=$(echo "$IMAGE_INFO" | grep "pixelWidth" | awk '{print $2}')
HEIGHT=$(echo "$IMAGE_INFO" | grep "pixelHeight" | awk '{print $2}')

if [[ -z "$WIDTH" ]] || [[ -z "$HEIGHT" ]]; then
    echo "Error: Could not read image dimensions" >&2
    exit 1
fi

echo "  Dimensions: ${WIDTH}x${HEIGHT}"

if [[ "$WIDTH" != "$HEIGHT" ]]; then
    echo "  Warning: Image is not square. It will be cropped to square."
fi

if [[ "$WIDTH" -lt 1024 ]]; then
    echo "  Warning: Image is smaller than 1024x1024. Quality may be reduced."
fi

# Create output directory
mkdir -p "$ICON_DIR"

# Generate all required icon sizes
echo ""
echo "Generating icon sizes..."

# 16x16 (1x)
sips -z 16 16 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_16x16.png" > /dev/null 2>&1
echo "  ✓ icon_16x16.png (16x16)"

# 16x16@2x (32x32)
sips -z 32 32 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_16x16@2x.png" > /dev/null 2>&1
echo "  ✓ icon_16x16@2x.png (32x32)"

# 32x32 (1x)
sips -z 32 32 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_32x32.png" > /dev/null 2>&1
echo "  ✓ icon_32x32.png (32x32)"

# 32x32@2x (64x64)
sips -z 64 64 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_32x32@2x.png" > /dev/null 2>&1
echo "  ✓ icon_32x32@2x.png (64x64)"

# 128x128 (1x)
sips -z 128 128 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_128x128.png" > /dev/null 2>&1
echo "  ✓ icon_128x128.png (128x128)"

# 128x128@2x (256x256)
sips -z 256 256 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_128x128@2x.png" > /dev/null 2>&1
echo "  ✓ icon_128x128@2x.png (256x256)"

# 256x256 (1x)
sips -z 256 256 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_256x256.png" > /dev/null 2>&1
echo "  ✓ icon_256x256.png (256x256)"

# 256x256@2x (512x512)
sips -z 512 512 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_256x256@2x.png" > /dev/null 2>&1
echo "  ✓ icon_256x256@2x.png (512x512)"

# 512x512 (1x)
sips -z 512 512 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_512x512.png" > /dev/null 2>&1
echo "  ✓ icon_512x512.png (512x512)"

# 512x512@2x (1024x1024)
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$ICON_DIR/icon_512x512@2x.png" > /dev/null 2>&1
echo "  ✓ icon_512x512@2x.png (1024x1024)"

# Ensure Contents.json exists and is correct
cat > "$ICON_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo ""
echo "✓ All icon files generated successfully!"
echo ""

# Rebuild the app
echo "=========================================="
echo "Rebuilding Application"
echo "=========================================="
cd "$PROJECT_DIR"

if [[ -f "scripts/build.sh" ]]; then
    echo "Running build script..."
    ./scripts/build.sh
else
    echo "Build script not found. Building with xcodebuild..."
    if [[ -f "SublerPlus.xcodeproj/project.pbxproj" ]]; then
        xcodebuild -project SublerPlus.xcodeproj -scheme SublerPlus -configuration Release build
    elif [[ -f "Package.swift" ]]; then
        swift build -c release
    else
        echo "Error: Could not find project file" >&2
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "✓ Icon setup and build complete!"
echo "=========================================="
echo ""
echo "The app icon has been set up and the application has been rebuilt."
echo "You can find the built app in the build directory."

