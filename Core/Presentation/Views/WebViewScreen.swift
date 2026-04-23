import SwiftUI
import WebKit
import UIKit

/// SwiftUI wrapper for displaying web content using WKWebView with custom navigation handling.
/// Handles too many redirects, disables zoom, and opens target="_blank" links in the same view.
struct WebViewScreen: UIViewRepresentable {
    /// URL to load in the web view.
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(initialURL: url)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        if #available(iOS 15.0, *) {
            webView.underPageBackgroundColor = .black
        }
        print("WebViewScreen: load initial URL=\(url.absoluteString)")
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// Coordinator to handle WKWebView navigation delegate methods.
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let initialURL: URL
        private var lastKnownURL: URL?
        private var redirectRecoveryAttempts = 0

        init(initialURL: URL) {
            self.initialURL = initialURL
            self.lastKnownURL = initialURL
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if let currentURL = webView.url {
                lastKnownURL = currentURL
            }
            print("WebViewScreen: didStartProvisionalNavigation url=\(webView.url?.absoluteString ?? initialURL.absoluteString)")
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            if let redirectedURL = webView.url {
                lastKnownURL = redirectedURL
                print("WebViewScreen: didReceiveServerRedirect url=\(redirectedURL.absoluteString)")
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let requestURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let normalizedScheme = requestURL.scheme?.lowercased() ?? ""
            if normalizedScheme == "itms-appss" || normalizedScheme == "itms-apps" {
                if let fallbackURL = Self.appStoreHTTPSFallback(from: requestURL) {
                    print("WebViewScreen: map AppStore scheme to https url=\(fallbackURL.absoluteString)")
                    webView.load(URLRequest(url: fallbackURL))
                }
                decisionHandler(.cancel)
                return
            }
            if normalizedScheme == "http" || normalizedScheme == "https" || normalizedScheme == "about" || normalizedScheme == "data" {
                decisionHandler(.allow)
                return
            }
            let resolution = DeepLinkRouter.resolveIncomingURLDetailed(requestURL)
            if case .resolved(let resolvedURL) = resolution {
                print("WebViewScreen: resolved custom deeplink to web url=\(resolvedURL.absoluteString)")
                webView.load(URLRequest(url: resolvedURL))
            } else if case .rejected(let reason) = resolution {
                print("WebViewScreen: rejected custom deeplink reason=\(reason)")
                print("WebViewScreen: trying to open external custom deeplink url=\(requestURL.absoluteString)")
                UIApplication.shared.open(requestURL, options: [:]) { success in
                    if success {
                        print("WebViewScreen: external custom deeplink open success url=\(requestURL.absoluteString)")
                    } else {
                        print("WebViewScreen: external custom deeplink open failed url=\(requestURL.absoluteString)")
                    }
                }
            }
            decisionHandler(.cancel)
        }

        private static func appStoreHTTPSFallback(from url: URL) -> URL? {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            var mapped = components
            mapped.scheme = "https"
            return mapped.url
        }

        /// Handles error -1007 (too many redirects) by reloading the last known URL.
        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {

            let nsError = error as NSError
            print(
                "WebViewScreen: didFailProvisionalNavigation code=\(nsError.code), domain=\(nsError.domain), url=\(webView.url?.absoluteString ?? initialURL.absoluteString), error=\(error.localizedDescription)"
            )

            if nsError.domain == NSURLErrorDomain &&
                nsError.code == NSURLErrorHTTPTooManyRedirects {

                redirectRecoveryAttempts += 1
                print("WebViewScreen: too many redirects, recovery attempt=\(redirectRecoveryAttempts)")

                let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL
                let reloadURL = failingURL ?? webView.url ?? lastKnownURL ?? initialURL

                print("WebViewScreen: reload URL=\(reloadURL.absoluteString)")
                lastKnownURL = reloadURL
                webView.load(URLRequest(url: reloadURL))
            }
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            let nsError = error as NSError
            print(
                "WebViewScreen: didFail code=\(nsError.code), domain=\(nsError.domain), url=\(webView.url?.absoluteString ?? initialURL.absoluteString), error=\(error.localizedDescription)"
            )
        }

        /// Injects meta viewport to disable zoom after page finishes loading.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebViewScreen: didFinish url=\(webView.url?.absoluteString ?? initialURL.absoluteString)")
            let js = """
            var meta = document.querySelector('meta[name=viewport]');
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        /// Forces links with target="_blank" to open in the same web view.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {

            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
