import SwiftUI
import SublerPlusCore

struct FileDetailView: View {
    let file: URL
    let details: MetadataDetails?
    let job: Job?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(file.deletingPathExtension().lastPathComponent)
                .font(.title2)
                .accessibilityLabel("Selected file \(file.lastPathComponent)")
            Text(file.path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let job {
                HStack {
                    Label(job.status.rawValue.capitalized, systemImage: statusIcon(for: job.status))
                        .foregroundColor(color(for: job.status))
                    Text(job.message).font(.caption).foregroundColor(.secondary)
                }
                .accessibilityLabel("Job status \(job.status.rawValue)")
            }

            if let details {
                Divider()
                if let url = details.coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 160, height: 90)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 260)
                                .cornerRadius(6)
                                .shadow(radius: 2)
                        case .failure:
                            Image(systemName: "photo")
                                .frame(width: 160, height: 90)
                                .foregroundColor(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                Text(details.title).font(.headline)
                if let synopsis = details.synopsis {
                    Text(synopsis).font(.body)
                }
                if let studio = details.studio {
                    Text("Studio: \(studio)").font(.callout)
                }
                if !details.performers.isEmpty {
                    Text("Performers: \(details.performers.joined(separator: ", "))").font(.callout)
                }
                if !details.tags.isEmpty {
                    Text("Tags: \(details.tags.joined(separator: ", "))").font(.callout)
                }
                if let source = details.source {
                    Text("Provider: \(source)").font(.caption).foregroundColor(.secondary)
                }
            } else {
                Text("No metadata written yet. Enrich this file to see details.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func color(for status: Job.Status) -> Color {
        switch status {
        case .queued: return .secondary
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .red
        }
    }

    private func statusIcon(for status: Job.Status) -> String {
        switch status {
        case .queued: return "clock"
        case .running: return "arrow.clockwise"
        case .succeeded: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }
}

