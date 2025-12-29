import SwiftUI
import SublerPlusCore

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var dependencyManager = DependencyManager()
    @State private var showDependencyCheck = false

    var body: some View {
        TabView {
            // General Tab
            generalSettingsTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            // Providers Tab
            providersTab
                .tabItem {
                    Label("Providers", systemImage: "network")
                }
            
            // Output Tab
            outputTab
                .tabItem {
                    Label("Output", systemImage: "folder")
                }
            
            // Advanced Tab
            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showDependencyCheck) {
            DependencyCheckView {
                Task {
                    await dependencyManager.refreshCheck()
                }
            }
        }
        .onAppear {
            Task {
                await dependencyManager.refreshCheck()
            }
        }
    }
    
    // MARK: - Tab Views
    
    private var generalSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Dependency Status Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Dependencies")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("Check Dependencies") {
                            showDependencyCheck = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        .accessibilityLabel("Check dependencies")
                        .accessibilityHint("Verify that required external tools are installed")
                    }
                    
                    if let status = dependencyManager.dependencyStatus {
                        ForEach(status.dependencies) { dependency in
                            HStack {
                                Circle()
                                    .fill(statusColor(for: dependency.status))
                                    .frame(width: 8, height: 8)
                                    .accessibilityLabel("\(dependency.name) status: \(dependency.status == .installed ? "installed" : dependency.status == .outdated ? "outdated" : "missing")")
                                Text(dependency.name)
                                    .font(.caption)
                                    .accessibilityLabel("\(dependency.name)")
                                Spacer()
                                if let version = dependency.installedVersion {
                                    Text("v\(version)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .accessibilityLabel("Version \(version)")
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(dependency.name), \(dependency.status == .installed ? "installed" : dependency.status == .outdated ? "outdated" : "missing")\(dependency.installedVersion.map { ", version \($0)" } ?? "")")
                        }
                    } else {
                        Text("Checking dependencies...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Divider()
                Toggle("Enable adult metadata", isOn: $viewModel.adultEnabled)
                    .accessibilityLabel("Enable adult metadata")
                    .accessibilityHint("Enable metadata providers that may include adult content")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Settings")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Toggle("Incremental streaming (show results as providers complete)", isOn: $viewModel.incrementalStreamingEnabled)
                        .font(.caption)
                        .accessibilityLabel("Incremental streaming")
                        .accessibilityHint("Show search results as each provider completes")
                    Text("When enabled, search results appear as each provider completes. When disabled, all results appear at once.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Incremental streaming description")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Provider Priorities")
                        .font(.headline)
                    Text("Higher priority providers execute first and appear first in results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    // Provider priority controls would go here
                    // For now, we'll use defaults from ProviderPriority
                    Text("Default priorities: TMDB (80), TVDB (70), TPDB (60)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search Provider Preferences")
                        .font(.headline)
                    Text("Adjust boost factors for search providers. Higher values prioritize results from that provider.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let availableProviders = appViewModel.getAvailableProviders()
                    ForEach(availableProviders.sorted(), id: \.self) { providerID in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(providerID)
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f", viewModel.providerWeights[providerID] ?? 1.0))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            Slider(
                                value: Binding(
                                    get: { viewModel.providerWeights[providerID] ?? 1.0 },
                                    set: { viewModel.providerWeights[providerID] = $0 }
                                ),
                                in: 0.0...2.0,
                                step: 0.1
                            )
                            HStack {
                                Text("0.0 (disable)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("1.0 (default)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("2.0 (double)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if availableProviders.isEmpty {
                        Text("No providers available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("TPDB Minimum Confidence: \(String(format: "%.2f", viewModel.tpdbConfidence))")
                    Slider(value: $viewModel.tpdbConfidence, in: 0...1, step: 0.05)
                }
                
                HStack(spacing: 12) {
                    Button("Clear Match Cache") {
                        appViewModel.clearResolutionCache()
                    }
                    .accessibilityLabel("Clear match cache")
                    .accessibilityHint("Clear cached metadata match resolutions")
                    Button("Save") {
                        viewModel.save()
                        appViewModel.updateWatchFolders(viewModel.watchFolders)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Save settings")
                    .accessibilityHint("Save all settings changes")
                }
            }
            .padding(20)
            .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var providersTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TPDB API Key")
                        .accessibilityAddTraits(.isHeader)
                    SecureField("Key", text: $viewModel.tpdbKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("TPDB API Key")
                        .accessibilityHint("Enter your ThePornDB API key")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("TMDB API Key")
                        .accessibilityAddTraits(.isHeader)
                    SecureField("Key", text: $viewModel.tmdbKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("TMDB API Key")
                        .accessibilityHint("Enter your The Movie Database API key")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("TVDB API Key")
                        .accessibilityAddTraits(.isHeader)
                    SecureField("Key", text: $viewModel.tvdbKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("TVDB API Key")
                        .accessibilityHint("Enter your TheTVDB API key")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subtitles (OpenSubtitles API)")
                        .font(.headline)
                    SecureField("OpenSubtitles API Key", text: $viewModel.openSubtitlesKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("OpenSubtitles API Key")
                        .accessibilityHint("Enter your OpenSubtitles API key for subtitle lookup")
                    HStack {
                        Text("Default language:")
                            .accessibilityLabel("Default subtitle language")
                        TextField("eng", text: $viewModel.defaultSubtitleLanguage)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("Default subtitle language")
                            .accessibilityHint("ISO language code for subtitle search, e.g., eng for English")
                    }
                    .font(.caption)
                    Toggle("Automatically search and download subtitles after metadata enrichment", isOn: $viewModel.autoSubtitleLookup)
                        .font(.caption)
                        .accessibilityLabel("Automatically search and download subtitles")
                        .accessibilityHint("Enable automatic subtitle lookup after metadata enrichment")
                    Text("API key is stored in Keychain. Register at https://www.opensubtitles.com/ to get an API key. Language uses ISO codes (e.g., eng, spa).")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("iTunes & Music")
                        .font(.headline)
                    HStack {
                        Text("Default country:")
                        Picker("", selection: $viewModel.iTunesCountry) {
                            Text("United States").tag("us")
                            Text("United Kingdom").tag("gb")
                            Text("Canada").tag("ca")
                            Text("Australia").tag("au")
                            Text("Germany").tag("de")
                            Text("France").tag("fr")
                            Text("Japan").tag("jp")
                        }
                        .frame(width: 150)
                    }
                    .font(.caption)
                    Toggle("Prefer high-resolution artwork", isOn: $viewModel.preferHighResArtwork)
                        .font(.caption)
                    Toggle("Enable music metadata provider", isOn: $viewModel.enableMusicMetadata)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Musixmatch API Key (for lyrics)")
                            .font(.caption)
                        SecureField("Optional - for lyrics lookup", text: $viewModel.musixmatchKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Text("API key is stored in Keychain. Register at https://developer.musixmatch.com/ to get an API key.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var outputTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Retain originals (write output copy)", isOn: $viewModel.retainOriginals)
                    .accessibilityLabel("Retain originals")
                    .accessibilityHint("Keep original files and write enriched copies to output directory")
                HStack {
                    Text("Output folder:")
                        .accessibilityLabel("Output folder")
                    Text(viewModel.outputDirectory?.path ?? "Not set")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Output folder path: \(viewModel.outputDirectory?.path ?? "Not set")")
                    Spacer()
                    Button("Choose...") {
                        viewModel.pickOutputDirectory()
                    }
                    .accessibilityLabel("Choose output folder")
                    .accessibilityHint("Select folder for enriched file output")
                }
                Toggle("Generate NFO sidecar", isOn: $viewModel.generateNFO)
                    .accessibilityLabel("Generate NFO sidecar")
                    .accessibilityHint("Create NFO metadata files alongside media files")
                HStack {
                    Text("NFO folder:")
                        .accessibilityLabel("NFO folder")
                    Text(viewModel.nfoOutputDirectory?.path ?? "Same as media")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("NFO folder path: \(viewModel.nfoOutputDirectory?.path ?? "Same as media")")
                    Spacer()
                    Button("Choose...") {
                        viewModel.pickNFOOutputDirectory()
                    }
                    .accessibilityLabel("Choose NFO folder")
                    .accessibilityHint("Select folder for NFO file output")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("TV naming template")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    TokenField(tokens: $viewModel.tvNamingTokens, placeholder: "Enter pattern (e.g., {ShowName} - S{Season}E{Episode} - {Title})")
                        .frame(height: 28)
                        .accessibilityLabel("TV naming template")
                        .accessibilityHint("Enter filename pattern using tokens like {ShowName}, {Season}, {Episode}")
                    Text("Available tokens: {ShowName}, {Title}, {Season}, {Episode}, {Episode#}, {Year}")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Available tokens: ShowName, Title, Season, Episode, Episode#, Year")
                    // Show preview of generated filename
                    if !viewModel.tvNamingTokens.isEmpty {
                        Text("Preview: Breaking Bad - S01E02 - Cat's in the Bag")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                            .accessibilityLabel("Filename preview: Breaking Bad - S01E02 - Cat's in the Bag")
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Watch folders")
                        Spacer()
                        Button("Add Folder") {
                            viewModel.addWatchFolder()
                        }
                    }
                    if viewModel.watchFolders.isEmpty {
                        Text("No watch folders configured.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.watchFolders, id: \.self) { folder in
                            HStack {
                                Text(folder.path)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(role: .destructive) {
                                    viewModel.removeWatchFolder(folder)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .help("Remove folder from watch list")
                            }
                        }
                    }
                    Text("New media in these folders is auto-enqueued and processed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var advancedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Advanced Features (require dependencies)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Advanced Features")
                        .font(.headline)
                    
                    let ffmpegMissing = isFeatureDisabled(requiresDependency: "ffmpeg")
                    let tesseractMissing = isFeatureDisabled(requiresDependency: "tesseract")
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio/Video Conversion")
                            .font(.subheadline)
                            .foregroundColor(ffmpegMissing ? .secondary : .primary)
                        Text("Requires FFmpeg")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if ffmpegMissing {
                            Text("Install FFmpeg to enable: FLAC→AAC, MP3→AAC, advanced codec support")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(ffmpegMissing)
                    .opacity(ffmpegMissing ? 0.5 : 1.0)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subtitle OCR (PGS, VobSub)")
                            .font(.subheadline)
                            .foregroundColor(tesseractMissing ? .secondary : .primary)
                        Text("Requires Tesseract OCR (optional)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if tesseractMissing {
                            Text("Install Tesseract OCR to enable bitmap subtitle conversion")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .disabled(tesseractMissing)
                    .opacity(tesseractMissing ? 0.5 : 1.0)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Web UI Token")
                            .font(.headline)
                        Text("(REQUIRED)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                    SecureField("Token", text: $viewModel.webToken)
                        .textFieldStyle(.roundedBorder)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(viewModel.webToken.isEmpty ? Color.red : Color.clear, lineWidth: 1)
                        )
                        .accessibilityLabel("Web UI Token")
                        .accessibilityValue(viewModel.webToken.isEmpty ? "Empty, required" : "Set")
                        .accessibilityHint("Enter authentication token for Web UI access. This field is required.")
                    HStack {
                        Button("Generate Token") { viewModel.generateToken() }
                            .accessibilityLabel("Generate token")
                            .accessibilityHint("Generate a new Web UI authentication token")
                        Button("Mark Rotated") { viewModel.markRotatedNow() }
                            .accessibilityLabel("Mark token rotated")
                            .accessibilityHint("Mark the current token as rotated for security")
                    }
                    .buttonStyle(.bordered)
                    Text(viewModel.keyRotationInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if viewModel.webToken.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Token is REQUIRED for WebUI access", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("WebUI authentication is mandatory. Generate a token above to enable WebUI functionality.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    } else {
                        Label("Token is set. WebUI authentication enabled.", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    Divider()
                    Text("Shared Machine Authentication")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("For shared machines, use session tokens:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("1. Authenticate with main token to get session token from /api/session")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("2. Use X-Session-Token header for subsequent requests (expires in 1 hour)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Artwork")
                    HStack(spacing: 12) {
                        Button("Clear Artwork Cache") {
                            appViewModel.clearArtworkCache()
                        }
                        .accessibilityLabel("Clear artwork cache")
                        .accessibilityHint("Remove all cached artwork images")
                        Button("Refresh Artwork for Selection") {
                            if let url = appViewModel.selectedFile {
                                appViewModel.refreshArtwork(for: url)
                            }
                        }
                        .disabled(!appViewModel.hasSelection)
                        .accessibilityLabel("Refresh artwork for selection")
                        .accessibilityHint("Reload artwork for the currently selected file")
                    }
                    .buttonStyle(.bordered)
                    Text("Clears cached artwork downloads; refresh reloads the selected file's cover.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Helper Functions
    
    private func statusColor(for status: DependencyStatus) -> Color {
        switch status {
        case .installed: return .green
        case .outdated: return .yellow
        case .missing: return .red
        }
    }
    
    private func isFeatureDisabled(requiresDependency: String?) -> Bool {
        guard let depId = requiresDependency,
              let status = dependencyManager.dependencyStatus else {
            return false
        }
        if let dependency = status.dependencies.first(where: { $0.id == depId }) {
            return dependency.status == .missing
        }
        return false
    }
}

