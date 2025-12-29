import SwiftUI
import SublerPlusCore

// MARK: - SearchResultsList (Equatable for performance)

struct SearchResultsList: View, Equatable {
    let results: [MetadataResult]
    @Binding var selectedResult: MetadataResult?
    
    var body: some View {
        List(selection: $selectedResult) {
            ForEach(results, id: \.id) { result in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(result.title)
                            .font(.headline)
                        Spacer()
                        if let mediaType = result.mediaType {
                            Text(mediaType)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(mediaType == "TV show" ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    HStack {
                        if let year = result.year {
                            Text("Year: \(year)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let score = result.score {
                            Text("Score: \(String(format: "%.2f", score))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let source = result.source {
                        Text("Source: \(source)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .tag(result)
            }
        }
        .frame(minHeight: 200)
    }
    
    static func == (lhs: SearchResultsList, rhs: SearchResultsList) -> Bool {
        lhs.results == rhs.results && lhs.selectedResult?.id == rhs.selectedResult?.id
    }
}

struct AdvancedSearchView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDraggingOver = false

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                HSplitView {
                    // Main content area
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Advanced Search")
                            .font(.title2)
                            .accessibilityAddTraits(.isHeader)
                        
                        // Drag indicator when no file is loaded
                        if viewModel.droppedFile == nil {
                            HStack {
                                Image(systemName: "arrow.down.doc")
                                    .foregroundColor(.secondary)
                                    .font(.title2)
                                Text("Drag and drop a media file here to load its metadata")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 80)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                            .background(isDraggingOver ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isDraggingOver ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                        }
                        
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                            GridRow {
                                Text("Title")
                                    .accessibilityLabel("Title")
                                TextField("Title or keywords", text: $viewModel.searchTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Title or keywords")
                                    .accessibilityHint("Enter title or keywords to search for")
                            }
                            GridRow {
                                Text("Studio/Network")
                                    .accessibilityLabel("Studio or Network")
                                TextField("Studio or network", text: $viewModel.searchStudio)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Studio or network")
                                    .accessibilityHint("Enter studio or network name")
                            }
                            GridRow {
                                Text("Year")
                                    .accessibilityLabel("Year range")
                                HStack {
                                    TextField("From", text: $viewModel.searchYearFrom)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .accessibilityLabel("Year from")
                                        .accessibilityHint("Start year for search range")
                                    Text("to")
                                        .accessibilityLabel("to")
                                    TextField("To", text: $viewModel.searchYearTo)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .accessibilityLabel("Year to")
                                        .accessibilityHint("End year for search range")
                                }
                            }
                            GridRow {
                                Text("Actors/Actresses")
                                    .accessibilityLabel("Actors or Actresses")
                                TextField("Comma-separated", text: $viewModel.searchActors)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Actors or actresses")
                                    .accessibilityHint("Enter comma-separated list of actors")
                            }
                            GridRow {
                                Text("Directors/Producers")
                                    .accessibilityLabel("Directors or Producers")
                                TextField("Comma-separated", text: $viewModel.searchDirectors)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Directors or producers")
                                    .accessibilityHint("Enter comma-separated list of directors or producers")
                            }
                            GridRow {
                                Text("Rough Air Date (TV)")
                                    .accessibilityLabel("Rough Air Date for TV")
                                TextField("YYYY-MM-DD", text: $viewModel.searchAirDate)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Rough air date")
                                    .accessibilityHint("Enter approximate air date in YYYY-MM-DD format")
                            }
                        }
                        advancedFooter
                    }
                    .frame(minWidth: 400)
                    
                    // Sidebar for file metadata
                    if viewModel.droppedFile != nil {
                        fileMetadataSidebar
                            .frame(minWidth: 250, maxWidth: 350)
                    }
                }
            } else {
                Form {
                    Section("Keywords") {
                        TextField("Title", text: $viewModel.searchTitle)
                        TextField("Studio / Network", text: $viewModel.searchStudio)
                        HStack {
                            TextField("Year from", text: $viewModel.searchYearFrom)
                            TextField("to", text: $viewModel.searchYearTo)
                        }
                        TextField("Actors", text: $viewModel.searchActors)
                        TextField("Directors", text: $viewModel.searchDirectors)
                        TextField("Air date", text: $viewModel.searchAirDate)
                    }
                    Section {
                        advancedFooter
                    }
                }
            }
        }
        .padding()
        .animation(reduceMotion ? nil : .default, value: viewModel.searchResults.count)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDraggingOver ? Color.accentColor : Color.clear, lineWidth: 2)
                .padding(4)
                .allowsHitTesting(false)
        )
        .confirmationDialog(
            "Apply Metadata",
            isPresented: $viewModel.showApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Apply") {
                if let file = viewModel.droppedFile {
                    Task {
                        await viewModel.applySelectedMetadata(to: file)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let file = viewModel.droppedFile, let details = viewModel.selectedResultDetails {
                Text("Apply metadata to \(file.lastPathComponent)?\n\nTitle: \(details.title)\n\(details.studio.map { "Studio: \($0)\n" } ?? "")\(details.releaseDate.map { "Year: \(Calendar.current.component(.year, from: $0))\n" } ?? "")")
            } else {
                Text("Apply metadata to the selected file?")
            }
        }
    }
    
    @available(macOS 13.0, *)
    private var fileMetadataSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("File Metadata")
                .font(.title3)
                .fontWeight(.semibold)
            
            Divider()
            
            if let file = viewModel.droppedFile {
                // File name
                VStack(alignment: .leading, spacing: 4) {
                    Text("File:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(file.lastPathComponent)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                
                Divider()
                
                // Artwork
                if let artworkURL = viewModel.droppedFileArtworkURL {
                    AsyncImage(url: artworkURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .cornerRadius(8)
                }
                
                // Metadata fields
                if let metadata = viewModel.droppedFileMetadata {
                    VStack(alignment: .leading, spacing: 12) {
                        if !metadata.title.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Title:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(metadata.title)
                                    .font(.subheadline)
                            }
                        }
                        
                        if let studio = metadata.studio {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Studio:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(studio)
                                    .font(.subheadline)
                            }
                        }
                        
                        if let releaseDate = metadata.releaseDate {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Year:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(Calendar.current.component(.year, from: releaseDate)))
                                    .font(.subheadline)
                            }
                        }
                        
                        if !metadata.performers.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Performers:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(metadata.performers.joined(separator: ", "))
                                    .font(.subheadline)
                                    .lineLimit(3)
                            }
                        }
                        
                        if let synopsis = metadata.synopsis, !synopsis.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Synopsis:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ScrollView {
                                    Text(synopsis)
                                        .font(.subheadline)
                                }
                                .frame(maxHeight: 100)
                            }
                        }
                        
