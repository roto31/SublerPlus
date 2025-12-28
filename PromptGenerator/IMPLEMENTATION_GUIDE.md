# Implementation Guide: AI Prompt Generator with Pop-up Blocking

This guide explains how the AI Prompt Generator app was implemented, including all features and the pop-up blocking mechanism.

## Architecture Overview

The app is built as a native macOS SwiftUI application with the following components:

1. **PromptGeneratorApp.swift** - Main app entry point
2. **ContentView.swift** - Main UI with split-view layout
3. **PromptGeneratorViewModel.swift** - Business logic for prompt generation
4. **WebViewWithPopupBlocking.swift** - Web view component with pop-up blocking (for future use or embedding web content)

## Key Features Implemented

### 1. Prompt Generation Frameworks

The app supports four professional prompt engineering frameworks:

#### RISE Framework (Research, Ideate, Synthesize, Execute)
- Best for: Research tasks, analysis, exploration
- Structure: Structured XML tags with clear instructions
- Detection keywords: "analyze", "evaluate", "compare", "research", "explore", "investigate"

#### CREATE Framework (Context, Request, Examples, Adjustments, Type, Extras)
- Best for: Creative tasks, content generation
- Structure: Context-aware prompt with clear request structure
- Detection keywords: "create", "generate", "write"

#### RACE Framework (Restate, Answer, Cite, Explain)
- Best for: Analytical questions requiring evidence
- Structure: Question-answer format with citation support
- Detection keywords: "analyze", "evaluate", "compare"

#### CREO Framework (Challenge, Response, Evidence, Outcome)
- Best for: Problem-solving and solutions
- Structure: Problem-solution format with expected outcomes
- Detection keywords: "problem", "solve", "solution"

### 2. Framework Auto-Detection

The app automatically detects the best framework based on:
- Keywords in the user's task description
- Task type (research, creative, analytical, problem-solving)
- Fallback to CREATE framework for creative tasks

### 3. Structured Prompt Output

All generated prompts use XML-style tags for:
- `<role>` - Defines the AI's role
- `<task>` / `<question>` / `<challenge>` - User's request
- `<context>` - Additional background information
- `<framework>` - Framework identifier
- `<instructions>` - Step-by-step guidance
- `<output_requirements>` - Expected output format

This structure ensures compatibility with:
- ChatGPT
- Claude (Anthropic)
- Google Gemini
- DeepSeek
- Grok
- Any other language model

### 4. User Interface

The SwiftUI interface features:
- **Split-view layout**: Input panel (left) and output panel (right)
- **Framework selector**: Segmented control for manual framework selection
- **Auto-detect option**: Automatic framework detection
- **Text editors**: Multi-line input for task and context
- **Real-time generation**: Progress indicator during generation
- **Copy button**: One-click clipboard copying
- **Visual feedback**: Alerts for successful copy operations

### 5. Pop-up Blocking Implementation

The app includes comprehensive pop-up blocking through `WebViewWithPopupBlocking.swift`:

#### Method 1: Navigation Delegate Blocking
```swift
func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, 
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    // Block navigation to new windows (pop-ups)
    if navigationAction.targetFrame == nil {
        decisionHandler(.cancel)  // Block pop-up
        return
    }
    decisionHandler(.allow)  // Allow normal navigation
}
```

#### Method 2: JavaScript Injection
Injected JavaScript that overrides:
- `window.open()` - Prevents pop-up windows
- `window.createPopup()` - Blocks legacy IE pop-ups
- Optional: `window.alert()`, `window.confirm()`, `window.prompt()` - Can block dialogs if needed

#### Method 3: WKWebView Configuration
```swift
configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
```

#### Implementation Details

The `WebViewWithPopupBlocking.swift` file provides two implementations:

1. **WebViewWithPopupBlocking** - Basic implementation with navigation delegate blocking
2. **EnhancedWebViewWithPopupBlocking** - Enhanced version with JavaScript injection

Both implementations:
- Block navigation to new windows (`targetFrame == nil`)
- Prevent JavaScript-initiated pop-ups
- Log blocked pop-ups to console for debugging
- Maintain normal navigation within the main frame

### 6. Copy to Clipboard

Simple clipboard integration:
```swift
func copyToClipboard() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(generatedPrompt, forType: .string)
    showCopyAlert = true
}
```

## How Pop-up Blocking Works

1. **Navigation Interception**: The WKNavigationDelegate intercepts all navigation requests
2. **Target Frame Check**: If `navigationAction.targetFrame == nil`, it's a new window request
3. **Cancellation**: New window requests are cancelled before they open
4. **JavaScript Override**: Injected JavaScript overrides `window.open()` to return null
5. **Configuration Lock**: WKWebView preferences prevent automatic JavaScript pop-ups

## Usage Example

### For Native App (Current Implementation)
The current app is a native SwiftUI app, so pop-ups aren't an issue. The WebView component is available for future use if you want to embed web content.

### For Web Content Embedding
If you want to embed the TripleTen website or any web content:

```swift
import SwiftUI

struct WebContentView: View {
    @State private var isLoading = false
    let url = URL(string: "https://tripleten.com/tools/prompt-generator/")!
    
    var body: some View {
        EnhancedWebViewWithPopupBlocking(url: url, isLoading: $isLoading)
            .overlay(
                isLoading ? ProgressView() : nil
            )
    }
}
```

## Testing Pop-up Blocking

To test the pop-up blocking:

1. Create a test HTML file with pop-up triggers:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Popup Test</title>
</head>
<body>
    <button onclick="window.open('https://example.com')">Test Popup</button>
    <button onclick="alert('Alert')">Test Alert</button>
</body>
</html>
```

2. Load it in the EnhancedWebViewWithPopupBlocking
3. Click the buttons - pop-ups should be blocked
4. Check console logs for "Popup blocked" messages

## Future Enhancements

Potential improvements:
- Save generated prompts to history
- Export prompts to file
- Custom framework definitions
- Prompt templates library
- Integration with AI APIs for testing
- Dark mode support (automatic in macOS)
- Keyboard shortcuts

## Security Considerations

The pop-up blocking helps prevent:
- Unwanted advertisement pop-ups
- Phishing attempts via new windows
- Malicious redirects
- User experience disruption

The app itself:
- Runs locally (no network requests for prompt generation)
- No data collection
- No external API calls
- Privacy-focused design

