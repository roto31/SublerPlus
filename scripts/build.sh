#!/usr/bin/env bash
set -euo pipefail

# Build and test SublerPlus from Terminal (no Xcode needed).
# Usage:
#   ./scripts/build.sh            # debug build + tests
#   ./scripts/build.sh --release  # release build + tests
#   ./scripts/build.sh --security # run security lane (warnings-as-errors + filtered tests)
#   ./scripts/build.sh --skip-tests
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
  echo "==> Packaging app bundle (SublerPlus.app)"
  bundle_dir="build/SublerPlus.app"
  build_root="build/App builds"
  version_stamp="$(date +%Y%m%d-%H%M%S)"
  version_dir="$build_root/$version_stamp"

  mkdir -p "$bundle_dir/Contents/MacOS"
  mkdir -p "$bundle_dir/Contents/Resources"
  cat > "$bundle_dir/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>SublerPlus</string>
  <key>CFBundleIdentifier</key><string>com.sublerplus.app</string>
  <key>CFBundleVersion</key><string>1.0.0</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleExecutable</key><string>SublerPlusApp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF
  cp .build/release/SublerPlusApp "$bundle_dir/Contents/MacOS/SublerPlusApp"
  chmod +x "$bundle_dir/Contents/MacOS/SublerPlusApp"
  echo "Bundle created at $bundle_dir (launchable from Finder)"

  # Archive this build for historical reference
  mkdir -p "$version_dir"
  rsync -a "$bundle_dir"/ "$version_dir/SublerPlus.app"/
  echo "Archived build at $version_dir/SublerPlus.app"
fi

echo "Done."

