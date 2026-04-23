import Foundation

/// Protocol for types that can display web content (e.g. coordinator or screen builder).
/// Used by presentation layer to abstract WebView screen.
protocol WebViewDisplaying: AnyObject {
    /// Notifies that web content at the given URL should be displayed.
    func displayWebContent(url: URL)
}
