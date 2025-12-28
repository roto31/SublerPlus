# Search Function Refactoring Guide

## Overview

This document describes the refactored search functionality that unifies the legacy Subler search system with the modern SublerPlus search architecture. The refactoring enables seamless integration between both systems while maintaining backward compatibility.

## Architecture

### Components

1. **UnifiedSearchManager** (`App/Controllers/UnifiedSearchManager.swift`)
   - Central coordinator that bridges legacy and modern search providers
   - Handles search execution across both systems
   - Manages result conversion and deduplication

2. **Legacy System (Subler)**
   - `MetadataService` protocol - Legacy provider interface
   - `MetadataSearch` enum - Search operation wrapper
   - `MetadataResult` class - Dictionary-based result storage
   - Providers: TheMovieDB, TheTVDB, AppleTV, iTunesStore

3. **Modern System (SublerPlus)**
   - `MetadataProvider` protocol - Modern async/await interface
   - `MetadataResult` struct - Type-safe result structure
   - Providers: TMDBProvider, TVDBProvider, ThePornDBProvider

### Unified Search Flow

```
User Query
    ↓
UnifiedSearchManager
    ├─→ Modern Providers (async/await)
    │   └─→ TMDB, TVDB, TPDB
    │
    └─→ Legacy Providers (callback-based)
        └─→ TheMovieDB, TheTVDB, AppleTV, iTunesStore
    ↓
Result Conversion & Deduplication
    ↓
Sorted Results (by score, year proximity)
```

## Implementation Details

### Search Options

The `UnifiedSearchManager.SearchOptions` struct provides flexible search configuration:

```swift
let options = UnifiedSearchManager.SearchOptions(
    query: "The Matrix",
    type: .movie,  // or .tvShow(season: 1, episode: 1)
    language: "en",
    providerName: nil,  // nil = use all providers
    yearHint: 1999
)
```

### Result Conversion

The system automatically converts between legacy and modern result formats:

- **Legacy → Modern**: Dictionary-based `MetadataResult` class → Type-safe struct
- **Modern → Legacy**: Not needed (modern is preferred)

### Provider Priority

1. Modern providers are searched first (faster, async/await)
2. Legacy providers are searched in parallel
3. Results are merged, deduplicated, and sorted

## Usage Examples

### Basic Search

```swift
let manager = UnifiedSearchManager(
    modernProviders: [tmdbProvider, tvdbProvider],
    includeAdult: false
)

let options = UnifiedSearchManager.SearchOptions(
    query: "Breaking Bad",
    type: .tvShow(season: 1, episode: 1)
)

let results = try await manager.search(options: options)
```

### Fetching Details

```swift
let details = try await manager.fetchDetails(for: result)
```

### Integration with ViewModels

The `AppViewModel` has been updated to use `UnifiedSearchManager`:

```swift
// In ViewModels.swift
private var unifiedSearchManager: UnifiedSearchManager

// Search automatically uses both modern and legacy providers
private func runSearch(query: String, yearHint: Int?) async {
    let options = UnifiedSearchManager.SearchOptions(
        query: query,
        type: .movie,
        yearHint: yearHint
    )
    let results = try await unifiedSearchManager.search(options: options)
    // Update UI with results
}
```

## Benefits

1. **Backward Compatibility**: Legacy Subler search continues to work
2. **Modern Architecture**: New features use async/await
3. **Unified Interface**: Single API for all search operations
4. **Better Results**: Combines results from all providers
5. **Future-Proof**: Easy to add new providers

## Migration Path

### For New Code

Use `UnifiedSearchManager` directly:

```swift
let manager = UnifiedSearchManager(modernProviders: providers, includeAdult: false)
let results = try await manager.search(options: options)
```

### For Legacy Code

Legacy code continues to work unchanged. The `MetadataSearch` enum and `MetadataService` protocol remain functional.

## Testing

The refactored search system should be tested with:

1. **Unit Tests**: Test result conversion and deduplication
2. **Integration Tests**: Test search across multiple providers
3. **UI Tests**: Verify search results display correctly
4. **Performance Tests**: Ensure search performance is acceptable

## Future Enhancements

1. **Smart Type Detection**: Automatically detect movie vs TV show from query
2. **Provider Weighting**: Allow users to prioritize certain providers
3. **Caching**: Cache search results to improve performance
4. **Offline Support**: Cache provider responses for offline use
5. **Search History**: Track and suggest previous searches

## Troubleshooting

### No Results Found

- Check that at least one provider is configured
- Verify API keys are set (for modern providers)
- Check network connectivity
- Review provider-specific error messages

### Legacy Provider Not Working

- Ensure legacy services are properly initialized
- Check that `MetadataSearch.service(name:)` returns valid service
- Verify language settings are correct

### Performance Issues

- Limit the number of providers searched simultaneously
- Implement result caching
- Consider provider-specific rate limiting

## Code Locations

- **UnifiedSearchManager**: `App/Controllers/UnifiedSearchManager.swift`
- **ViewModels Integration**: `App/Controllers/ViewModels.swift` (lines ~1000-1060)
- **Legacy Search**: `Subler/Classes/MetadataImporters/MetadataImporter.swift`
- **Modern Providers**: `App/Controllers/StandardMetadataProvider.swift`, etc.
- **Search UI**: `App/Views/AdvancedSearchView.swift`

## API Reference

### UnifiedSearchManager

#### Initialization

```swift
init(modernProviders: [MetadataProvider], includeAdult: Bool)
```

#### Search

```swift
func search(options: SearchOptions) async throws -> [MetadataResult]
```

#### Fetch Details

```swift
func fetchDetails(for result: MetadataResult) async throws -> MetadataDetails
```

#### Available Providers

```swift
var availableProviders: [String] { get }
```

## Conclusion

The refactored search system provides a unified, modern interface while maintaining full backward compatibility with the legacy Subler search functionality. This allows for gradual migration and ensures all existing features continue to work while enabling new capabilities.

