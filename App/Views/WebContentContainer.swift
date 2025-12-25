import SwiftUI
import WebKit

struct WebContentContainer: View {
    @StateObject private var model = WebViewModel()

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

                TextField("URL", text: .constant("http://127.0.0.1:8080/"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
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
    }
}

final class WebViewModel: ObservableObject {
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    weak var webView: WKWebView?
}

