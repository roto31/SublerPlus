# Search Function Troubleshooting Guide

## Problem Statement
The search function is not working when a user clicks 'Search' after dropping in a media file.

## Quick Diagnostic (Start Here)

**Most Likely Cause (80% of cases)**: No search providers configured

**Quick Check:**
1. Open Settings → API Keys section
2. Verify at least one API key is set (TMDB, TVDB, or TPDB)
3. If all are empty → **This is your problem!**

**Quick Fix:**
1. Get a TMDB API key from https://www.themoviedb.org/settings/api
2. Enter it in Settings → TMDB API Key
3. Click Save
4. Try search again

**If API keys are set but search still fails**, continue with detailed troubleshooting below.

## 1. Potential Root Causes

### Frontend Issues
1. **Auto-population Failure**: Metadata from dropped file may not be populating search fields
2. **Empty Query Validation**: Search fields may be empty even after file drop
3. **UI State Synchronization**: Search button may be disabled or not responding
4. **Async Task Issues**: Search task may be cancelled or not executing
5. **Cache Key Mismatch**: Cache lookup may be failing due to key normalization issues

### Backend Issues
1. **Provider Configuration**: No search providers available or misconfigured
2. **API Key Missing**: Required API keys (TMDB, TVDB) not set
3. **Network Connectivity**: Search providers unreachable
4. **UnifiedSearchManager Initialization**: Manager not properly initialized with cache/weights
5. **Search Type Detection**: Incorrect search type (movie vs TV show) being used

### Data Flow Issues
1. **Metadata Extraction Failure**: File metadata not being read correctly
2. **Query Building Logic**: Search query not constructed properly from fields
3. **Provider Weight Application**: Weight calculations causing search failures
4. **Result Processing**: Search results not being returned or displayed

## 2. Step-by-Step Troubleshooting Guide

### Step 1: Check User Interface for Visible Errors

**Actions:**
1. After dropping a file, check the status bar at the bottom of the window
2. Look for error messages like:
   - "File not found"
   - "Unsupported file type"
   - "Error loading file"
   - "No search providers available"
   - "Please enter at least one search field"

**Expected Behavior:**
- Status should show "Reading metadata from [filename]..." then "Metadata loaded from [filename]"
- Search fields should auto-populate with file metadata (Title, Studio, Year, Actors)
- Search button should be enabled

**If Issues Found:**
- Note the exact error message
- Check file path and permissions
- Verify file type is supported (MP4, M4V, M4A, MOV, MKV)

### Step 2: Verify Media File Upload/Drop Functionality

**Test Procedure:**
1. Drop a known-good media file (MP4 with metadata)
2. Observe the sidebar - it should show:
   - File name
   - Extracted metadata (Title, Studio, Year, Performers)
   - Artwork (if present)

**Check Points:**
- File appears in sidebar: ✅ Drop working
- Metadata visible in sidebar: ✅ Metadata extraction working
- Search fields auto-populated: ✅ Auto-population working
- Search fields empty: ❌ Auto-population failed

**Debug Code Location:**
- `App/Views/AdvancedSearchView.swift` lines 370-403: `processDroppedFile`
- `App/Controllers/ViewModels.swift` lines 232-290: `loadMetadataFromFile`

### Step 3: Verify Search Function Linkage

**Test Procedure:**
1. Manually fill in search fields (Title: "The Matrix")
2. Click Search button
3. Check status message

**Expected Flow:**
```
Click Search → Status: "Preparing search..." → "Searching..." → "Found X results"
```

**If Search Doesn't Trigger:**
- Check button action: `App/Views/AdvancedSearchView.swift` line 408-414
- Verify `viewModel.runAdvancedSearch()` is being called
- Check console for errors

**Validation Checks:**
```swift
// In runAdvancedSearch() - line 200-230
// Query must not be empty
guard !query.isEmpty else {
    status = "Please enter at least one search field"
    return
}
```

### Step 4: Test with Different Media File Types

**Test Matrix:**

| File Type | Expected Behavior | Common Issues |
|-----------|------------------|---------------|
| MP4 with metadata | Auto-populate, search works | None |
| MP4 without metadata | Fields empty, manual entry needed | User must type query |
| M4V | Same as MP4 | None |
| MOV | Same as MP4 | May have different metadata structure |
| MKV | Same as MP4 | May require additional parsing |
| Large files (>1GB) | May take longer to read | Timeout issues |

**File Size Considerations:**
- Small files (<100MB): Should work immediately
- Medium files (100MB-1GB): May take 2-5 seconds
- Large files (>1GB): May take 10+ seconds, check for timeouts

**Debug:**
- Check `loadMetadataFromFile` completion time
- Monitor status messages for "Reading metadata..." duration
- Verify file isn't corrupted or locked

### Step 5: Review Logs and Error Messages

**Log Locations:**
1. **Status Stream**: Check `viewModel.status` property
2. **Console Output**: Xcode console for Swift errors
3. **StatusStream Actor**: Async status messages

**Key Error Patterns:**

