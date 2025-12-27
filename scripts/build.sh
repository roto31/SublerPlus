#!/usr/bin/env bash
set -euo pipefail

# Build and test SublerPlus from Terminal (no Xcode needed).
# Usage:
#   ./scripts/build.sh            # debug build + tests
#   ./scripts/build.sh --release  # release build + tests
#   ./scripts/build.sh --security # run security lane (warnings-as-errors + filtered tests)
#   ./scripts/build.sh --skip-tests
#
# Versioning (semantic versioning):
#   BASE_VERSION     Base version (default: 0.3.0)
#   PRERELEASE       Prerelease tag (default: beta)
#   VERSION          Full version override (e.g., 0.3.0-beta1, 1.0.0)
#                     If not set, auto-increments beta number
#   Examples:
#     BASE_VERSION=0.3.0 PRERELEASE=beta ./scripts/build.sh --release
#     VERSION=1.0.0 ./scripts/build.sh --release
#
# Env (optional):
#   WEBUI_TOKEN      Optional token for WebUI auth
#   TPDB_API_KEY     ThePornDB key
#   TMDB_API_KEY     TMDB key
#   TVDB_API_KEY     TVDB key
#
# Notes:
# - Uses SwiftPM; no Xcode project required.
# - Security lane runs: swift build -Xswiftc -warnings-as-errors; swift test --filter Security

mode="debug"
run_tests=1
security=0
# Semantic versioning: MAJOR.MINOR.PATCH[-PRERELEASE]
# Examples: 0.2.0-beta1, 0.2.0-beta2, 1.0.0
BASE_VERSION="${BASE_VERSION:-0.3.0}"
PRERELEASE="${PRERELEASE:-beta}"
PRUNE_BUILDS_DAYS="${PRUNE_BUILDS_DAYS:-7}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) mode="release" ;;
    --skip-tests) run_tests=0 ;;
    --security) security=1 ;;
    -h|--help)
      echo "Usage: $0 [--release] [--skip-tests] [--security]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

echo "==> Building (mode: $mode)"
if [[ "$mode" == "release" ]]; then
  swift build -c release
else
  swift build
fi

if [[ "$run_tests" == "1" ]]; then
  if [[ "$security" == "1" ]]; then
    echo "==> Security build (warnings as errors)"
    swift build -Xswiftc -warnings-as-errors
    echo "==> Security tests"
    swift test --filter Security
  else
    echo "==> Running tests"
    swift test
  fi
else
  echo "==> Tests skipped"
fi

if [[ "$mode" == "release" ]]; then
  # Auto-increment beta number if VERSION not explicitly set
  if [[ -z "${VERSION:-}" ]]; then
    build_root="build/App builds"
    mkdir -p "$build_root"
    
    # Find highest existing patch version for 0.2.xb schema
    # Schema: 0.2.0b, 0.2.1b, 0.2.2b, etc. (patch number = beta number)
    highest_patch=-1
    major_minor="${BASE_VERSION%.*}"  # e.g., "0.2"
    
    # Check for format: 0.2.Xb (e.g., 0.2.0b, 0.2.1b, 0.2.2b)
    for dir in "$build_root"/SublerPlus-${major_minor}.*b*; do
      if [[ -d "$dir" ]]; then
        # Extract patch number from version like SublerPlus-0.2.3b -> 3
        basename_dir=$(basename "$dir")
        if [[ "$basename_dir" =~ SublerPlus-${major_minor}\.([0-9]+)b ]]; then
          patch="${BASH_REMATCH[1]}"
          if [[ "$patch" =~ ^[0-9]+$ ]] && [[ "$patch" -gt "$highest_patch" ]]; then
            highest_patch=$patch
          fi
        fi
      fi
    done
    
    # Check for legacy format: BASE_VERSION-betaN (e.g., 0.2.0-beta1)
    if ls "$build_root"/SublerPlus-${BASE_VERSION}-${PRERELEASE}* 2>/dev/null | grep -q .; then
      for dir in "$build_root"/SublerPlus-${BASE_VERSION}-${PRERELEASE}*; do
        if [[ -d "$dir" ]]; then
          beta_num=$(basename "$dir" | sed "s/SublerPlus-${BASE_VERSION}-${PRERELEASE}//" | sed 's/\/$//')
          if [[ "$beta_num" =~ ^[0-9]+$ ]] && [[ "$beta_num" -gt "$highest_patch" ]]; then
            highest_patch=$beta_num
          fi
        fi
      done
    fi
    
    # Increment patch version (start from 0 if no builds found)
    next_patch=$((highest_patch + 1))
    VERSION="${major_minor}.${next_patch}b"
  fi
  
  echo "==> Packaging app bundle (SublerPlus.app)"
  echo "==> Version: ${VERSION}"
  bundle_dir="build/SublerPlus.app"
  build_root="build/App builds"
  version_dir="$build_root/SublerPlus-$VERSION"

  mkdir -p "$bundle_dir/Contents/MacOS"
  mkdir -p "$bundle_dir/Contents/Resources"
  
  # Copy icon resources if they exist
  icon_source="App/Resources/AppIcon.appiconset"
  if [[ -d "$icon_source" ]]; then
    echo "==> Copying app icon resources"
    cp -R "$icon_source" "$bundle_dir/Contents/Resources/"
    
    # Generate .icns file if iconutil is available
    if command -v iconutil &> /dev/null; then
      echo "==> Generating .icns file"
      iconutil -c icns "$icon_source" -o "$bundle_dir/Contents/Resources/AppIcon.icns" 2>/dev/null || {
        echo "Warning: Could not generate .icns file (iconutil failed or icons incomplete)"
      }
    fi
  else
    echo "Warning: App icon resources not found at $icon_source"
  fi
  
  # Determine icon file reference
  icon_file=""
  if [[ -f "$bundle_dir/Contents/Resources/AppIcon.icns" ]]; then
    icon_file="AppIcon.icns"
  elif [[ -d "$bundle_dir/Contents/Resources/AppIcon.appiconset" ]]; then
    icon_file="AppIcon"
  fi
  
  cat > "$bundle_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>SublerPlus</string>
  <key>CFBundleIdentifier</key><string>com.sublerplus.app</string>
  <key>CFBundleVersion</key><string>{{VERSION}}</string>
  <key>CFBundleShortVersionString</key><string>{{VERSION}}</string>
  <key>CFBundleExecutable</key><string>SublerPlusApp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
