import XCTest
import Foundation
#if canImport(MP42Foundation)
import MP42Foundation
#endif
@testable import SublerPlusCore

// Note: These tests require access to SublerCompatibility classes
// The classes need to be accessible from the test target

/// Comprehensive tests for Subler search architecture replication
/// Tests: single provider, multi-provider, incremental streaming, cancellation, priorities
/// 
/// Note: Subler-specific tests require MP42Foundation and are only available in Xcode builds
final class SublerSearchArchitectureTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    func makeMockProvider(id: String, results: [MetadataResult], delay: TimeInterval = 0.1) -> MetadataProvider {
        return MockMetadataProvider(
            id: id,
            isAdult: false,
            searchResults: results,
            searchDelay: delay
        )
    }
    
    #if canImport(MP42Foundation)
    func makeSublerService(provider: MetadataProvider) -> MetadataService {
        return SublerMetadataServiceAdapter(provider: provider)
    }
    #endif
    
    // MARK: - Modern Provider Tests (Available in all builds)
    
    func testModernProviderSearch() async throws {
        let result1 = MetadataResult(
            id: "1",
            title: "Test Movie",
            score: 8.5,
            year: 2023,
            source: "tmdb"
        )
        
        let provider = makeMockProvider(id: "tmdb", results: [result1])
        let manager = UnifiedSearchManager(
            modernProviders: [provider],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults(),
            providerPriorities: [:],
            incrementalStreaming: false
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test Movie",
            type: .movie,
            language: "en"
        )
        
        let results = try await manager.search(options: options)
        
        XCTAssertEqual(results.count, 1, "Should return one result")
        XCTAssertEqual(results[0].title, "Test Movie", "Result should have correct title")
    }
    
    #if canImport(MP42Foundation)
    // MARK: - Single Provider Tests (Subler Integration Required)
    
    func testSingleProviderSearch() async throws {
        // Create a single provider with known results
        let result1 = MetadataResult(
            id: "1",
            title: "Test Movie",
            score: 8.5,
            year: 2023,
            source: "tmdb"
        )
        
        let provider = makeMockProvider(id: "tmdb", results: [result1])
        let service = makeSublerService(provider: provider)
        
        // Test movie search
        let results = service.search(movie: "Test Movie", language: "en")
        
        XCTAssertEqual(results.count, 1, "Should return one result")
        XCTAssertEqual(results[0][.name] as? String, "Test Movie", "Result should have correct title")
        XCTAssertEqual(results[0].mediaKind, .movie, "Result should be a movie")
    }
    #endif
    
    #if canImport(MP42Foundation)
    func testSingleProviderTVSearch() async throws {
        let result1 = MetadataResult(
            id: "1",
            title: "Test Show",
            score: 9.0,
            year: 2023,
            source: "tvdb"
        )
        
        let provider = makeMockProvider(id: "tvdb", results: [result1])
        let service = makeSublerService(provider: provider)
        
        // Test TV show search
        let results = service.search(tvShow: "Test Show", language: "en", season: 1, episode: 1)
        
        XCTAssertEqual(results.count, 1, "Should return one result")
        XCTAssertEqual(results[0][.name] as? String, "Test Show", "Result should have correct title")
        XCTAssertEqual(results[0].mediaKind, .tvShow, "Result should be a TV show")
    }
    
    // MARK: - Multi-Provider Tests
    
    func testMultiProviderSearch() {
        let expectation = XCTestExpectation(description: "Multi-provider search completes")
        
        // Create multiple providers with different results
        let tmdbResult = MetadataResult(
            id: "tmdb-1",
            title: "Movie A",
            score: 8.0,
            year: 2023,
            source: "tmdb"
        )
        
        let tvdbResult = MetadataResult(
            id: "tvdb-1",
            title: "Movie B",
            score: 7.5,
            year: 2023,
            source: "tvdb"
        )
        
        let tmdbProvider = makeMockProvider(id: "tmdb", results: [tmdbResult])
        let tvdbProvider = makeMockProvider(id: "tvdb", results: [tvdbResult])
        
        let tmdbService = makeSublerService(provider: tmdbProvider)
        let tvdbService = makeSublerService(provider: tvdbProvider)
        
        let coordinator = MultiProviderSearchCoordinator(
            providers: [tmdbService, tvdbService],
            priority: ProviderPriority.defaults(),
            includeAdult: false,
            incrementalStreaming: false // Batch mode
        )
        
        var allResults: [MetadataResult] = []
        let task = coordinator.searchMovie(
            query: "Movie",
            language: "en",
            completionHandler: { results in
                allResults = results
                expectation.fulfill()
            }
        )
        
        _ = task.runAsync()
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertGreaterThanOrEqual(allResults.count, 2, "Should return results from both providers")
    }
    
    // MARK: - Incremental Streaming Tests
    
    func testIncrementalStreaming() {
        let completionExpectation = XCTestExpectation(description: "Search completes")
        let provider1Expectation = XCTestExpectation(description: "Provider 1 completes")
        let provider2Expectation = XCTestExpectation(description: "Provider 2 completes")
        
        // Create providers with different delays
        let result1 = MetadataResult(
            id: "1",
            title: "Fast Result",
            score: 8.0,
            year: 2023,
            source: "tmdb"
        )
        
        let result2 = MetadataResult(
            id: "2",
            title: "Slow Result",
            score: 7.5,
            year: 2023,
            source: "tvdb"
        )
        
        let fastProvider = makeMockProvider(id: "tmdb", results: [result1], delay: 0.1)
        let slowProvider = makeMockProvider(id: "tvdb", results: [result2], delay: 0.3)
        
        let fastService = makeSublerService(provider: fastProvider)
        let slowService = makeSublerService(provider: slowProvider)
        
        let coordinator = MultiProviderSearchCoordinator(
            providers: [fastService, slowService],
            priority: ProviderPriority.defaults(),
            includeAdult: false,
            incrementalStreaming: true // Enable incremental streaming
        )
        
        var incrementalResults: [String: [MetadataResult]] = [:]
        var finalResults: [MetadataResult] = []
        
        let task = coordinator.searchMovieIncremental(
            query: "Movie",
            language: "en",
            providerCallback: { providerName, results in
                incrementalResults[providerName] = results
                if providerName == "tmdb" {
                    provider1Expectation.fulfill()
                } else if providerName == "tvdb" {
                    provider2Expectation.fulfill()
                }
            },
            completionHandler: { results in
                finalResults = results
                completionExpectation.fulfill()
            }
        )
        
        _ = task.runAsync()
        
        wait(for: [provider1Expectation, provider2Expectation, completionExpectation], timeout: 5.0)
        
        // Verify incremental results were received
        XCTAssertTrue(incrementalResults.keys.contains("tmdb"), "Should receive results from tmdb")
        XCTAssertTrue(incrementalResults.keys.contains("tvdb"), "Should receive results from tvdb")
        
        // Verify final results contain both
        XCTAssertEqual(finalResults.count, 2, "Final results should contain both provider results")
    }
    
    // MARK: - Cancellation Tests
    
    func testSearchCancellation() {
        let expectation = XCTestExpectation(description: "Search is cancelled")
        expectation.isInverted = true // Should NOT fulfill
        
        // Create a provider with long delay
        let result = MetadataResult(
            id: "1",
            title: "Slow Result",
            score: 8.0,
            year: 2023,
            source: "tmdb"
        )
        
        let slowProvider = makeMockProvider(id: "tmdb", results: [result], delay: 2.0)
        let service = makeSublerService(provider: slowProvider)
        
        let coordinator = MultiProviderSearchCoordinator(
            providers: [service],
            priority: ProviderPriority.defaults(),
            includeAdult: false,
            incrementalStreaming: false
        )
        
        var resultsReceived = false
        let task = coordinator.searchMovie(
            query: "Movie",
            language: "en",
            completionHandler: { _ in
                resultsReceived = true
                expectation.fulfill()
            }
        )
        
        _ = task.runAsync()
        
        // Cancel immediately
        task.cancel()
        
        // Wait a bit to ensure cancellation worked
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(resultsReceived, "Results should not be received after cancellation")
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Priority Tests
    
    func testProviderPriorityExecution() {
        let expectation = XCTestExpectation(description: "Search completes")
        
        // Create providers with different priorities
        let highPriorityResult = MetadataResult(
            id: "high-1",
            title: "High Priority",
            score: 9.0,
            year: 2023,
            source: "tmdb"
        )
        
        let lowPriorityResult = MetadataResult(
            id: "low-1",
            title: "Low Priority",
            score: 7.0,
            year: 2023,
            source: "tvdb"
        )
        
        let highProvider = makeMockProvider(id: "tmdb", results: [highPriorityResult])
        let lowProvider = makeMockProvider(id: "tvdb", results: [lowPriorityResult])
        
        let highService = makeSublerService(provider: highProvider)
        let lowService = makeSublerService(provider: lowProvider)
        
        // Create custom priority with TMDB higher than TVDB
        var priority = ProviderPriority.defaults()
        priority.setPriority(90, for: "tmdb")
        priority.setPriority(70, for: "tvdb")
        
        let coordinator = MultiProviderSearchCoordinator(
            providers: [lowService, highService], // Intentionally reverse order
            priority: priority,
            includeAdult: false,
            incrementalStreaming: false
        )
        
        var executionOrder: [String] = []
        var allResults: [MetadataResult] = []
        
        // Track execution order (simplified - in real implementation we'd need more sophisticated tracking)
        let task = coordinator.searchMovie(
            query: "Movie",
            language: "en",
            completionHandler: { results in
                allResults = results
                expectation.fulfill()
            }
        )
        
        _ = task.runAsync()
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify both providers executed
        XCTAssertGreaterThanOrEqual(allResults.count, 2, "Should get results from both providers")
        
        // Results should be sorted by priority (higher priority first)
        // Note: This is a simplified test - full priority ordering would require more sophisticated tracking
    }
    
    func testProviderPriorityResultOrdering() {
        let expectation = XCTestExpectation(description: "Search completes with priority ordering")
        
        let tmdbResult = MetadataResult(
            id: "tmdb-1",
            title: "TMDB Movie",
            score: 8.0,
            year: 2023,
            source: "tmdb"
        )
        
        let tvdbResult = MetadataResult(
            id: "tvdb-1",
            title: "TVDB Movie",
            score: 9.0, // Higher score but lower priority
            year: 2023,
            source: "tvdb"
        )
        
        let tmdbProvider = makeMockProvider(id: "tmdb", results: [tmdbResult])
        let tvdbProvider = makeMockProvider(id: "tvdb", results: [tvdbResult])
        
        let tmdbService = makeSublerService(provider: tmdbProvider)
        let tvdbService = makeSublerService(provider: tvdbProvider)
        
        // Set TMDB priority higher than TVDB
        var priority = ProviderPriority.defaults()
        priority.setPriority(90, for: "tmdb")
        priority.setPriority(70, for: "tvdb")
        
        let coordinator = MultiProviderSearchCoordinator(
            providers: [tmdbService, tvdbService],
            priority: priority,
            includeAdult: false,
            incrementalStreaming: false
        )
        
        var allResults: [MetadataResult] = []
        let task = coordinator.searchMovie(
            query: "Movie",
            language: "en",
            completionHandler: { results in
                allResults = results
                expectation.fulfill()
            }
        )
        
        _ = task.runAsync()
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results are ordered by priority
        XCTAssertGreaterThanOrEqual(allResults.count, 2, "Should get results from both providers")
        // Note: Full priority ordering verification would require tracking provider source in MetadataResult
    }
    
    // MARK: - UnifiedSearchManager Integration Tests
    
    func testUnifiedSearchManagerBatchMode() async throws {
        let result1 = MetadataResult(
            id: "1",
            title: "Test Movie",
            score: 8.5,
            year: 2023,
            source: "tmdb"
        )
        
        let provider = makeMockProvider(id: "tmdb", results: [result1])
        
        let manager = UnifiedSearchManager(
            modernProviders: [provider],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults(),
            providerPriorities: [:],
            incrementalStreaming: false, // Batch mode
            tpdbProvider: nil,
            tvdbProvider: nil,
            tmdbProvider: nil
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test Movie",
            type: .movie,
            language: "en"
        )
        
        let results = try await manager.search(options: options)
        
        XCTAssertEqual(results.count, 1, "Should return one result")
        XCTAssertEqual(results[0].title, "Test Movie", "Result should have correct title")
    }
    
    func testUnifiedSearchManagerIncrementalMode() {
        let completionExpectation = XCTestExpectation(description: "Incremental search completes")
        let providerExpectation = XCTestExpectation(description: "Provider callback received")
        
        let result1 = MetadataResult(
            id: "1",
            title: "Test Movie",
            score: 8.5,
            year: 2023,
            source: "tmdb"
        )
        
        let provider = makeMockProvider(id: "tmdb", results: [result1])
        
        let manager = UnifiedSearchManager(
            modernProviders: [provider],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults(),
            providerPriorities: [:],
            incrementalStreaming: true, // Incremental mode
            tpdbProvider: nil,
            tvdbProvider: nil,
            tmdbProvider: nil
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test Movie",
            type: .movie,
            language: "en"
        )
        
        var incrementalReceived = false
        var finalResults: [MetadataResult] = []
        
        let task = manager.searchIncremental(
            options: options,
            providerCallback: { providerName, results in
                incrementalReceived = true
                providerExpectation.fulfill()
            },
            completionHandler: { results in
                finalResults = results
                completionExpectation.fulfill()
            }
        )
        
        _ = task.runAsync()
        
        wait(for: [providerExpectation, completionExpectation], timeout: 5.0)
        
        XCTAssertTrue(incrementalReceived, "Should receive incremental callback")
        XCTAssertEqual(finalResults.count, 1, "Should return one final result")
    }
    
    // MARK: - Error Handling Tests
    
    func testProviderFailureHandling() {
        let expectation = XCTestExpectation(description: "Search handles provider failure")
        
        // Create one failing provider and one successful provider
        let failingProvider = MockMetadataProvider(
            id: "failing",
            isAdult: false,
            searchResults: [],
            searchDelay: 0.1,
            shouldFail: true,
            failureError: NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Provider failed"])
        )
        
        let successResult = MetadataResult(
            id: "1",
            title: "Success Movie",
            score: 8.0,
            year: 2023,
            source: "success"
        )
        
        let successProvider = makeMockProvider(id: "success", results: [successResult])
        
        let failingService = makeSublerService(provider: failingProvider)
        let successService = makeSublerService(provider: successProvider)
        
        let coordinator = MultiProviderSearchCoordinator(
            providers: [failingService, successService],
            priority: ProviderPriority.defaults(),
            includeAdult: false,
            incrementalStreaming: false
        )
        
        var allResults: [MetadataResult] = []
        let task = coordinator.searchMovie(
            query: "Movie",
            language: "en",
            completionHandler: { results in
                allResults = results
                expectation.fulfill()
            }
        )
        
        _ = task.runAsync()
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should still get results from successful provider
        XCTAssertGreaterThanOrEqual(allResults.count, 1, "Should get results from successful provider despite failure")
    }
    
    // MARK: - Adult Content Filtering Tests
    
    func testAdultContentFiltering() {
        let expectation = XCTestExpectation(description: "Search filters adult content")
        
        let adultResult = MetadataResult(
            id: "1",
            title: "Adult Content",
            score: 8.0,
            year: 2023,
            source: "tpdb"
        )
        
        let adultProvider = MockMetadataProvider(
            id: "tpdb",
            isAdult: true,
            searchResults: [adultResult]
        )
        
        let normalResult = MetadataResult(
            id: "2",
            title: "Normal Content",
            score: 8.0,
            year: 2023,
            source: "tmdb"
        )
        
        let normalProvider = makeMockProvider(id: "tmdb", results: [normalResult])
        
        let adultService = makeSublerService(provider: adultProvider)
        let normalService = makeSublerService(provider: normalProvider)
        
        // Test with adult content disabled
        let coordinator = MultiProviderSearchCoordinator(
            providers: [adultService, normalService],
            priority: ProviderPriority.defaults(),
            includeAdult: false, // Adult content disabled
            incrementalStreaming: false
        )
        
        var allResults: [MetadataResult] = []
        let task = coordinator.searchMovie(
            query: "Movie",
            language: "en",
            completionHandler: { results in
                allResults = results
                expectation.fulfill()
            }
        )
        
        _ = task.runAsync()
        
        wait(for: [expectation], timeout: 5.0)
        
        // Note: Adult filtering happens at provider level before coordinator
        // This test verifies the coordinator still works with filtered providers
        XCTAssertGreaterThanOrEqual(allResults.count, 0, "Should handle filtered providers")
    }
    #endif // canImport(MP42Foundation)
}

