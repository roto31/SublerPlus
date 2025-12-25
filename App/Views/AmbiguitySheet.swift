import SwiftUI
import SublerPlusCore

struct AmbiguitySheet: View {
    let match: AmbiguousMatch?
    let onSelect: (MetadataDetails) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select the correct match")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let file = match?.file {
                Text(file.lastPathComponent)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("File \(file.lastPathComponent)")
            }
            if let choices = match?.choices {
                List(choices, id: \.id) { choice in
                    Button {
                        onSelect(choice)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
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
                    .accessibilityHint("Select this match")
                }
                .frame(minHeight: 240)
            } else {
                Text("No choices available.")
            }
            HStack {
                Spacer()
                Button("Close") {
                    // handled by parent binding
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 320)
    }
}

