import SwiftUI
import AppKit
import SublerPlusCore

struct FileListView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedFile: URL?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            List(selection: $selectedFile) {
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
            .frame(minHeight: 320)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                viewModel.handleDrop(providers: providers)
            }
            .accessibilityLabel("File list")
            .accessibilityHint("Select a file to enrich or drop files to add")

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
        }
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

