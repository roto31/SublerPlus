#!/usr/bin/env bash
set -euo pipefail

# Generate placeholder app icons for SublerPlus
# Creates all required icon sizes from a simple placeholder design

ICON_DIR="App/Resources/AppIcon.appiconset"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "==> Generating placeholder app icons"

# Create a simple 1024x1024 blue square placeholder
# We'll use a minimal PNG and scale it, or create via other means

# Method 1: Try to use an existing system icon as base (simplest)
# Method 2: Create a minimal PNG programmatically
# Method 3: Use sips to create from color (if supported)

# Create a minimal 1x1 blue PNG using hex data
# This is a valid 1x1 blue PNG file
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\tpHYs\x00\x00\x0b\x13\x00\x00\x0b\x13\x01\x00\x9a\x9c\x18\x00\x00\x00\nIDATx\x9cc\xf8\x0f\x00\x00\x01\x00\x01\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$TEMP_DIR/minimal.png"

# Scale up to 1024x1024 using sips
if ! sips -z 1024 1024 "$TEMP_DIR/minimal.png" --out "$TEMP_DIR/source.png" > /dev/null 2>&1; then
    # Alternative: Try using a system icon as template
    # Use App Store icon or create via different method
    if [[ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" ]]; then
        # Extract largest size from system icon
        iconutil -c iconset "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" -o "$TEMP_DIR/system_iconset" 2>/dev/null || true
        if [[ -f "$TEMP_DIR/system_iconset/icon_512x512@2x.png" ]]; then
            cp "$TEMP_DIR/system_iconset/icon_512x512@2x.png" "$TEMP_DIR/source.png"
        fi
    fi
    
    # If still no source, create a simple approach using sips with an existing image
    if [[ ! -f "$TEMP_DIR/source.png" ]]; then
        echo "Creating source image using alternative method..."
        # Create via sips by copying and scaling a known image
        # Use a simple workaround: create a blue square using sips format conversion
        # We'll create a data URI approach or use a different method
        # For now, let's try creating a simple colored image using sips
        # Create a temporary image file with specific color
        # Since sips can't create from scratch, we'll use a workaround
        
        # Create a 1x1 image and repeatedly scale it
        sips -z 2 2 "$TEMP_DIR/minimal.png" --out "$TEMP_DIR/temp2.png" > /dev/null 2>&1
        sips -z 4 4 "$TEMP_DIR/temp2.png" --out "$TEMP_DIR/temp4.png" > /dev/null 2>&1
        sips -z 8 8 "$TEMP_DIR/temp4.png" --out "$TEMP_DIR/temp8.png" > /dev/null 2>&1
        sips -z 16 16 "$TEMP_DIR/temp8.png" --out "$TEMP_DIR/temp16.png" > /dev/null 2>&1
        sips -z 32 32 "$TEMP_DIR/temp16.png" --out "$TEMP_DIR/temp32.png" > /dev/null 2>&1
        sips -z 64 64 "$TEMP_DIR/temp32.png" --out "$TEMP_DIR/temp64.png" > /dev/null 2>&1
        sips -z 128 128 "$TEMP_DIR/temp64.png" --out "$TEMP_DIR/temp128.png" > /dev/null 2>&1
        sips -z 256 256 "$TEMP_DIR/temp128.png" --out "$TEMP_DIR/temp256.png" > /dev/null 2>&1
        sips -z 512 512 "$TEMP_DIR/temp256.png" --out "$TEMP_DIR/temp512.png" > /dev/null 2>&1
        sips -z 1024 1024 "$TEMP_DIR/temp512.png" --out "$TEMP_DIR/source.png" > /dev/null 2>&1
    fi
fi

# Verify source image was created
if [[ ! -f "$TEMP_DIR/source.png" ]]; then
    echo "Error: Failed to create source image"
    echo "Please install ImageMagick for better icon generation: brew install imagemagick"
    exit 1
fi

# Ensure icon directory exists
mkdir -p "$ICON_DIR"

# Generate all required icon sizes using sips
echo "==> Creating icon sizes..."

sips -z 16 16 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_16x16.png" > /dev/null 2>&1
sips -z 32 32 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 32 32 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_32x32.png" > /dev/null 2>&1
sips -z 64 64 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 128 128 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_128x128.png" > /dev/null 2>&1
sips -z 256 256 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_256x256.png" > /dev/null 2>&1
sips -z 512 512 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_512x512.png" > /dev/null 2>&1
sips -z 1024 1024 "$TEMP_DIR/source.png" --out "$ICON_DIR/icon_512x512@2x.png" > /dev/null 2>&1

# Verify all icons were created
missing=0
for icon in icon_16x16.png icon_16x16@2x.png icon_32x32.png icon_32x32@2x.png \
            icon_128x128.png icon_128x128@2x.png icon_256x256.png icon_256x256@2x.png \
            icon_512x512.png icon_512x512@2x.png; do
    if [[ ! -f "$ICON_DIR/$icon" ]]; then
        echo "Error: Missing icon: $icon"
        missing=1
    fi
done

if [[ $missing -eq 1 ]]; then
    echo "Error: Some icons failed to generate"
    exit 1
fi

echo "✅ All 10 icon files created successfully"

# Test iconutil generation
echo "==> Testing .icns file generation..."
if iconutil -c icns "$ICON_DIR" -o "$ICON_DIR/../AppIcon.icns" 2>/dev/null; then
    echo "✅ .icns file generated successfully"
    rm -f "$ICON_DIR/../AppIcon.icns"  # Remove test file, build script will generate it
else
    echo "⚠️  Warning: iconutil test failed (may need to check icon files)"
fi

echo "==> Done! Icons ready in $ICON_DIR"
