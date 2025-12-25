import SwiftUI
import SublerPlusCore

struct AdvancedSearchView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var query: String = ""
    @State private var performer: String = ""
    @State private var year: String = ""
    @State private var studio: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Form {
            Section("Keywords") {
                TextField("Title", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Title")
                TextField("Performer", text: $performer)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Performer")
                TextField("Year", text: $year)
                    .textFieldStyle(.roundedBorder)
                    .onReceive(year.publisher.collect()) { newValue in
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if filtered != newValue {
                            self.year = String(filtered)
                        }
                    }
                    .accessibilityLabel("Year")
                TextField("Studio / Network", text: $studio)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Studio or Network")
            }
            Section {
                Button(action: {
                    let combined = [query, performer, studio, year].filter { !$0.isEmpty }.joined(separator: " ")
                    viewModel.searchAdultMetadata(for: combined)
                }) {
                    Text("Search")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(query.isEmpty && performer.isEmpty && studio.isEmpty && year.isEmpty)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .animation(reduceMotion ? nil : .default, value: query + performer + studio + year)
    }
}

