# Troubleshooting

## WebUI not loading
- Ensure the app started the local server (Status pane should show start message).
- Confirm `http://127.0.0.1:8080` reachable; reload via WebUI header button.
- If token set, ensure `X-Auth-Token` saved in the WebUI token field.

## Metadata not applying
- Verify file extensions are mp4/m4v/mov.
- Check job list for failures; use “Retry” on failed jobs.
- For ambiguous matches, resolve in-app; cache remembers choices.

## Provider failures
- Inspect Console.app logs under subsystem `com.sublerplus.app` categories `network`/`providers`.
- Ensure TPDB/TMDB/TVDB keys are set in Settings; rotate keys if stale.
- Network retries and circuit breaker will pause after repeated 5xx/429.

## NFO/retained copies
- If NFO missing, confirm “Generate NFO sidecar” is enabled and target folder exists.
- If retaining originals, ensure output directory is set and writable.

## Build issues
- Use `./scripts/build-with-subler.sh --release` for release builds with MP42Foundation support
- Add `--skip-tests` to skip test execution
- Add `--skip-mp42` to skip MP42Foundation build (use existing framework)
- Prune old archives in `build/App builds/` to reclaim space
- If MCPServer build fails, ensure Swifter dependency is properly configured in Package.swift
# Troubleshooting

## Build Issues
- Swift errors about MP42: the project no longer depends on MP42; clean and rebuild. Ensure `swift-tools-version:5.9`.
- Missing API keys: set env vars or enter in Settings (Keychain).

## Metadata Not Updating
- Verify the file is writable (no sandbox/permissions).
- Check Activity/Jobs panes for provider errors.
- Ensure network access; TPDB/TMDB/TVDB require HTTPS.

## Ambiguous Matches Keep Deferring
- Open the ambiguity sheet and select a match; choice is cached by filename+studio+year.
- Clear cache in Settings if a wrong choice was cached.

## WebUI Not Loading
- Confirm server is running at http://127.0.0.1:8080.
- CORS locked to localhost; use the embedded WebView.
- Asset 404: ensure `WebUI/Assets` exists in bundle; rebuild.

## Provider Failures / Rate Limits
- TPDB/TVDB/TMDB have retry/backoff; repeated 429/5xx will surface in Activity.
- Double-check API keys are valid and not empty.

## Artwork Missing
- Some providers may not return artwork; or image exceeds cache size limit (5MB default).

## Accessibility Issues
- If VoiceOver doesn't announce elements properly, ensure you're using the latest version (0.4.2-beta+)
- Keyboard navigation: Use Tab to navigate between elements, arrow keys in lists
- Error dialogs: All errors are presented via ErrorPresenter with clear messages
- Form validation: Required fields show red borders when empty (e.g., Web UI Token)

## Menu Shortcuts Not Working
- Ensure you're using standard macOS shortcuts (⌘Q, ⌘W, ⌘,)
- Custom shortcuts may conflict with system shortcuts; check System Preferences > Keyboard > Shortcuts
- About window: Access via App menu > About SublerPlus

## Logging
- Structured logs available in Console.app under subsystem `com.sublerplus.app`.
- StatusStream shows recent events in Activity pane and WebUI `/api/status`.

## Security
- WebUI/API are localhost-only; optionally set `WEBUI_TOKEN` and restart.
- Avoid running on shared machines without the token; embedded WebView is preferred.
- If sandboxing, restrict network to provider domains and file access to user-selected paths.
- Never log or share API keys; logs are scrubbed but review Console.app before sharing.

