import SwiftUI
import SublerPlusCore

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var dependencyManager = DependencyManager()
    @State private var showDependencyCheck = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Dependency Status Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Dependencies")
                            .font(.headline)
                        Spacer()
                        Button("Check Dependencies") {
                            showDependencyCheck = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    
                    if let status = dependencyManager.dependencyStatus {
                        ForEach(status.dependencies) { dependency in
                            HStack {
                                Circle()
                                    .fill(statusColor(for: dependency.status))
                                    .frame(width: 8, height: 8)
                                Text(dependency.name)
                                    .font(.caption)
                                Spacer()
                                if let version = dependency.installedVersion {
                                    Text("v\(version)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Settings")
                        .font(.headline)
                    Toggle("Incremental streaming (show results as providers complete)", isOn: $viewModel.incrementalStreamingEnabled)
                        .font(.caption)
                    Text("When enabled, search results appear as each provider completes. When disabled, all results appear at once.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("TPDB API Key")
                    SecureField("Key", text: $viewModel.tpdbKey)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("TMDB API Key")
                    SecureField("Key", text: $viewModel.tmdbKey)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("TVDB API Key")
                    SecureField("Key", text: $viewModel.tvdbKey)
                        .textFieldStyle(.roundedBorder)
                }
                Toggle("Retain originals (write output copy)", isOn: $viewModel.retainOriginals)
                HStack {
                    Text("Output folder:")
                    Text(viewModel.outputDirectory?.path ?? "Not set")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Choose...") {
                        viewModel.pickOutputDirectory()
                    }
                }
                Toggle("Generate NFO sidecar", isOn: $viewModel.generateNFO)
                HStack {
                    Text("NFO folder:")
                    Text(viewModel.nfoOutputDirectory?.path ?? "Same as media")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Choose...") {
                        viewModel.pickNFOOutputDirectory()
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("TV naming template")
                    TextField("Template (e.g., S%02dE%02d - %t)", text: $viewModel.tvNamingTemplate)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subtitles (OpenSubtitles API)")
                        .font(.headline)
                    SecureField("OpenSubtitles API Key", text: $viewModel.openSubtitlesKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("Default language:")
                        TextField("eng", text: $viewModel.defaultSubtitleLanguage)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    .font(.caption)
                    Toggle("Automatically search and download subtitles after metadata enrichment", isOn: $viewModel.autoSubtitleLookup)
                        .font(.caption)
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
                    HStack {
                        Button("Generate Token") { viewModel.generateToken() }
                        Button("Mark Rotated") { viewModel.markRotatedNow() }
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
                        Button("Refresh Artwork for Selection") {
                            if let url = appViewModel.selectedFile {
                                appViewModel.refreshArtwork(for: url)
                            }
                        }
                        .disabled(!appViewModel.hasSelection)
                    }
                    .buttonStyle(.bordered)
                    Text("Clears cached artwork downloads; refresh reloads the selected file's cover.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("TPDB Minimum Confidence: \(String(format: "%.2f", viewModel.tpdbConfidence))")
                    Slider(value: $viewModel.tpdbConfidence, in: 0...1, step: 0.05)
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
                HStack(spacing: 12) {
                    Button("Clear Match Cache") {
                        appViewModel.clearResolutionCache()
                    }
                    Button("Save") {
                        viewModel.save()
                        appViewModel.updateWatchFolders(viewModel.watchFolders)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
            )
            .padding()
        }
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

