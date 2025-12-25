import SwiftUI
import SublerPlusCore

struct AdvancedSearchView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Search")
                .font(.title2)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Title")
                    TextField("Title or keywords", text: $viewModel.searchTitle)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Studio/Network")
                    TextField("Studio or network", text: $viewModel.searchStudio)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Year")
                    HStack {
                        TextField("From", text: $viewModel.searchYearFrom)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("to")
                        TextField("To", text: $viewModel.searchYearTo)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                GridRow {
                    Text("Actors/Actresses")
                    TextField("Comma-separated", text: $viewModel.searchActors)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Directors/Producers")
                    TextField("Comma-separated", text: $viewModel.searchDirectors)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Rough Air Date (TV)")
                    TextField("YYYY-MM-DD", text: $viewModel.searchAirDate)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                Button("Search") { viewModel.runAdvancedSearch() }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                Spacer()
                Picker("Provider weighting", selection: $viewModel.providerPreference) {
                    Text("Balanced").tag(AppViewModel.ProviderPreference.balanced)
                    Text("Score-first").tag(.scoreFirst)
                    Text("Year-first").tag(.yearFirst)
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }

            Divider()

            List(viewModel.searchResults, id: \.id) { result in
                VStack(alignment: .leading) {
                    Text(result.title)
                        .font(.headline)
                    if let year = result.year {
                        Text("Year: \(year)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let score = result.score {
                        Text(String(format: "Score: %.2f", score))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .animation(reduceMotion ? nil : .default, value: viewModel.searchResults.count)
    }
}

