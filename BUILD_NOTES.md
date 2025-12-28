# Build Notes

## Icon Setup

The app icon setup script is ready. To add the new icon:

```bash
./scripts/setup-app-icon.sh /path/to/your/icon.png
```

This will generate all required sizes and rebuild the app.

## Build Requirements

### SwiftPM Build (Current)
- The SublerCompatibility files require `MP42Foundation` from the Subler Xcode project
- These files are excluded from SwiftPM builds in `Package.swift`
- Core functionality works without Subler integration

### Xcode Build (Full Features)
- Requires the Subler Xcode project to be included
- Provides full Subler search architecture integration
- All SublerCompatibility features available

## Current Status

- ✅ Icon setup script created (`scripts/setup-app-icon.sh`)
- ✅ Icon generation script ready
- ✅ Build script updated
- ⚠️ SublerCompatibility requires Xcode build for full functionality

## Next Steps

1. Provide the icon image file (1024x1024 PNG recommended)
2. Run: `./scripts/setup-app-icon.sh /path/to/icon.png`
3. For full Subler integration, build with Xcode

