# Automatic Media Type Classification

## Overview

SublerPlus includes an automatic classification system that determines whether a search result is a **movie** or **TV show** without requiring manual input. The system analyzes metadata, title patterns, and context clues to make accurate determinations.

## Classification Result

The system returns a clear classification string:
- `"movie"` - For movie content
- `"TV show"` - For TV show content

## How It Works

### Classification Priority

The classifier uses a priority-based approach, checking indicators in order of reliability:

1. **Explicit MediaKind** (Highest Priority)
   - If `MetadataDetails.mediaKind` is set to `.movie` or `.tvShow`, this takes precedence
   - Most reliable indicator

2. **TV Show Indicators in Details**
   - `show` field (series name)
   - `seasonNumber` field
   - `episodeNumber` field
   - `episodeID` field
   - If any of these are present, classified as TV show

3. **Title Pattern Analysis**
   - Analyzes the title for common TV show patterns
   - Examples: "S01E01", "Season 1", "Episode 5", "1x05", etc.

4. **Provider/Source Analysis**
   - TVDB provider → TV show
   - Other providers → context-dependent

5. **Movie Keywords**
   - Checks for movie-specific keywords in title
   - Examples: "The Movie", "Film", "Feature Film"

6. **Default** (Lowest Priority)
   - If no clear indicators, defaults to "movie"

## Usage

### Basic Classification

```swift
import SublerPlusCore

let result = MetadataResult(
    id: "1",
    title: "Breaking Bad S01E01"
)

// Automatic classification
let classification = MediaTypeClassifier.classify(result: result)
print(classification.rawValue) // "TV show"
```

### With Detailed Metadata

```swift
let result = MetadataResult(id: "2", title: "Episode Title")
let details = MetadataDetails(
    id: "2",
    title: "Episode Title",
    show: "Series Name",
    seasonNumber: 1,
    episodeNumber: 5
)

let classification = MediaTypeClassifier.classify(result: result, details: details)
print(classification.rawValue) // "TV show"
```

### Using Convenience Extensions

```swift
// Direct on MetadataResult
let result = MetadataResult(id: "3", title: "The Matrix")
let type = result.classifyMediaType()
print(type) // "movie"

// Direct on MetadataDetails
let details = MetadataDetails(id: "4", title: "TV Episode", mediaKind: .tvShow)
let type = details.classifyMediaType()
print(type) // "TV show"
```

### Batch Classification

```swift
let results = [
    (result: MetadataResult(id: "1", title: "Movie Title"), details: nil),
    (result: MetadataResult(id: "2", title: "TV Show S01E01"), details: nil)
]

let classifications = MediaTypeClassifier.classifyBatch(results: results)
// classifications["1"] = .movie
// classifications["2"] = .tvShow
```

## TV Show Patterns Detected

The classifier recognizes these patterns in titles:

### Season/Episode Patterns
- `S01E01`, `S1E1` - Standard season/episode format
- `Season 1`, `Season 2` - Season keyword
- `Episode 1`, `Episode 2` - Episode keyword
- `Ep. 1`, `Ep1` - Abbreviated episode
- `E01`, `E1` - Episode number only
- `S01`, `S1` - Season number only
- `1x01`, `2x05` - Season x Episode format
- `Series 1`, `Series 2` - UK format

### TV Show Keywords
- "pilot"
- "season finale"
- "series finale"
- "mid-season"
- "special episode"
- "webisode"
- "miniseries"
- "limited series"
- "anthology"
- "Part 1", "Part 2" (miniseries)
- "Chapter 1", "Chapter 2"

## Integration

### Automatic Classification in Search

The classification is automatically applied to all search results in `UnifiedSearchManager`:

```swift
// Results are automatically classified after search
let results = try await unifiedSearchManager.search(options: searchOptions)

// Each result now has mediaType set
for result in results {
    print("\(result.title): \(result.mediaType ?? "unknown")")
}
```

### UI Display

The classification is displayed in the search results list with visual indicators:
- **TV show**: Blue badge
- **Movie**: Green badge

## Confidence Scoring

The classifier also provides confidence scores (0.0 to 1.0):

```swift
let confidence = MediaTypeClassifier.confidence(result: result, details: details)
// Higher values indicate more reliable classification
```

### Confidence Factors

- **0.5 points**: Explicit `mediaKind` in details
- **0.3 points**: TV show indicators (season/episode/show)
- **0.2 points**: TV show patterns in title
- **0.1 points**: TV-specific provider (TVDB)

## Examples

### Example 1: TV Show by Pattern
```swift
let result = MetadataResult(id: "1", title: "Game of Thrones S08E06")
let classification = MediaTypeClassifier.classify(result: result)
// Returns: .tvShow
```

### Example 2: Movie by Default
```swift
let result = MetadataResult(id: "2", title: "Inception")
let classification = MediaTypeClassifier.classify(result: result)
// Returns: .movie (default when no TV indicators)
```

### Example 3: TV Show by Details
```swift
let result = MetadataResult(id: "3", title: "Episode Title")
let details = MetadataDetails(
    id: "3",
    title: "Episode Title",
    show: "The Office",
    seasonNumber: 3,
    episodeNumber: 10
)
let classification = MediaTypeClassifier.classify(result: result, details: details)
// Returns: .tvShow
```

### Example 4: Explicit MediaKind
```swift
let result = MetadataResult(id: "4", title: "Some Title")
let details = MetadataDetails(id: "4", title: "Some Title", mediaKind: .movie)
let classification = MediaTypeClassifier.classify(result: result, details: details)
// Returns: .movie (explicit mediaKind takes precedence)
```

## Testing

Comprehensive test suite available in `MediaTypeClassifierTests.swift`:

```bash
swift test --filter MediaTypeClassifier
```

Tests cover:
- TV show pattern detection
- Movie classification
- Explicit mediaKind handling
- Provider-based classification
- Edge cases and mixed indicators
- Batch classification
- Confidence scoring

## Implementation Details

### Files

- **`App/Controllers/MediaTypeClassifier.swift`** - Main classification logic
- **`App/Models/MetadataResult.swift`** - Extended with `mediaType` field and classification methods
- **`App/Controllers/UnifiedSearchManager.swift`** - Automatic classification integration
- **`App/Views/AdvancedSearchView.swift`** - UI display of classification
- **`Tests/MediaTypeClassifierTests.swift`** - Test suite

### Performance

- Classification is performed automatically during search
- Minimal performance impact (pattern matching is fast)
- Results are cached with search results

## Future Enhancements

Potential improvements:
- Machine learning-based classification
- User feedback loop for accuracy improvement
- Custom pattern recognition rules
- Provider-specific classification hints
- Confidence-based filtering