**Error: "No search providers available"**
- **Cause**: No providers configured or all filtered out
- **Fix**: Check Settings → API Keys (TMDB, TVDB)
- **Code**: `App/Controllers/UnifiedSearchManager.swift` line 78

**Error: "Please enter at least one search field"**
- **Cause**: Query validation failed
- **Fix**: Ensure at least one field has content
- **Code**: `App/Controllers/ViewModels.swift` line 219

**Error: "Search failed: [error message]"**
- **Cause**: Provider search failed
- **Fix**: Check network, API keys, provider availability
- **Code**: `App/Controllers/ViewModels.swift` line 1043-1049

**Debugging Code:**
```swift
// Add logging in runSearch() method
print("Search query: \(query)")
print("Year hint: \(yearHint)")
print("Providers: \(searchProviders.count)")
print("Cache enabled: \(searchCache != nil)")
```

## 3. Possible Solutions and Workarounds

### Solution 0: CRITICAL - Check Provider Availability

**Most Common Issue**: No search providers are available

**Diagnosis:**
```swift
// Check in Xcode debugger or add logging:
print("Available providers: \(viewModel.searchProviders.count)")
print("Provider IDs: \(viewModel.searchProviders.map { $0.id })")
```

**Symptoms:**
- Search completes immediately with "No results found"
- No error message about missing providers
- Status shows "Searching..." then "No results found" instantly

**Root Cause:**
- `UnifiedSearchManager.searchModernProviders()` silently returns empty array when no providers available
- No validation check before search execution

**Fix:**
1. Go to Settings → API Keys
2. Set at least one API key (TMDB recommended)
3. Restart app or reload settings
4. Verify provider appears in Settings → Search Provider Preferences

**Code Location:**
- `App/Controllers/UnifiedSearchManager.swift` line 83-102: `searchModernProviders`
- Missing validation for empty provider list

### Solution 1: Ensure Search Fields Are Populated

**Problem**: Auto-population only fills empty fields
**Workaround**: Manually enter search terms if auto-population fails

**Code Fix** (if needed):
```swift
// In loadMetadataFromFile, force populate even if fields have content
if let metadata = metadata {
    self.searchTitle = metadata.title  // Remove isEmpty check
    // ... etc
}
```

### Solution 2: Verify Provider Configuration

**Checklist:**
- [ ] TMDB API key set in Settings
- [ ] TVDB API key set in Settings (if using TVDB)
- [ ] At least one provider available
- [ ] Adult content enabled if needed

**Code Location**: `App/Controllers/ViewModels.swift` line 1013-1050

### Solution 3: Clear Search Cache

**If caching is causing issues:**
```swift
// Temporarily disable cache
let manager = UnifiedSearchManager(
    modernProviders: searchProviders,
    includeAdult: adultEnabled,
    searchCache: nil,  // Disable cache
    providerWeights: currentSettings.providerWeights
)
```

### Solution 4: Check Provider Weights

**Issue**: Extreme weights (0.0) may filter out all results
**Fix**: Reset provider weights to defaults (1.0) in Settings

### Solution 5: Manual Search Trigger

**Workaround**: If auto-search desired, add:
```swift
// After loadMetadataFromFile completes
if !searchTitle.isEmpty {
    Task {
        await runSearch(query: searchTitle, yearHint: yearHint)
    }
}
```

### Solution 6: Add Provider Validation (Code Fix)

**Recommended Code Enhancement:**

Add validation in `UnifiedSearchManager.search()`:
```swift
// In UnifiedSearchManager.swift, before searching
let filteredProviders = modernProviders.filter { includeAdult || !$0.isAdult }
guard !filteredProviders.isEmpty else {
    throw SearchError.noProvidersAvailable
}
```

Add error case:
```swift
public enum SearchError: LocalizedError {
    case providerNotFound(String)
    case noProvidersAvailable
    
    public var errorDescription: String? {
        switch self {
        case .providerNotFound(let name):
            return "Search provider '\(name)' not found"
        case .noProvidersAvailable:
            return "No search providers available. Please configure API keys in Settings."
        }
    }
}
```

This will provide clear feedback when no providers are configured.

## 4. Best Practices for Robust Search Implementation

### 4.1 Input Validation

**Current Implementation:**
```swift
// ✅ Good: Validates query before search
guard !query.isEmpty else {
    status = "Please enter at least one search field"
    return
}
```

**Enhancement Suggestions:**
- Validate query length (min 2 characters)
- Sanitize input (remove special characters if needed)
- Provide helpful error messages

### 4.2 Error Handling

**Current Implementation:**
```swift
// ✅ Good: Catches and displays errors
catch {
    await MainActor.run {
        self.status = "Search failed: \(error.localizedDescription)"
        self.searchResults = []
    }
}
```

**Enhancement Suggestions:**
- Categorize errors (network, provider, validation)
- Provide retry mechanisms
- Log errors for debugging

### 4.3 Async Task Management

**Current Implementation:**
```swift
// ✅ Good: Uses Task for async operations
Task { await runSearch(query: query, yearHint: yearHint) }
```

**Enhancement Suggestions:**
- Cancel previous searches when new one starts
- Show loading indicators
- Prevent multiple simultaneous searches

