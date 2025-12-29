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
                            .accessibilityElement(children: .combine)
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
                        .accessibilityElement(children: .contain)
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
            .overlay {
                if viewModel.mediaFiles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray.and.arrow.down")
                            .foregroundColor(.secondary)
                        Text("Drop files here or use Add Files to begin.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }

                HStack(spacing: 12) {
                    Button {
                        viewModel.enqueueCurrentSelection()
                    } label: {
                        Label("Batch enqueue", systemImage: "text.append")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Batch enqueue")
                    .accessibilityHint("Queue the selected file or all files for batch processing")
                    Button {
                    Task { await viewModel.refreshJobs() }
                    } label: {
                        Label("Refresh Jobs", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Refresh jobs")
                    .accessibilityHint("Refresh the job queue status")
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
                    HStack {
                        Text("Jobs")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityHint("Queued, running, failed, and ambiguous jobs")
                        Spacer()
                        let stats = jobStats(viewModel.jobs)
                        if stats.total > 0 {
                            HStack(spacing: 8) {
                                if stats.queued > 0 {
                                    Label("\(stats.queued)", systemImage: "clock")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .accessibilityLabel("\(stats.queued) queued")
                                }
                                if stats.running > 0 {
                                    Label("\(stats.running)", systemImage: "arrow.clockwise")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .accessibilityLabel("\(stats.running) running")
                                }
                                if stats.succeeded > 0 {
                                    Label("\(stats.succeeded)", systemImage: "checkmark.circle")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .accessibilityLabel("\(stats.succeeded) succeeded")
                                }
                                if stats.failed > 0 {
                                    Label("\(stats.failed)", systemImage: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if viewModel.jobs.isEmpty {
                                Text("No jobs in queue")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else {
                                ForEach(viewModel.jobs, id: \.id) { job in
                                    HStack {
                                        statusIcon(for: job.status)
                                            .foregroundColor(color(for: job.status))
                                            .font(.caption)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(job.url.lastPathComponent)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                            Text(job.message)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        if job.status == .running {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Text(job.status.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundColor(color(for: job.status))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(color(for: job.status).opacity(0.2))
                                                .cornerRadius(4)
                                        }
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
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                                    .cornerRadius(6)
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
                    let tracks = viewModel.tracks(for: selected) ?? []
                    let chapters = viewModel.chapters(for: selected) ?? []
                    let subs = viewModel.subtitles(for: selected) ?? []
                    FileDetailView(
                        file: selected,
                        details: meta,
                        job: job,
                        onRefreshArtwork: {
                            viewModel.refreshArtwork(for: selected)
                        },
                        onApplyArtwork: { alt in
                            viewModel.applyArtwork(for: selected, to: alt)
                        },
                        tracks: tracks,
                        chapters: chapters,
                        subtitles: subs,
                        onSearchSubtitles: {
                            viewModel.searchSubtitles(for: selected)
                        },
                        onAttachSubtitle: { candidate in
                            viewModel.downloadAndAttachSubtitle(for: selected, candidate: candidate)
                        }
                    )
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
    
    private func statusIcon(for status: Job.Status) -> Image {
        switch status {
        case .queued: return Image(systemName: "clock")
        case .running: return Image(systemName: "arrow.clockwise")
        case .succeeded: return Image(systemName: "checkmark.circle.fill")
        case .failed: return Image(systemName: "exclamationmark.triangle.fill")
        }
    }
    
    private func jobStats(_ jobs: [Job]) -> (total: Int, queued: Int, running: Int, succeeded: Int, failed: Int) {
        let total = jobs.count
        let queued = jobs.filter { $0.status == .queued }.count
        let running = jobs.filter { $0.status == .running }.count
        let succeeded = jobs.filter { $0.status == .succeeded }.count
        let failed = jobs.filter { $0.status == .failed }.count
        return (total, queued, running, succeeded, failed)
    }
}

