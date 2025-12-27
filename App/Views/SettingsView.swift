import SwiftUI
import SublerPlusCore

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable adult metadata", isOn: $viewModel.adultEnabled)
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
                    Text("Subtitles (OpenSubtitles via RapidAPI)")
                    SecureField("OpenSubtitles API Key", text: $viewModel.openSubtitlesKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("Default language:")
                        TextField("eng", text: $viewModel.defaultSubtitleLanguage)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    .font(.caption)
                    Text("Key is stored in Keychain. Language uses ISO codes (e.g., eng, spa).")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
    }
}

