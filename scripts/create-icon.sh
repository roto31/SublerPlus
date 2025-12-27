#!/usr/bin/env bash
# Helper script to create app icons from a source image
# Usage: ./scripts/create-icon.sh <source-image.png> [output-dir]

set -euo pipefail

SOURCE_IMAGE="${1:-}"
OUTPUT_DIR="${2:-App/Resources/AppIcon.appiconset}"

if [[ -z "$SOURCE_IMAGE" ]]; then
    echo "Usage: $0 <source-image.png> [output-dir]"
    echo ""
    echo "Creates all required icon sizes from a source image (1024x1024 recommended)"
    exit 1
fi

if [[ ! -f "$SOURCE_IMAGE" ]]; then
    echo "Error: Source image not found: $SOURCE_IMAGE" >&2
    exit 1
fi

if ! command -v sips &> /dev/null; then
    echo "Error: sips command not found (macOS built-in tool)" >&2
    exit 1
fi

echo "Creating app icons from: $SOURCE_IMAGE"
echo "Output directory: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# Create all required sizes
echo "Generating icon sizes..."
sips -z 16 16 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_16x16.png" > /dev/null
sips -z 32 32 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_16x16@2x.png" > /dev/null
sips -z 32 32 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_32x32.png" > /dev/null
sips -z 64 64 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_32x32@2x.png" > /dev/null
sips -z 128 128 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_128x128.png" > /dev/null
sips -z 256 256 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_256x256.png" > /dev/null
sips -z 512 512 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_512x512@2x.png" > /dev/null

echo "✓ Icons created successfully in $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Review the generated icons"
echo "2. Run: ./scripts/build.sh --release"
echo "3. The build script will automatically integrate the icons"

