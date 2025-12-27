import SwiftUI
import SublerPlusCore

struct ArtworkBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ArtworkBrowserViewModel()
    var onSelectArtwork: ((URL) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                TextField("Search for artwork...", text: $viewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await viewModel.search()
                        }
                    }
                
                Picker("Media Type", selection: $viewModel.selectedMediaType) {
                    ForEach(iTunesArtworkProvider.MediaType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .frame(width: 150)
                
                Picker("Country", selection: $viewModel.selectedCountry) {
                    Text("United States").tag("us")
                    Text("United Kingdom").tag("gb")
                    Text("Canada").tag("ca")
                    Text("Australia").tag("au")
                    Text("Germany").tag("de")
                    Text("France").tag("fr")
                    Text("Japan").tag("jp")
                }
                .frame(width: 120)
                
                Button("Search") {
                    Task {
                        await viewModel.search()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSearching)
            }
            .padding()
            
            Divider()
            
            // Results
            if viewModel.isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.results.isEmpty && !viewModel.searchQuery.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No results found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.results.isEmpty {
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Enter a search term to find artwork")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                    ], spacing: 16) {
                        ForEach(viewModel.results) { result in
                            ArtworkThumbnailView(result: result) {
                                if let highRes = result.artworkURLHighRes {
                                    onSelectArtwork?(highRes)
                                } else {
                                    onSelectArtwork?(result.artworkURL)
                                }
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(viewModel.results.count) result\(viewModel.results.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 800, height: 600)
    }
}

@MainActor
private class ArtworkBrowserViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var selectedMediaType: iTunesArtworkProvider.MediaType = .movie
    @Published var selectedCountry: String = "us"
    @Published var results: [ArtworkSearchResult] = []
    @Published var isSearching: Bool = false
    
    private let provider = iTunesArtworkProvider()
    
    func search() async {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            let searchResults = try await provider.search(
                query: searchQuery,
                mediaType: selectedMediaType,
                country: selectedCountry
            )
            results = searchResults.map { ArtworkSearchResult(from: $0) }
        } catch {
            // Handle error (could show alert)
            results = []
        }
    }
}

private struct ArtworkThumbnailView: View {
    let result: ArtworkSearchResult
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: result.artworkURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(8)
                        .shadow(radius: isHovered ? 8 : 2)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if let artist = result.artist {
                    Text(artist)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Button("Use This Artwork") {
                onSelect()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

