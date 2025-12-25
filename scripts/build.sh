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
endwhile

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

echo "Done."

