# SublerPlus User Guide

## Install & Run
1) Ensure macOS 12+ with Swift toolchain.
2) Set API keys:
   - In-app Settings (Keychain) for TPDB/TMDB/TVDB, or
   - Env vars before launch: `TPDB_API_KEY`, `TMDB_API_KEY`, `TVDB_API_KEY`.
3) `swift build` then run `SublerPlusApp` (or `sublerplus-cli` for CLI).

## Main App
- Add files: Toolbar “Add Files” or drag-drop into File list.
- Enrich: Select a file → “Enrich” (⌘E). Batch queue auto-enriches added files.
- Adult metadata: toggle in Settings.
- Ambiguous matches: a sheet lists candidates (title/year/studio/score). Pick one; choice is remembered for future runs.
- Jobs: Jobs section shows queued/running/succeeded/failed; failed jobs offer Retry.
- Activity: Live status lines; concise status label above.
- Web UI: Sidebar “Web UI” opens embedded dashboard (localhost only).

## CLI
`sublerplus-cli /path/to/file.mp4`  
Uses same providers and pipeline; ambiguous items are deferred for later resolution in the app.

## Settings
- Toggle adult lookups, adjust TPDB confidence (if exposed), manage API keys (Keychain).
- Clear ambiguity cache if needed (Settings control).

## Folder Monitoring
- Add a folder (if configured) to auto-enqueue new media into the JobQueue with bounded concurrency and retries.

## Shortcuts
- Add Files ⌘N, Enrich ⌘E, Search ⌘F, Refresh Status ⌘R, Settings ⌘,.

## Accessibility & HIG
- Sidebar/navigation labels and hints.
- Toolbar and drop targets labeled with hints; ambiguity sheet accessible.
- Respects Reduce Motion/Transparency via SwiftUI environment.

