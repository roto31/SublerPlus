import SwiftUI
import WebKit

struct WebContentView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Disable magnification/bounce and limit to local content
        config.allowsAirPlayForMediaPlayback = false
        config.suppressesIncrementalRendering = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // reduce transparency if enabled
        if let url = URL(string: "http://127.0.0.1:8080/") {
            webView.load(URLRequest(url: url))
        }
        webView.setAccessibilityLabel("Embedded Web UI")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // no-op; content is driven by the local server
    }
}