                        if let show = metadata.show {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TV Show:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(show)
                                    .font(.subheadline)
                            }
                            
                            if let season = metadata.seasonNumber {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Season:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(season))
                                        .font(.subheadline)
                                }
                            }
                            
                            if let episode = metadata.episodeNumber {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Episode:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(episode))
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
    }
    
    @ViewBuilder
    private var artworkPickerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: {
                    viewModel.showArtworkPicker = false
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to Results")
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("Select Artwork")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Divider()
            
            ArtworkBrowserView { artworkURL in
                viewModel.pendingArtworkURL = artworkURL
                if let file = viewModel.droppedFile {
                    Task {
                        await viewModel.applyArtwork(to: file, artworkURL: artworkURL)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier("public.file-url") }
        guard !fileProviders.isEmpty, let provider = fileProviders.first else { return false }
        
        // Load the file URL asynchronously (using the same pattern as FileListView)
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            if let error = error {
                Task { @MainActor in
                    self.viewModel.status = "Error loading file: \(error.localizedDescription)"
                }
                return
            }
            
            var fileURL: URL?
            
            // Try different ways to extract the URL
            if let url = item as? URL {
                fileURL = url
            } else if let data = item as? Data {
                // Try to create URL from data representation
                fileURL = URL(dataRepresentation: data, relativeTo: nil)
                
                // If that fails, try to decode as string (file path)
                if fileURL == nil || !fileURL!.isFileURL {
                    if let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                        // Remove file:// prefix if present
                        let cleanString = string.hasPrefix("file://") ? String(string.dropFirst(7)) : string
                        fileURL = URL(fileURLWithPath: cleanString)
                    }
                }
            } else if let string = item as? String {
                // Remove file:// prefix if present
                let cleanString = string.hasPrefix("file://") ? String(string.dropFirst(7)) : string
                fileURL = URL(fileURLWithPath: cleanString)
            }
            
            guard let url = fileURL else {
                Task { @MainActor in
                    self.viewModel.status = "Could not extract file URL from dropped item"
                }
                return
            }
            
            // Process the dropped file
            self.processDroppedFile(url: url)
        }
        
        return true
    }
    
    private func processDroppedFile(url: URL) {
        // Ensure it's a file URL (not a web URL)
        guard url.isFileURL else {
            Task { @MainActor in
                viewModel.status = "Only local files are supported"
            }
            return
        }
        
        // Resolve symlinks and get the actual file path
        let resolvedURL = url.resolvingSymlinksInPath()
        
        // Validate file exists
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            Task { @MainActor in
                viewModel.status = "File not found: \(resolvedURL.lastPathComponent)"
            }
            return
        }
        
        // Validate file type
        let ext = resolvedURL.pathExtension.lowercased()
        guard ["mp4", "m4v", "m4a", "mov", "mkv"].contains(ext) else {
            Task { @MainActor in
                viewModel.status = "Unsupported file type: \(ext). Supported: MP4, M4V, M4A, MOV, MKV"
            }
            return
        }
        
        // Load metadata from file
        Task {
            await viewModel.loadMetadataFromFile(resolvedURL)
        }
    }

    private var advancedFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    viewModel.runAdvancedSearch()
                }) {
                    HStack {
                        if viewModel.isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                                .accessibilityLabel("Searching")
                        }
                        Text(viewModel.isSearching ? "Searching..." : "Search")
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSearching)
                .accessibilityLabel(viewModel.isSearching ? "Searching" : "Search")
                .accessibilityHint("Search metadata providers with the entered criteria")
                Spacer()
                Picker("Provider weighting", selection: $viewModel.providerPreference) {
                    Text("Balanced").tag(ProviderPreference.balanced)
                    Text("Score-first").tag(ProviderPreference.scoreFirst)
                    Text("Year-first").tag(ProviderPreference.yearFirst)
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }

            Divider()

            if viewModel.showArtworkPicker {
                // Show artwork picker instead of results
                artworkPickerView
            } else if viewModel.isSearching {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let error = viewModel.searchError {
                // Error state
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Search Failed")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        viewModel.runAdvancedSearch()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if viewModel.searchResults.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No results yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Click Search to find matches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                HStack(alignment: .top, spacing: 16) {
                    // Results list (using EquatableView for performance)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search Results")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        SearchResultsList(
                            results: viewModel.searchResults,
                            selectedResult: $viewModel.selectedSearchResult
                        )
                        .equatable()
                        .accessibilityLabel("Search results list")
                        .accessibilityHint("List of metadata search results. Use arrow keys to navigate, Enter to select.")
                    }
                    .frame(width: 300)

                    // Result details view
                    if let selectedResult = viewModel.selectedSearchResult {
                        resultDetailsView(for: selectedResult)
                            .frame(minWidth: 300)
                            .onChange(of: viewModel.selectedSearchResult?.id) { newID in
                                // Fetch details when selection changes
                                if let newID = newID, let result = viewModel.searchResults.first(where: { $0.id == newID }) {
                                    // Clear old details and fetch new ones
                                    viewModel.selectedResultDetails = nil
                                    Task {
                                        await viewModel.fetchResultDetails(for: result)
                                    }
                                }
                            }
                            .onAppear {
                                // Also handle initial selection (if onChange doesn't fire)
                                if viewModel.selectedResultDetails == nil {
                                    Task {
                                        await viewModel.fetchResultDetails(for: selectedResult)
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func resultDetailsView(for result: MetadataResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Result Details")
                    .font(.headline)
                Spacer()
                if let mediaType = result.mediaType {
                    Text(mediaType)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(mediaType == "TV show" ? Color.blue : Color.green)
                        .cornerRadius(6)
                }
            }
            
            Divider()
            
            if let details = viewModel.selectedResultDetails {
                // Show full metadata details
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(details.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        if let year = details.releaseDate.flatMap({ Calendar.current.component(.year, from: $0) }) {
                            Text("Year: \(year)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let studio = details.studio {
                            Text("Studio: \(studio)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let rating = details.rating {
                            Text("Rating: \(String(format: "%.1f", rating))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let synopsis = details.synopsis, !synopsis.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Synopsis:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(synopsis)
                                    .font(.subheadline)
                            }
                        }
                        
                        if !details.performers.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Performers:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(details.performers.joined(separator: ", "))
                                    .font(.subheadline)
                            }
                        }
                        
                        if let show = details.show {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TV Show: \(show)")
                                    .font(.subheadline)
                                if let season = details.seasonNumber {
                                    Text("Season: \(season)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let episode = details.episodeNumber {
                                    Text("Episode: \(episode)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if let coverURL = details.coverURL ?? result.coverURL {
                            AsyncImage(url: coverURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Apply button
                if viewModel.droppedFile != nil {
                    Button("Apply Metadata") {
                        viewModel.showApplyConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Apply metadata")
                    .accessibilityHint("Apply selected metadata to the dropped file")
                }
            } else {
                // Loading state
                VStack {
                    ProgressView()
                    Text("Loading details...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

