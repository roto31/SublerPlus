import SwiftUI
import SublerPlusCore

struct FileDetailView: View {
    let details: MetadataDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(details.title).font(.title2)
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
            Spacer()
        }
        .padding()
    }
}