EOF

  if [[ -n "$icon_file" ]]; then
    cat >> "$bundle_dir/Contents/Info.plist" <<EOF
  <key>CFBundleIconFile</key><string>$icon_file</string>
EOF
  fi
  
  # AppleScript support
  cat >> "$bundle_dir/Contents/Info.plist" <<EOF
  <key>NSAppleScriptEnabled</key><true/>
  <key>OSAScriptingDefinition</key><string>SublerPlus.sdef</string>
EOF
  
  cat >> "$bundle_dir/Contents/Info.plist" <<EOF
</dict>
</plist>
EOF
  sed -i '' "s/{{VERSION}}/$VERSION/g" "$bundle_dir/Contents/Info.plist"
  cp .build/release/SublerPlusApp "$bundle_dir/Contents/MacOS/SublerPlusApp"
  chmod +x "$bundle_dir/Contents/MacOS/SublerPlusApp"
  
  # Copy entitlements file for App Sandbox
  if [[ -f "App/SublerPlus.entitlements" ]]; then
    cp "App/SublerPlus.entitlements" "$bundle_dir/Contents/SublerPlus.entitlements"
    echo "Entitlements file copied"
  fi
  
  # Copy AppleScript dictionary (.sdef file)
  if [[ -f "Resources/SublerPlus.sdef" ]]; then
    cp "Resources/SublerPlus.sdef" "$bundle_dir/Contents/Resources/SublerPlus.sdef"
    echo "AppleScript dictionary copied"
  fi
  
  # Code sign with entitlements (if codesign is available)
  if command -v codesign &> /dev/null; then
    if [[ -f "$bundle_dir/Contents/SublerPlus.entitlements" ]]; then
      echo "==> Code signing with entitlements"
      codesign --force --deep --sign - --entitlements "$bundle_dir/Contents/SublerPlus.entitlements" "$bundle_dir" 2>/dev/null || {
        echo "Warning: Code signing failed (may need developer certificate). Continuing..."
      }
    else
      echo "Warning: Entitlements file not found. App Sandbox may not be enabled."
    fi
  else
    echo "Warning: codesign not available. App Sandbox entitlements will be applied at runtime if available."
  fi
  
  echo "Bundle created at $bundle_dir (launchable from Finder)"

  # Archive this build for historical reference
  # Directory and zip names use format: SublerPlus-MAJOR.MINOR.PATCH[-PRERELEASE]
  mkdir -p "$version_dir"
  cp -R "$bundle_dir" "$version_dir/SublerPlus.app"
  (cd "$build_root" && zip -qr "SublerPlus-$VERSION.zip" "SublerPlus-$VERSION/SublerPlus.app")
  echo "Archived build at $version_dir/SublerPlus.app (zip: $build_root/SublerPlus-$VERSION.zip)"
  echo "Version: $VERSION"

  # Optional pruning of old archives to limit disk usage
  if [[ "$PRUNE_BUILDS_DAYS" -gt 0 ]]; then
    echo "==> Pruning archives older than $PRUNE_BUILDS_DAYS days"
    find "$build_root" -maxdepth 1 -type d -name "SublerPlus-*" -mtime +"$PRUNE_BUILDS_DAYS" -print -exec rm -rf {} \;
    find "$build_root" -maxdepth 1 -type f -name "SublerPlus-*.zip" -mtime +"$PRUNE_BUILDS_DAYS" -print -exec rm -f {} \;
  fi
fi

echo "Done."

