# App Icon Setup Instructions

## Quick Start

To set up the new app icon and rebuild the application:

1. **Prepare your icon image:**
   - Should be a square PNG image
   - Recommended size: 1024x1024 pixels
   - High quality, with the design described (film clapperboard, magnifying glass, Swift logo on gradient blue background)

2. **Run the setup script:**
   ```bash
   ./scripts/setup-app-icon.sh /path/to/your/icon.png
   ```

   This will:
   - Generate all required icon sizes (16x16 through 1024x1024)
   - Place them in `App/Resources/AppIcon.appiconset/`
   - Rebuild the application

## Manual Setup

If you prefer to set up icons manually:

1. **Create all required sizes** from your source image:
   ```bash
   # Navigate to the icon directory
   cd App/Resources/AppIcon.appiconset/
   
   # Generate each size (replace source.png with your image)
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

2. **Rebuild the app:**
   ```bash
   ./scripts/build.sh --release
   ```

## Icon Description

Based on the provided description, the icon should feature:
- **Film Clapperboard**: Dark grey/black with black and white stripes, positioned in upper half
- **Magnifying Glass**: Silver/chrome rimmed, overlapping the clapperboard, with digital display showing blue/teal data visualization
- **Swift Logo**: Orange square with white swift bird logo in bottom right corner
- **Background**: Gradient blue (light to dark) with glowing light effects and star-like glints

## Required Icon Sizes

The app requires the following icon sizes:

| Size | Dimensions | File Name |
|------|------------|-----------|
| 16x16 (1x) | 16×16 | `icon_16x16.png` |
| 16x16 (2x) | 32×32 | `icon_16x16@2x.png` |
| 32x32 (1x) | 32×32 | `icon_32x32.png` |
| 32x32 (2x) | 64×64 | `icon_32x32@2x.png` |
| 128x128 (1x) | 128×128 | `icon_128x128.png` |
| 128x128 (2x) | 256×256 | `icon_128x128@2x.png` |
| 256x256 (1x) | 256×256 | `icon_256x256.png` |
| 256x256 (2x) | 512×512 | `icon_256x256@2x.png` |
| 512x512 (1x) | 512×512 | `icon_512x512.png` |
| 512x512 (2x) | 1024×1024 | `icon_512x512@2x.png` |

## Verification

After setting up the icons, verify they're in place:

```bash
ls -lh App/Resources/AppIcon.appiconset/
```

You should see all 10 PNG files plus `Contents.json`.

## Next Steps

Once you have the icon image file ready:

1. Place it in an accessible location
2. Run: `./scripts/setup-app-icon.sh /path/to/icon.png`
3. The script will handle everything automatically

## Troubleshooting

**Error: sips command not found**
- `sips` is a built-in macOS tool. If missing, you may need to reinstall macOS command line tools.

**Icons look blurry**
- Ensure your source image is at least 1024x1024 pixels
- Use high-quality source material
- Avoid upscaling small images

**Icons not appearing in app**
- Ensure all files are in `App/Resources/AppIcon.appiconset/`
- Verify `Contents.json` is correct
- Rebuild the app completely (clean build)

