# App Icon Resources

This directory contains the application icon resources for SublerPlus.

## Icon Files Required

Place the following icon files in `AppIcon.appiconset/`:

- `icon_16x16.png` - 16x16 pixels
- `icon_16x16@2x.png` - 32x32 pixels (Retina)
- `icon_32x32.png` - 32x32 pixels
- `icon_32x32@2x.png` - 64x64 pixels (Retina)
- `icon_128x128.png` - 128x128 pixels
- `icon_128x128@2x.png` - 256x256 pixels (Retina)
- `icon_256x256.png` - 256x256 pixels
- `icon_256x256@2x.png` - 512x512 pixels (Retina)
- `icon_512x512.png` - 512x512 pixels
- `icon_512x512@2x.png` - 1024x1024 pixels (Retina)

## Creating Icons

### Option 1: Using macOS Icon Composer
1. Open Icon Composer (included with Xcode)
2. Drag your 1024x1024 source image
3. Export as `.icns` file
4. Convert `.icns` to individual PNG files using `iconutil`:
   ```bash
   iconutil -c iconset AppIcon.icns
   ```

### Option 2: Using sips (macOS built-in)
If you have a 1024x1024 source image:
```bash
# Create all sizes from a source image
sips -z 16 16 source.png --out icon_16x16.png
sips -z 32 32 source.png --out icon_16x16@2x.png
sips -z 32 32 source.png --out icon_32x32.png
sips -z 64 64 source.png --out icon_32x32@2x.png
sips -z 128 128 source.png --out icon_128x128.png
sips -z 256 256 source.png --out icon_128x128@2x.png
sips -z 256 256 source.png --out icon_256x256.png
sips -z 512 512 source.png --out icon_256x256@2x.png
sips -z 512 512 source.png --out icon_512x512.png
sips -z 1024 1024 source.png --out icon_512x512@2x.png
```

### Option 3: Online Tools
- Use online icon generators that support macOS app icons
- Ensure they generate all required sizes

## Icon Design Guidelines

- Use a square source image (1024x1024 recommended)
- Keep important content within the center 80% (safe area)
- Use transparent backgrounds for best results
- Follow macOS Human Interface Guidelines
- Consider dark mode appearance
- Test at small sizes (16x16) to ensure readability

## Build Integration

The build script (`scripts/build.sh`) will automatically:
1. Copy icon resources to the app bundle
2. Generate `.icns` file if needed
3. Set icon reference in Info.plist

## Notes

- Icons are copied to `SublerPlus.app/Contents/Resources/AppIcon.appiconset/`
- The Info.plist references the icon via `CFBundleIconFile`
- macOS will automatically use the appropriate size for each context

