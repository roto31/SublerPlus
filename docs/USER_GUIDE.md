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
- Dependency checking: View status of external dependencies (FFmpeg, Tesseract) with visual indicators.

## Muxing & Presets
- **Presets**: Use built-in presets (Passthrough, Apple TV, iPhone, iPad, Audio Only, Audiobook) or create custom presets
- **Preset Import/Export**: Export presets to JSON/PLIST files or import from files
- **Track Selection**: Select specific tracks for muxing with conversion options
- **Audio Conversion**: Convert audio tracks to AAC or AC3 with configurable bitrate and mixdown
- **Subtitle Conversion**: Convert subtitles to TX3G format with styling options

## Queue Operations
- **Queue Statistics**: View real-time statistics including total processed, success/failure counts, average time, and estimated remaining
- **Queue Management**: Reorder items, edit job settings, bulk modify, duplicate jobs, filter by status/URL, and sort queue
- **Batch Actions**: Configure preferred audio/subtitle languages, fix fallbacks, set languages, clear track names, organize groups

## Folder Monitoring
- Add a folder (if configured) to auto-enqueue new media into the JobQueue with bounded concurrency and retries.

## Shortcuts
- **Standard macOS Shortcuts**:
  - ⌘Q: Quit
  - ⌘W: Close Window
  - ⌘, (comma): Preferences
- **Application Shortcuts**:
  - ⌘N: Add Files
  - ⌘E: Enrich Selected
  - ⌘F: Search
  - ⌘R: Refresh Status
  - ⌘⇧O: Open Web UI in Browser
  - ⌘M: Minimize Window

## Accessibility & HIG Compliance
- **Full VoiceOver Support**: All interactive elements have comprehensive accessibility labels, hints, and values
- **Keyboard Navigation**: All features accessible via keyboard with logical tab order
- **Dynamic Type**: Text scales with system preferences
- **High Contrast Mode**: Full support for accessibility display preferences
- **Reduce Motion/Transparency**: Respects system accessibility settings via SwiftUI environment
- **Error Handling**: User-friendly error dialogs with clear messages and recovery suggestions
- **Form Validation**: Visual feedback for invalid inputs (red borders, error messages)
- **Button Hierarchy**: Proper primary/secondary/destructive button styles following HIG
- **About Window**: Accessible via App menu (⌘, for About SublerPlus)

