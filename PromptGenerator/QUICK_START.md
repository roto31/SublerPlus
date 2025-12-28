# Quick Start Guide

## Getting Started

This is a native macOS app that replicates the functionality of TripleTen's AI Prompt Generator with pop-up blocking capabilities.

## Features

✅ **Four Prompt Frameworks**: RISE, CREATE, RACE, CREO  
✅ **Auto-Detection**: Automatically selects the best framework  
✅ **Structured Output**: XML-tagged prompts for optimal AI comprehension  
✅ **Copy to Clipboard**: One-click copying  
✅ **Pop-up Blocking**: Comprehensive pop-up prevention (via WebView component)  
✅ **Modern UI**: Native SwiftUI interface  

## Building and Running

### Using Xcode (Easiest)

```bash
cd PromptGenerator
open PromptGenerator.xcodeproj
```

Then:
1. Select the "PromptGenerator" scheme
2. Choose your Mac as the destination
3. Press ⌘R to build and run

### Requirements

- macOS 13.0 or later
- Xcode 14.0 or later

## How to Use

1. **Enter your task** in the left panel (e.g., "Write a blog post about AI")
2. **Add context** (optional) - any additional information
3. **Select framework** - Choose auto-detect or pick a specific framework
4. **Click "Generate Prompt"** - Creates an optimized prompt
5. **Copy the result** - Click the "Copy" button to copy to clipboard
6. **Use with any AI** - Paste into ChatGPT, Claude, Gemini, etc.

## Framework Guide

- **RISE**: Research, analysis, exploration tasks
- **CREATE**: Creative writing, content generation
- **RACE**: Questions requiring evidence-based answers
- **CREO**: Problem-solving, solutions

## Pop-up Blocking

The app includes `WebViewWithPopupBlocking.swift` which provides:

- Navigation-based blocking (blocks new window requests)
- JavaScript injection (overrides window.open())
- Configuration-level prevention (WKWebView settings)

See `IMPLEMENTATION_GUIDE.md` for detailed technical information.

## File Structure

```
PromptGenerator/
├── PromptGeneratorApp.swift          # App entry point
├── ContentView.swift                 # Main UI
├── PromptGeneratorViewModel.swift    # Business logic
├── WebViewWithPopupBlocking.swift    # Pop-up blocking component
├── Info.plist                        # App configuration
├── README.md                         # Full documentation
├── IMPLEMENTATION_GUIDE.md           # Technical details
└── BUILD.md                          # Build instructions
```

## Next Steps

- Read `IMPLEMENTATION_GUIDE.md` for architecture details
- Check `README.md` for comprehensive documentation
- Review `WebViewWithPopupBlocking.swift` for pop-up blocking implementation