### 4.4 Cache Management

**Best Practices:**
- Use normalized cache keys (already implemented)
- Implement cache size limits (already implemented: 100 entries)
- Clear cache on provider/weight changes
- Consider cache expiration for stale results

### 4.5 User Feedback

**Current Implementation:**
- Status messages show progress
- Results count displayed
- Loading states shown

**Enhancement Suggestions:**
- Progress indicators for long searches
- Estimated time remaining
- Search history/autocomplete

## 5. Monitoring and Maintenance Recommendations

### 5.1 Logging Strategy

**Add Structured Logging:**
```swift
// In runSearch()
await statusStream.add("Search started: query='\(query)', providers=\(providers.count)")
await statusStream.add("Search completed: \(results.count) results in \(duration)ms")
```

**Log Levels:**
- **Info**: Search initiated, completed
- **Warning**: Empty results, slow searches
- **Error**: Provider failures, network errors

### 5.2 Metrics to Track

1. **Search Success Rate**: % of searches returning results
2. **Average Response Time**: Time from click to results
3. **Provider Performance**: Success rate per provider
4. **Cache Hit Rate**: % of searches served from cache
5. **Error Frequency**: Types and frequency of errors

### 5.3 Health Checks

**Implement Provider Health Monitoring:**
```swift
func checkProviderHealth() async -> [String: Bool] {
    var health: [String: Bool] = [:]
    for provider in searchProviders {
        // Quick test search
        do {
            _ = try await provider.search(query: "test")
            health[provider.id] = true
        } catch {
            health[provider.id] = false
        }
    }
    return health
}
```

### 5.4 Regular Maintenance Tasks

**Weekly:**
- Review error logs
- Check provider API status
- Verify cache performance

**Monthly:**
- Update provider SDKs/APIs
- Review and optimize cache size
- Analyze search patterns

**Quarterly:**
- Review and update provider weights based on usage
- Optimize search algorithms
- Update documentation

## 6. Quick Diagnostic Checklist

Use this checklist when troubleshooting:

- [ ] File dropped successfully (sidebar shows file)
- [ ] Metadata extracted (sidebar shows metadata)
- [ ] Search fields populated (at least Title field)
- [ ] Search button enabled and clickable
- [ ] Status message changes when clicking Search
- [ ] At least one provider configured (Settings → API Keys)
- [ ] Network connection active
- [ ] No console errors in Xcode
- [ ] Cache cleared (if suspecting cache issues)
- [ ] Provider weights at default (1.0) or reasonable values

## 7. Common Issues and Fixes

### Issue: "No results found" but query is valid

**Possible Causes:**
1. Provider API keys invalid/expired
2. Network connectivity issues
3. Provider service down
4. Query too specific

**Fixes:**
1. Verify API keys in Settings
2. Test network connection
3. Check provider status pages
4. Try simpler/broader query

### Issue: Search button does nothing

**Possible Causes:**
1. Query validation failing silently
2. Button action not connected
3. Task cancelled immediately
4. UI state issue

**Fixes:**
1. Check status message for validation errors
2. Verify button action in AdvancedSearchView
3. Check for task cancellation
4. Restart app to reset UI state

### Issue: Results appear but are wrong

**Possible Causes:**
1. Provider weights too high/low
2. Cache serving stale results
3. Search type incorrect (movie vs TV)

**Fixes:**
1. Reset provider weights to 1.0
2. Clear search cache
3. Verify search type detection logic

## 8. Code References

**Key Files:**
- `App/Views/AdvancedSearchView.swift` - UI and file drop handling
- `App/Controllers/ViewModels.swift` - Search logic and state management
- `App/Controllers/UnifiedSearchManager.swift` - Search execution
- `App/Controllers/SearchCacheManager.swift` - Caching implementation
- `App/Controllers/MetadataManager.swift` - Provider weights configuration

**Key Methods:**
- `handleDrop()` - File drop handler
- `loadMetadataFromFile()` - Metadata extraction
- `runAdvancedSearch()` - Search trigger
- `runSearch()` - Search execution
- `search()` - UnifiedSearchManager search

## 9. Testing Recommendations

### Unit Tests Needed:
1. Query building from search fields
2. Cache key generation and normalization
3. Provider weight application
4. Result sorting with weights

### Integration Tests Needed:
1. File drop → metadata extraction → search
2. Search with multiple providers
3. Cache hit/miss scenarios
4. Error handling and recovery

### Manual Test Scenarios:
1. Drop file → Auto-populate → Search
2. Drop file → Modify fields → Search
3. Drop file → Clear fields → Manual entry → Search
4. Search with no providers configured
5. Search with network disabled
6. Search with invalid API keys

## 10. Emergency Workaround

If search completely fails, users can:
1. Manually enter search terms in Title field
2. Use basic search (if available) instead of advanced
3. Export file metadata and search externally
4. Check Settings → API Keys configuration
5. Restart application to reset state

---

**Last Updated**: Based on codebase analysis of SublerPlus v0.3.8b
**Related Documentation**: `docs/SEARCH_REFACTORING.md`, `docs/TROUBLESHOOTING.md`

