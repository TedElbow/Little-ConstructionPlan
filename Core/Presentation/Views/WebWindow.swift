import SwiftUI

/// Fullscreen wrapper view for displaying web content using WebViewScreen.
struct WebWindow: View {
    /// URL to display in the web window.
    let url: URL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            WebViewScreen(url: url)
        }
        // Let WKWebView handle focused-field scrolling; avoid stacking SwiftUI keyboard safe-area shrink
        // with extra UIScrollView insets (caused visible jumps, especially in landscape).
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
