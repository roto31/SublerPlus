# AI Prompt Generator

A native macOS application that helps you create optimized AI prompts using professional prompt engineering frameworks.

## Features

- **Multiple Framework Support**: Choose from RISE, CREATE, RACE, or CREO frameworks, or use auto-detection
- **Structured Prompt Generation**: Generates well-formatted prompts with XML tags for optimal AI comprehension
- **Intelligent Framework Detection**: Automatically selects the best framework based on your task description
- **Copy to Clipboard**: Easy one-click copying of generated prompts
- **Clean, Modern UI**: Native SwiftUI interface with a split-view layout

## Prompt Frameworks

### RISE (Research, Ideate, Synthesize, Execute)
Best for research tasks, analysis, and exploratory work.

### CREATE (Context, Request, Examples, Adjustments, Type, Extras)
Best for creative tasks, content generation, and writing.

### RACE (Restate, Answer, Cite, Explain)
Best for analytical questions requiring evidence-based answers.

### CREO (Challenge, Response, Evidence, Outcome)
Best for problem-solving and solution-focused tasks.

## Building

This is a SwiftUI macOS application. To build:

1. Open in Xcode:
   ```bash
   open PromptGenerator.xcodeproj
   ```

2. Or build from command line using Swift Package Manager:
   ```bash
   swift build -c release
   ```

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later
- Swift 5.9 or later

## Usage

1. Enter your task description in the input field
2. Optionally add additional context
3. Select a framework (or use auto-detect)
4. Click "Generate Prompt"
5. Copy the generated prompt to use with any AI model

The generated prompts are compatible with:
- ChatGPT
- Claude (Anthropic)
- Google Gemini
- DeepSeek
- Grok
- Any other language model

