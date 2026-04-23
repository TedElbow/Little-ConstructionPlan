import Foundation

/// Errors that can occur during server API communication.
enum ServerAPIRepositoryError: Error {
    /// Server URL is invalid.
    case invalidURL
    /// Request payload cannot be converted to JSON.
    case invalidPayload
    /// Request exceeded configured timeout.
    case timeout(TimeInterval)
    /// Transport-level error during the request.
    case transportError(Error)
    /// Server returned non-success HTTP status code.
    case httpError(statusCode: Int, body: String)
    /// Server response is invalid or unexpected.
    case invalidResponse(String)
    /// Server response did not match expected contract.
    case contractMismatch(String)
}

extension ServerAPIRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Server URL is invalid."
        case .invalidPayload:
            return "Request payload is not valid JSON."
        case .timeout(let timeout):
            return "Request timed out after \(timeout) seconds."
        case .transportError(let error):
            return "Transport error: \(error.localizedDescription)"
        case .httpError(let statusCode, _):
            return "HTTP error with status code \(statusCode)."
        case .invalidResponse(let description):
            return "Invalid response: \(description)"
        case .contractMismatch(let description):
            return "Response contract mismatch: \(description)"
        }
    }
}

private struct ServerAPIResponse: Decodable {
    let isSuccess: Bool?
    let urlKey: String?
    let urlString: String?
    let expiresRawValue: String?

    private enum CodingKeys: String, CodingKey {
        case ok
        case success
        case status
        case url
        case link
        case deepLink = "deep_link"
        case expires
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isSuccess = Self.decodeSuccessFlag(from: container)
        let urlCandidate = Self.decodeURLCandidate(from: container)
        urlKey = urlCandidate?.key
        urlString = urlCandidate?.value
        expiresRawValue = Self.decodeExpiresRawValue(from: container)
    }

    private static func decodeSuccessFlag(from container: KeyedDecodingContainer<CodingKeys>) -> Bool? {
        if let value = try? container.decodeIfPresent(Bool.self, forKey: .ok) {
            return value
        }
        if let value = try? container.decodeIfPresent(Bool.self, forKey: .success) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: .ok) {
            return value == 1
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: .success) {
            return value == 1
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: .status) {
            return value == 1
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: .status) {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["ok", "success", "true", "1"].contains(normalized) {
                return true
            }
            if ["fail", "failed", "false", "0", "error"].contains(normalized) {
                return false
            }
        }
        return nil
    }

    private static func decodeURLCandidate(from container: KeyedDecodingContainer<CodingKeys>) -> (key: String, value: String)? {
        let candidates: [(CodingKeys, String)] = [
            (.url, "url"),
            (.link, "link"),
            (.deepLink, "deep_link")
        ]
        for (codingKey, keyName) in candidates {
            if let value = try? container.decodeIfPresent(String.self, forKey: codingKey) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return (key: keyName, value: trimmed)
                }
            }
        }
        return nil
    }

    private static func decodeExpiresRawValue(from container: KeyedDecodingContainer<CodingKeys>) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: .expires) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let intValue = try? container.decodeIfPresent(Int64.self, forKey: .expires) {
            return String(intValue)
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .expires) {
            return String(doubleValue)
        }
        return nil
    }
}

protocol NetworkSessionProtocol: AnyObject {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSessionProtocol {}

/// Network repository implementation: POST to config endpoint and parse web URL from JSON response.
/// Injected via DI; use `NetworkRepositoryProtocol` in domain/use cases.
final class ServerAPIRepository: NetworkRepositoryProtocol {

    private let configuration: AppConfigurationProtocol
    private let logger: Logging
    private let session: NetworkSessionProtocol

    init(
        configuration: AppConfigurationProtocol,
        logger: Logging,
        session: NetworkSessionProtocol = URLSession.shared
    ) {
        self.configuration = configuration
        self.logger = logger
        self.session = session
    }

