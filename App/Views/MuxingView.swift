import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SublerPlusCore

struct MuxingView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedTracks: Set<UUID> = []
    @State private var outputURL: URL?
    @State private var showingSavePanel = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Muxing Options")
                .font(.title2)
            
            if let selectedFile = viewModel.selectedFile {
                Text("Source: \(selectedFile.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let tracks = viewModel.getTracks(for: selectedFile), !tracks.isEmpty {
                    Text("Select Tracks to Include")
                        .font(.headline)
                    
                    List {
                        ForEach(tracks) { track in
                            HStack {
                                Toggle("", isOn: Binding(
                                    get: { selectedTracks.contains(track.id) },
                                    set: { isOn in
                                        if isOn {
                                            selectedTracks.insert(track.id)
                                        } else {
                                            selectedTracks.remove(track.id)
                                        }
                                    }
                                ))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trackKindLabel(track.kind))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    if let codec = track.codec {
                                        Text("Codec: \(codec)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let lang = track.language {
                                        Text("Language: \(lang)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let resolution = track.resolution {
                                        Text("Resolution: \(resolution)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 300)
                }
                
                HStack {
                    Text("Output:")
                        .font(.headline)
                    Text(outputURL?.lastPathComponent ?? "Not set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Choose...") {
                        showingSavePanel = true
                    }
                    .buttonStyle(.bordered)
                }
                
                if viewModel.isMuxing {
                    ProgressView(value: viewModel.muxingProgress)
                    Text("Muxing in progress... \(Int(viewModel.muxingProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Button("Cancel") {
                        // Cancel muxing
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isMuxing)
                    
                    Spacer()
                    
                    Button("Start Muxing") {
                        if let selectedFile = viewModel.selectedFile,
                           let output = outputURL {
                            let tracks = viewModel.getTracks(for: selectedFile) ?? []
                            let trackSelections = tracks.filter { selectedTracks.contains($0.id) }.map { track in
                                TrackSelection(track: track, sourceURL: selectedFile, selected: true)
                            }
                            viewModel.muxTracks(trackSelections, outputURL: output)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedTracks.isEmpty || outputURL == nil || viewModel.isMuxing)
                }
            } else {
                Text("No file selected")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onChange(of: showingSavePanel) { isShowing in
            if isShowing {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.mpeg4Movie]
                panel.nameFieldStringValue = "output.mp4"
                if panel.runModal() == .OK, let url = panel.url {
                    outputURL = url
                }
                showingSavePanel = false
            }
        }
    }
    
    private func trackKindLabel(_ kind: MediaTrack.Kind) -> String {
        switch kind {
        case .video: return "Video"
        case .audio: return "Audio"
        case .subtitle: return "Subtitle"
        case .timecode: return "Timecode"
        case .metadata: return "Metadata"
        case .unknown: return "Unknown"
        }
    }
}

