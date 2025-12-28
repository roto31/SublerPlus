#!/bin/bash

# Build script for Prompt Generator macOS App
# This script helps build the app using Xcode command line tools

set -e

echo "🔨 Building Prompt Generator..."
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: xcodebuild not found. Please install Xcode."
    exit 1
fi

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_PATH="$SCRIPT_DIR/PromptGenerator.xcodeproj"

# Check if project exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Error: Xcode project not found at $PROJECT_PATH"
    exit 1
fi

# Build the project
echo "📦 Building project..."
xcodebuild -project "$PROJECT_PATH" \
    -scheme PromptGenerator \
    -configuration Release \
    -derivedDataPath "$SCRIPT_DIR/build" \
    clean build

echo ""
echo "✅ Build complete!"
echo ""
echo "📱 To run the app:"
echo "   open $SCRIPT_DIR/build/Build/Products/Release/PromptGenerator.app"
echo ""
echo "Or open the project in Xcode and press ⌘R"

