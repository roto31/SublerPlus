import SwiftUI
import SublerPlusCore

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        Form {
            Toggle("Enable adult metadata", isOn: $viewModel.adultEnabled)
            HStack {
                Text("TPDB API Key")
                SecureField("Key", text: $viewModel.tpdbKey)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Web UI Token (optional, recommended)")
                SecureField("Token", text: $viewModel.webToken)
                HStack {
                    Button("Generate Token") { viewModel.generateToken() }
                    Button("Mark Rotated") { viewModel.markRotatedNow() }
                }
                .buttonStyle(.bordered)
                Text(viewModel.keyRotationInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if viewModel.webToken.isEmpty {
                    Text("No token set. Localhost-only, but token reduces local misuse.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            VStack(alignment: .leading) {
                Text("TPDB Minimum Confidence: \(String(format: "%.2f", viewModel.tpdbConfidence))")
                Slider(value: $viewModel.tpdbConfidence, in: 0...1, step: 0.05)
            }
            Button("Clear Match Cache") {
                appViewModel.clearResolutionCache()
            }
            Button("Save") {
                viewModel.save()
            }
        }
        .padding()
    }
}

