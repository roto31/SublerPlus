import SwiftUI
import WebKit

// WKWebView wrapper with pop-up blocking enabled
struct WebViewWithPopupBlocking: NSViewRepresentable {
    let url: URL?
    @Binding var isLoading: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        // Configure web view preferences to block pop-ups
        let configuration = WKWebViewConfiguration()
        // JavaScript is enabled by default in WKWebView
        
        // Create web view
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Block pop-ups by preventing new window creation
        webView.navigationDelegate = context.coordinator
        
        // Disable pop-ups in preferences
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = url, webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWithPopupBlocking
        
        init(_ parent: WebViewWithPopupBlocking) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        // Block pop-ups by preventing navigation to new windows
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Block navigation to new windows/tabs (pop-ups)
            if navigationAction.targetFrame == nil {
                // This is a request to open a new window - block it
                decisionHandler(.cancel)
                return
            }
            
            // Allow normal navigation
            decisionHandler(.allow)
        }
        
        // Additional pop-up blocking via JavaScript
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}

// UserScript to block pop-ups via JavaScript
extension WKWebViewConfiguration {
    static func withPopupBlocking() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Inject JavaScript to block window.open() calls
        let popupBlockingScript = """
            (function() {
                // Override window.open to block pop-ups
                const originalOpen = window.open;
                window.open = function() {
                    console.log('Popup blocked:', arguments);
                    return null;
                };
                
                // Block createPopup (legacy IE)
                if (window.createPopup) {
                    window.createPopup = function() {
                        console.log('createPopup blocked');
                        return null;
                    };
                }
                
                // Prevent alert, confirm, prompt if needed (optional - can be commented out)
                // window.alert = function() { console.log('Alert blocked:', arguments); };
                // window.confirm = function() { console.log('Confirm blocked:', arguments); return false; };
                // window.prompt = function() { console.log('Prompt blocked:', arguments); return null; };
            })();
        """
        
        let userScript = WKUserScript(source: popupBlockingScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)
        
        // Disable JavaScript pop-ups
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        return configuration
    }
}

// Enhanced WebView with stronger pop-up blocking
struct EnhancedWebViewWithPopupBlocking: NSViewRepresentable {
    let url: URL?
    @Binding var isLoading: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration.withPopupBlocking()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = url, webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EnhancedWebViewWithPopupBlocking
        
        init(_ parent: EnhancedWebViewWithPopupBlocking) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Block navigation to new windows (pop-ups)
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