    func fetchConfig(usingPayload payload: [AnyHashable: Any], timeout: TimeInterval = 10) async throws -> ConfigFetchResult {
        guard let url = URL(string: configuration.serverURL) else {
            throw ServerAPIRepositoryError.invalidURL
        }
        guard JSONSerialization.isValidJSONObject(payload) else {
            logger.log("ServerAPI: invalid payload. Non-JSON object detected", level: .error)
            throw ServerAPIRepositoryError.invalidPayload
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let requestBody = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = requestBody
        let requestBodyString = String(data: requestBody, encoding: .utf8) ?? "<non-utf8-body>"
        logger.log(
            "ServerAPI Request: method=\(request.httpMethod ?? "UNKNOWN"), url=\(url.absoluteString), timeout=\(timeout)s, headers=\(request.allHTTPHeaderFields ?? [:]), bodyBytes=\(requestBody.count), body=\(requestBodyString)"
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                group.addTask {
                    try await self.session.data(for: request)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    self.logger.log("ServerAPI Transport: request timed out after \(timeout)s", level: .error)
                    throw ServerAPIRepositoryError.timeout(timeout)
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch let error as ServerAPIRepositoryError {
            logger.log("ServerAPI Error: \(error.localizedDescription)", level: .error)
            throw error
        } catch {
            if let urlError = error as? URLError {
                logger.log(
                    "ServerAPI Transport error: code=\(urlError.errorCode), description=\(urlError.localizedDescription)",
                    level: .error
                )
            } else {
                logger.log("ServerAPI Transport error: \(error.localizedDescription)", level: .error)
            }
            throw ServerAPIRepositoryError.transportError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ServerAPIRepositoryError.invalidResponse("Response is not HTTPURLResponse")
        }

        let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8-body>"
        logger.log(
            "ServerAPI Response: status=\(http.statusCode), headers=\(http.allHeaderFields), bodyBytes=\(data.count), body=\(responseBody)"
        )

        guard (200...299).contains(http.statusCode) else {
            logger.log("ServerAPI Error: non-success HTTP status \(http.statusCode)", level: .error)
            throw ServerAPIRepositoryError.httpError(statusCode: http.statusCode, body: responseBody)
        }

        if let codableResponse = try? JSONDecoder().decode(ServerAPIResponse.self, from: data) {
            logger.log(
                "ServerAPI Parse: decoder=codable, isSuccess=\(String(describing: codableResponse.isSuccess)), urlKey=\(codableResponse.urlKey ?? "nil"), url=\(codableResponse.urlString ?? "nil")"
            )
            let resolvedURLString = try resolveURLFromResponse(
                isSuccess: codableResponse.isSuccess,
                urlString: codableResponse.urlString
            )
            let expiresAt = parseExpiresDate(from: codableResponse.expiresRawValue)
            logger.log("ServerAPI Parse: resolvedURL=\(resolvedURLString ?? "nil"), expires=\(codableResponse.expiresRawValue ?? "nil")")
            return ConfigFetchResult(urlString: resolvedURLString, expiresAt: expiresAt)
        }

        logger.log("ServerAPI Parse: Codable parsing failed, using JSON fallback parser", level: .error)

        let json: [String: Any]
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = jsonObject as? [String: Any] else {
                throw ServerAPIRepositoryError.invalidResponse("Expected dictionary JSON response")
            }
            json = dictionary
        } catch {
            throw ServerAPIRepositoryError.invalidResponse("Invalid JSON: \(error.localizedDescription)")
        }
        let fallbackSuccess = parseSuccessFlag(from: json)
        let fallbackURLCandidate = parseURLCandidate(from: json)
        let fallbackExpires = parseExpiresRawValue(from: json)
        logger.log(
            "ServerAPI Parse: decoder=fallback, isSuccess=\(String(describing: fallbackSuccess)), urlKey=\(fallbackURLCandidate?.key ?? "nil"), url=\(fallbackURLCandidate?.value ?? "nil"), expires=\(fallbackExpires ?? "nil"), json=\(json)"
        )
        let resolvedURLString = try resolveURLFromResponse(
            isSuccess: fallbackSuccess,
            urlString: fallbackURLCandidate?.value
        )
        let expiresAt = parseExpiresDate(from: fallbackExpires)
        logger.log("ServerAPI Parse: resolvedURL=\(resolvedURLString ?? "nil"), expires=\(fallbackExpires ?? "nil")")
        return ConfigFetchResult(urlString: resolvedURLString, expiresAt: expiresAt)
    }

    private func resolveURLFromResponse(isSuccess: Bool?, urlString: String?) throws -> String? {
        if isSuccess == true, let urlString {
            logger.log("ServerAPI Parse: response is successful with URL")
            return urlString
        }
        if isSuccess == true {
            logger.log("ServerAPI Parse error: successful response does not contain URL", level: .error)
            throw ServerAPIRepositoryError.contractMismatch("Successful response does not contain URL")
        }
        if isSuccess == nil, let urlString {
            logger.log("ServerAPI Parse: URL present without explicit success flag")
            return urlString
        }
        if isSuccess == nil {
            logger.log("ServerAPI Parse error: response is missing success indicator and URL", level: .error)
            throw ServerAPIRepositoryError.contractMismatch("Response is missing success indicator and URL")
        }
        logger.log("ServerAPI Parse: response indicates failure without URL")
        return nil
    }

    private func parseSuccessFlag(from json: [String: Any]) -> Bool? {
        if let ok = json["ok"] as? Bool {
            return ok
        }
        if let success = json["success"] as? Bool {
            return success
        }
        if let okNumber = json["ok"] as? NSNumber {
            return okNumber.intValue == 1
        }
        if let successNumber = json["success"] as? NSNumber {
            return successNumber.intValue == 1
        }
        if let status = json["status"] as? String {
            let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["ok", "success", "true", "1"].contains(normalized) {
                return true
            }
            if ["fail", "failed", "false", "0", "error"].contains(normalized) {
                return false
            }
        }
        if let status = json["status"] as? NSNumber {
            return status.intValue == 1
        }
        return nil
    }

    private func parseURLCandidate(from json: [String: Any]) -> (key: String, value: String)? {
        let candidateKeys = ["url", "link", "deep_link"]
        for key in candidateKeys {
            if let value = json[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return (key: key, value: trimmed)
                }
            }
        }
        return nil
    }

    private func parseExpiresRawValue(from json: [String: Any]) -> String? {
        if let value = json["expires"] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = json["expires"] as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    private func parseExpiresDate(from rawValue: String?) -> Date? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }

        if let seconds = Double(rawValue) {
            return Date(timeIntervalSince1970: seconds)
        }

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsedDate = iso8601Formatter.date(from: rawValue) {
            return parsedDate
        }
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let parsedDate = iso8601Formatter.date(from: rawValue) {
            return parsedDate
        }

        let fallbackFormatter = DateFormatter()
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
        fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let parsedDate = fallbackFormatter.date(from: rawValue) {
            return parsedDate
        }
        return nil
    }
}
