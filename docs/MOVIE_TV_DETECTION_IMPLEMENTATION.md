# Movie and TV Show Detection Implementation

## Overview

SublerPlus now includes a comprehensive automatic classification system that determines whether a search result corresponds to a **movie** or **TV show** without requiring manual input. The system analyzes metadata, title patterns, and context clues to make accurate determinations.

## Implementation Summary

### Core Components

1. **MediaTypeClassifier** (`App/Controllers/MediaTypeClassifier.swift`)
   - Primary classification engine
   - Priority-based analysis system
   - Pattern recognition for TV show indicators
   - Provider-based classification hints
   - Confidence scoring

2. **MetadataResult Extension** (`App/Models/MetadataResult.swift`)
   - Added `mediaType` field to store classification
   - `withClassifiedMediaType()` method for automatic classification
   - Convenience extension method `classifyMediaType()`

3. **UnifiedSearchManager Integration** (`App/Controllers/UnifiedSearchManager.swift`)
   - Automatic classification of all search results
   - Classification happens after sorting/deduplication
   - Results are classified before being returned to UI

4. **ViewModels Enhancement** (`App/Controllers/ViewModels.swift`)
   - Re-classification when detailed metadata is loaded
   - Updates search results with more accurate classification
   - Status messages include media type information

5. **UI Display** (`App/Views/AdvancedSearchView.swift`)
   - Visual badges in search results list
   - Color-coded indicators (Blue for TV show, Green for movie)
   - Classification displayed in result details view

## Classification Logic

### Priority Order

The classifier uses a priority-based approach, checking indicators in order of reliability:

1. **Explicit MediaKind** (Highest Priority - 0.5 confidence points)
   - If `MetadataDetails.mediaKind` is set to `.movie` or `.tvShow`
   - Most reliable indicator
   - Takes precedence over all other checks

2. **TV Show Indicators in Details** (0.3 confidence points)
   - `show` field (series name)
   - `seasonNumber` field
   - `episodeNumber` field
   - `episodeID` field
   - If any of these are present, classified as TV show

3. **Title Pattern Analysis** (0.2 confidence points)
   - Analyzes the title for common TV show patterns
   - Examples: "S01E01", "Season 1", "Episode 5", "1x05", etc.
   - See "TV Show Patterns Detected" section below

4. **Provider/Source Analysis** (0.1 confidence points)
   - TVDB provider → TV show
   - Other providers → context-dependent

5. **Movie Keywords**
   - Checks for movie-specific keywords in title
   - Examples: "The Movie", "Film", "Feature Film"

6. **Default** (Lowest Priority)
   - If no clear indicators, defaults to "movie"
   - Most common case for general search results

### TV Show Patterns Detected

The classifier recognizes these patterns in titles:

#### Season/Episode Patterns
- `S01E01`, `S1E1` - Standard season/episode format
- `Season 1`, `Season 2` - Season keyword
- `Episode 1`, `Episode 2` - Episode keyword
- `Ep. 1`, `Ep1` - Abbreviated episode
- `E01`, `E1` - Episode number only
- `S01`, `S1` - Season number only
- `1x01`, `2x05` - Season x Episode format
- `Series 1`, `Series 2` - UK format
- `Part 1`, `Part 2` - Miniseries format
- `Chapter 1`, `Chapter 2` - Chapter format

#### TV Show Keywords
- "pilot"
- "season finale"
- "series finale"
- "mid-season"
- "special episode"
- "webisode"
- "miniseries"
- "limited series"
- "anthology"

## Integration Points

### 1. Search Results

All search results are automatically classified when returned from `UnifiedSearchManager`:

```swift
// In UnifiedSearchManager.search()
var sortedResults = sortAndDeduplicate(...)
sortedResults = classifyResults(sortedResults)  // Automatic classification
return sortedResults
```

### 2. Detailed Metadata Loading

When detailed metadata is fetched for a selected result, the classification is refined:

```swift
// In ViewModels.fetchResultDetails()
let details = try await unifiedSearchManager.fetchDetails(for: result)

// Re-classify with detailed metadata for better accuracy
if let index = searchResults.firstIndex(where: { $0.id == result.id }) {
    let updatedResult = result.withClassifiedMediaType(details: details)
    searchResults[index] = updatedResult
}
```

### 3. UI Display

The classification is displayed in multiple places:

#### Search Results List
- Badge next to title showing "movie" or "TV show"
- Color-coded: Blue for TV show, Green for movie

#### Result Details View
- Badge in header showing media type
- Status messages include media type: "Details loaded for Title (movie)"

## Usage Examples

### Basic Classification

```swift
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

## Testing

Comprehensive test suite available in `MediaTypeClassifierTests.swift`:

- **16 tests** covering:
  - TV show pattern detection (S01E01, Season, Episode patterns)
  - Movie classification
  - Explicit mediaKind handling
  - Provider-based classification (TVDB)
  - Edge cases and mixed indicators
  - Batch classification
  - Confidence scoring
  - Convenience methods

All tests pass successfully.

## Performance

- Classification is performed automatically during search
- Minimal performance impact (pattern matching is fast)
- Results are cached with search results
- Re-classification only happens when detailed metadata is loaded

## Accuracy

The classification system achieves high accuracy through:

1. **Multi-factor Analysis**: Uses multiple indicators, not just one
2. **Priority System**: More reliable indicators take precedence
3. **Refinement**: Re-classifies when detailed metadata is available
4. **Pattern Recognition**: Recognizes common TV show naming conventions
5. **Provider Hints**: Uses provider information as context

## Future Enhancements

Potential improvements:

- Machine learning-based classification
- User feedback loop for accuracy improvement
- Custom pattern recognition rules
- Provider-specific classification hints
- Confidence-based filtering
- Historical classification data for better accuracy

## Files Modified/Created

### New Files
- `App/Controllers/MediaTypeClassifier.swift` - Core classification logic
- `Tests/MediaTypeClassifierTests.swift` - Test suite
- `docs/MEDIA_TYPE_CLASSIFICATION.md` - User documentation
- `docs/MOVIE_TV_DETECTION_IMPLEMENTATION.md` - This file

### Modified Files
- `App/Models/MetadataResult.swift` - Added `mediaType` field and classification methods
- `App/Controllers/UnifiedSearchManager.swift` - Integrated automatic classification
- `App/Controllers/ViewModels.swift` - Added re-classification on details load
- `App/Views/AdvancedSearchView.swift` - Added UI display of classification

## Conclusion

The automatic movie/TV show detection system is fully integrated into SublerPlus, providing accurate classification without requiring manual input. The system uses a multi-factor approach with priority-based analysis to ensure high accuracy, and automatically refines classifications when detailed metadata becomes available.

