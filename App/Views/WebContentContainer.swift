import SwiftUI
import WebKit

struct WebContentContainer: View {
    @StateObject private var model = WebViewModel()
    @State private var address: String = "http://127.0.0.1:8080/"
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    model.webView?.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!(model.canGoBack))

                Button {
                    model.webView?.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!(model.canGoForward))

                Button {
                    model.webView?.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }

                TextField("URL", text: $address, onCommit: loadAddress)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                    .focused($addressFocused)
                    .accessibilityLabel("Web UI address")
                    .accessibilityHint("Enter a local URL such as http://127.0.0.1:8080")
                    .onTapGesture { addressFocused = true }
            }
            .padding(8)
            .background(
                LinearGradient(colors: [Color.accentColor.opacity(0.12), Color.clear],
                               startPoint: .leading,
                               endPoint: .trailing)
            )

            WebContentView(model: model)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(model.$currentURL.compactMap { $0 }) { url in
            guard !addressFocused else { return } // don't overwrite while editing
            address = url.absoluteString
        }
    }

    private func loadAddress() {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), isAllowed(url) else {
            address = "http://127.0.0.1:8080/"
            if let defaultURL = URL(string: address) {
                model.webView?.load(URLRequest(url: defaultURL))
            }
            return
        }
        model.webView?.load(URLRequest(url: url))
    }

    private func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host?.lowercased()
        else { return false }
        return host == "127.0.0.1" || host == "localhost"
    }
}

final class WebViewModel: ObservableObject {
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var currentURL: URL?
    weak var webView: WKWebView?
}

