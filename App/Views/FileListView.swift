import SwiftUI
import AppKit
import SublerPlusCore

struct FileListView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTargeted: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                List(selection: $viewModel.selectedFile) {
                    ForEach(viewModel.mediaFiles, id: \.self) { fileURL in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fileURL.deletingPathExtension().lastPathComponent)
                                    .font(.headline)
                                    .accessibilityLabel("File \(fileURL.deletingPathExtension().lastPathComponent)")
                                Text(fileURL.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button {
                                viewModel.enrich(file: fileURL)
                            } label: {
                                Label("Enrich", systemImage: "wand.and.stars")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Enrich \(fileURL.deletingPathExtension().lastPathComponent)")
                            .accessibilityHint("Apply metadata to this file")
                        }
                        .contentShape(Rectangle())
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 320, maxHeight: .infinity)
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    viewModel.handleDrop(providers: providers)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(isDropTargeted ? 0.85 : 0), style: StrokeStyle(lineWidth: 2, dash: [6]))
                )
                .overlay {
                    if isDropTargeted {
                        Label("Drop to add files", systemImage: "tray.and.arrow.down")
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .transition(.opacity)
                            .accessibilityLabel("Drop files to add them")
                    }
                }
                .accessibilityLabel("File list")
                .accessibilityHint("Select a file to enrich or drop files to add")

                HStack(spacing: 12) {
                    Button {
                        viewModel.enqueueCurrentSelection()
                    } label: {
                        Label("Batch enqueue", systemImage: "text.append")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Queue the selected file or all files for batch processing")
                    Button {
                    Task { await viewModel.refreshJobs() }
                    } label: {
                        Label("Refresh Jobs", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ScrollView {
                        Text(viewModel.status)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 60)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHint("Recent actions and events")
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.activityLines, id: \.self) { line in
                                Text(line)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(minHeight: 80)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Jobs")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHint("Queued, running, failed, and ambiguous jobs")
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(viewModel.jobs, id: \.id) { job in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(job.url.lastPathComponent)
                                            .font(.subheadline)
                                        Text(job.message)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(job.status.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundColor(color(for: job.status))
                                    if job.status == .failed {
                                        Button {
                                            viewModel.retryJob(id: job.id)
                                        } label: {
                                            Label("Retry", systemImage: "arrow.clockwise")
                                        }
                                        .buttonStyle(.bordered)
                                        .accessibilityHint("Retry this job")
                                    }
                                }
                            }
                        }
                    }
                    .frame(minHeight: 100)
                }

                if let pending = viewModel.pendingAmbiguity {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resolve Match")
                            .font(.headline)
                        Text(pending.file.lastPathComponent)
                            .font(.subheadline)
                        ForEach(pending.choices, id: \.id) { choice in
                            Button {
                                viewModel.resolveAmbiguity(choice: choice, for: pending)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(choice.title)
                                    if let year = choice.releaseDate.flatMap({ Calendar.current.dateComponents([.year], from: $0).year }) {
                                        Text("Year: \(year)").font(.caption).foregroundColor(.secondary)
                                    }
                                    if let studio = choice.studio {
                                        Text(studio).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(8)
                    .accessibilityElement(children: .combine)
                }
                
                if let selected = viewModel.selectedFile {
                    let meta = viewModel.fileMetadata[selected]
                    let job = viewModel.job(for: selected)
                    FileDetailView(file: selected, details: meta, job: job)
                        .accessibilityLabel("File details")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .padding()
        .animation(reduceMotion ? nil : .default, value: viewModel.mediaFiles)
        .animation(reduceMotion ? nil : .default, value: viewModel.status)
        .animation(reduceMotion ? nil : .default, value: viewModel.jobs)
    }

    private func color(for status: Job.Status) -> Color {
        switch status {
        case .queued: return .secondary
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .red
        }
    }
}

