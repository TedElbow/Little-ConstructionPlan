import Foundation

/// Protocol for providing URL to load in WebView. Used by presentation layer to get target URL.
protocol WebContentProvidingProtocol: AnyObject {

    /// Returns the URL to display in WebView, if any.
    var currentURL: URL? { get }
}
