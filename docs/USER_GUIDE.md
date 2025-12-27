# SublerPlus User Guide

## Install & Run
1) Ensure macOS 12+ with Swift toolchain.
2) Set API keys:
   - In-app Settings (Keychain) for TPDB/TMDB/TVDB/OpenSubtitles, or
   - Env vars before launch: `TPDB_API_KEY`, `TMDB_API_KEY`, `TVDB_API_KEY`, `OPENSUBTITLES_API_KEY`.
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
`sublerplus-cli [--no-adult] [--auto-best] /path/to/file.mp4`  
Uses same providers and pipeline; ambiguous items are deferred for later resolution in the app.
- `--no-adult`: Disable adult content providers
- `--auto-best`: Automatically select the best match without manual disambiguation

## Settings
- **API Keys**: Manage TPDB, TMDB, TVDB, and OpenSubtitles API keys (stored in Keychain).
- **Adult Metadata**: Toggle adult content lookups; adjust TPDB confidence threshold.
- **Output Options**:
  - **Retain Originals**: When enabled, enriched files are written to a custom output directory instead of replacing the original.
  - **Output Directory**: Destination folder for enriched files when retain originals is enabled.
- **NFO Sidecars**: 
  - **Generate NFO**: Create .nfo XML files alongside enriched media.
  - **NFO Output Directory**: Custom location for .nfo files (defaults to same directory as media).
- **TV Show Naming**: 
  - **Naming Template**: Customize TV episode naming (e.g., `S%02dE%02d - %t` produces `S01E05 - Episode Title`).
- **Subtitles**:
  - **OpenSubtitles API Key**: Required for subtitle search and download (uses RapidAPI).
  - **Default Language**: Set preferred subtitle language using ISO codes (e.g., `eng`, `spa`, `fra`).
- **Watch Folders**: Add directories to automatically monitor and enqueue new media files for processing.
- **Cache Management**: 
  - Clear ambiguity resolution cache to reset remembered disambiguation choices.
  - Clear artwork cache to free up storage space.

## Watch Folders
- **Add Watch Folders**: Configure directories in Settings to automatically monitor for new media files.
- **Auto-Processing**: New MP4/M4V/MOV files detected in watched folders are automatically enqueued into the JobQueue.
- **Bounded Concurrency**: Processing respects the job queue's concurrency limits with automatic retries on failure.
- **Management**: Add or remove folders at any time through the Settings interface.

## Subtitles
- **Search & Download**: Search for subtitles via OpenSubtitles integration (requires RapidAPI key).
- **Language Support**: Configure default language in Settings using ISO 639-2 codes (e.g., `eng`, `spa`, `fra`, `deu`).
- **Format Support**: Handles both SRT and VTT subtitle formats.
- **Integration**: Subtitle search is available for selected media files in the file detail view.

## NFO Sidecar Files
- **Generation**: Optionally generate .nfo XML files containing metadata for media center applications (Kodi, Plex, etc.).
- **Content**: NFO files include title, plot, studio, actors, and genres from enriched metadata.
- **Output Location**: 
  - By default, .nfo files are saved alongside the media file.
  - Optionally specify a custom NFO output directory in Settings.
- **Enable/Disable**: Toggle NFO generation in Settings.

## Shortcuts
- Add Files ⌘N, Enrich ⌘E, Search ⌘F, Refresh Status ⌘R, Settings ⌘,.

## Accessibility & HIG
- Sidebar/navigation labels and hints.
- Toolbar and drop targets labeled with hints; ambiguity sheet accessible.
- Respects Reduce Motion/Transparency via SwiftUI environment.

