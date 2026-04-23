import Foundation

/// Thread-safe registration of hosts for App Transport Security exception domains.
actor AppTransportSecurityHostRegistrar: AppTransportSecurityHostRegistrarProtocol {

    private let userDefaults: UserDefaults
    private let userDefaultsKey = "AppTransportSecurityHostRegistrar.registeredHosts"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func registerHostsFromConfigResponse(webURL: URL?, configRequestURL: URL?, expiresAt: Date?) async {
        let hosts = Self.collectHosts(webURL: webURL, configRequestURL: configRequestURL)
        guard !hosts.isEmpty else { return }

        var stored = Set(userDefaults.stringArray(forKey: userDefaultsKey) ?? [])
        let beforeCount = stored.count
        for host in hosts {
            stored.insert(host)
        }
        if stored.count != beforeCount {
            userDefaults.set(Array(stored).sorted(), forKey: userDefaultsKey)
        }

        for host in hosts {
            Self.mergeExceptionDomainIfPossible(host: host)
        }

        _ = expiresAt
    }

    /// Host strings suitable as `NSExceptionDomains` keys (lowercased, from `URL.host`).
    nonisolated static func collectHosts(webURL: URL?, configRequestURL: URL?) -> [String] {
        var result: [String] = []
        if let h = normalizedHost(from: webURL) {
            result.append(h)
        }
        if let h = normalizedHost(from: configRequestURL) {
            result.append(h)
        }
        return Array(Set(result))
    }

    nonisolated static func normalizedHost(from url: URL?) -> String? {
        guard let url else { return nil }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        return host
    }

    /// Best-effort in-process merge when the main bundle exposes a mutable info dictionary (not documented by Apple).
    nonisolated private static func mergeExceptionDomainIfPossible(host: String) {
        guard let info = Bundle.main.infoDictionary as? NSMutableDictionary else { return }

        let ats: NSMutableDictionary = {
            if let existing = info["NSAppTransportSecurity"] as? NSMutableDictionary {
                return existing
            }
            let created = NSMutableDictionary()
            info["NSAppTransportSecurity"] = created
            return created
        }()

        let domains: NSMutableDictionary = {
            if let existing = ats["NSExceptionDomains"] as? NSMutableDictionary {
                return existing
            }
            let created = NSMutableDictionary()
            ats["NSExceptionDomains"] = created
            return created
        }()

        if domains[host] != nil { return }

        domains[host] = [
            "NSExceptionAllowsInsecureHTTPLoads": true,
            "NSIncludesSubdomains": true
        ] as NSDictionary
    }
}
