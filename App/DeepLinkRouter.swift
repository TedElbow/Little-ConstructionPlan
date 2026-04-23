import Foundation
import Combine

/// Resolves incoming deep links into web URLs that can be opened by the app.
@MainActor
final class DeepLinkRouter: ObservableObject {
    enum ResolutionResult {
        case resolved(URL)
        case rejected(String)
    }

    @Published private(set) var pendingURL: URL?

    /// Accepts incoming URL and stores a resolved web URL for app-level routing.
    func handleIncomingURL(_ url: URL) -> ResolutionResult {
        let result = Self.resolveIncomingURLDetailed(url)
        if case .resolved(let resolvedURL) = result {
            pendingURL = resolvedURL
        }
        return result
    }

    func clearPendingURL() {
        pendingURL = nil
    }

    nonisolated static func resolveIncomingURL(_ incomingURL: URL) -> URL? {
        if case .resolved(let url) = resolveIncomingURLDetailed(incomingURL) {
            return url
        }
        return nil
    }

    nonisolated static func resolveIncomingURLDetailed(_ incomingURL: URL) -> ResolutionResult {
        guard let scheme = incomingURL.scheme?.lowercased() else {
            return .rejected("Unsupported deep link. Missing URL scheme: \(incomingURL.absoluteString)")
        }
        if scheme == "http" || scheme == "https" {
            return .resolved(incomingURL)
        }

        if let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            var firstValueByLowerName: [String: String] = [:]
            for item in queryItems {
                let lower = item.name.lowercased()
                if firstValueByLowerName[lower] == nil, let value = item.value {
                    firstValueByLowerName[lower] = value
                }
            }
            let orderedPriorityNames = [
                "url",
                "deep_link",
                "link",
                "target",
                "redirect",
                "browser_fallback_url",
                "fallback_url"
            ]
            for name in orderedPriorityNames {
                if let value = firstValueByLowerName[name],
                   let resolved = resolveWebURLCandidate(value) {
                    return .resolved(resolved)
                }
            }
            for item in queryItems {
                guard let value = item.value,
                      let resolved = resolveWebURLCandidate(value)
                else {
                    continue
                }
                return .resolved(resolved)
            }
        }

        let raw = incomingURL.absoluteString
        if let fallbackFromIntent = resolveBrowserFallbackFromIntent(raw) {
            return .resolved(fallbackFromIntent)
        }
        if let range = raw.range(of: "https://") ?? raw.range(of: "http://") {
            let candidate = String(raw[range.lowerBound...])
            if let resolved = resolveWebURLCandidate(candidate) {
                return .resolved(resolved)
            }
        }

        let host = incomingURL.host ?? "<nil>"
        return .rejected("Unsupported deep link. scheme=\(scheme), host=\(host), raw=\(incomingURL.absoluteString)")
    }

    nonisolated private static func resolveWebURLCandidate(_ candidate: String) -> URL? {
        let recursivelyDecoded = recursivelyDecodePercentEncoded(candidate)

        if let range = recursivelyDecoded.range(of: "https://") ?? recursivelyDecoded.range(of: "http://") {
            let normalized = String(recursivelyDecoded[range.lowerBound...])
            if let url = URL(string: normalized),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return url
            }
        }

        guard let url = URL(string: recursivelyDecoded),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }
        return url
    }

    nonisolated private static func recursivelyDecodePercentEncoded(_ value: String) -> String {
        var current = value
        for _ in 0..<4 {
            guard let decoded = current.removingPercentEncoding, decoded != current else {
                break
            }
            current = decoded
        }
        return current
    }

    nonisolated private static func resolveBrowserFallbackFromIntent(_ raw: String) -> URL? {
        guard let markerRange = raw.range(of: "S.browser_fallback_url=") else { return nil }
        let fallbackStart = markerRange.upperBound
        let tail = raw[fallbackStart...]
        let fallbackValue = tail.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return resolveWebURLCandidate(fallbackValue)
    }
}
