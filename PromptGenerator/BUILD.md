# Building Prompt Generator

## Option 1: Using Xcode (Recommended)

1. Open the project:
   ```bash
   open PromptGenerator.xcodeproj
   ```

2. Select a scheme (Debug or Release)

3. Build and Run (⌘R)

## Option 2: Using Swift Package Manager

Since this is a macOS app with SwiftUI, the easiest way is to use Xcode. However, if you prefer command line:

1. Create a simple build script or use Swift Package Manager
2. Note: The Package.swift file is provided, but for a full macOS app, Xcode is recommended

## Option 3: Quick Build Script

Create a simple shell script to compile:

```bash
#!/bin/bash
swiftc -target x86_64-apple-macosx13.0 \
  PromptGeneratorApp.swift \
  ContentView.swift \
  PromptGeneratorViewModel.swift \
  WebViewWithPopupBlocking.swift \
  -o PromptGenerator \
  -framework SwiftUI \
  -framework AppKit \
  -framework WebKit
```

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later (for full development)
- Swift 5.9 or later

