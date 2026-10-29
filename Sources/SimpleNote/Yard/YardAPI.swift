import Foundation

/// Static configuration for the Yard project this app is sold through.
enum YardConfig {
    static let apiBase = URL(string: "https://api.yard.sh")!
    /// `yard projects show simple-note-3 --json | jq -r .id`. Not a secret: validation is
    /// scoped to this project so a key bought for another project never validates here.
    static let projectID = "7fbabe06-1fc5-4424-b13f-0ae84a4614ae"
    static let buyURL = URL(string: "https://live.yard.sh/simple-note-3")!
    static let libraryURL = URL(string: "https://yard.sh/library")!

    /// A team API key holding only the `licenses:validate` scope, injected into Info.plist
    /// by build.sh from `YARD_API_KEY`. Integration scopes are safe to ship in the app.
    static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "YardAPIKey") as? String,
              key.hasPrefix("yard_") else { return nil }
        return key
    }

    /// Test builds only (`YARD_SANDBOX=<name> ./build.sh`): the Yard sandbox whose simulated
    /// purchases this build accepts. Release builds have none, so sandbox keys never unlock them.
    static var sandbox: String? {
        guard let name = Bundle.main.object(forInfoDictionaryKey: "YardSandbox") as? String,
              !name.isEmpty else { return nil }
        return name
    }

    /// Where a sandbox build sends buyers: the sandbox's own store, with simulated checkout.
    static var storeURL: URL {
        guard let sandbox else { return buyURL }
        return buyURL.appending(path: "@\(sandbox)/")
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}

/// Thin client for the Yard REST endpoints the shipped app uses.
enum YardAPI {
    enum APIError: LocalizedError {
        case notConfigured
        case http(status: Int, message: String?, code: String?)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "License verification isn't configured in this build."
            case .http(let status, let message, _):
                return message ?? HTTPURLResponse.localizedString(forStatusCode: status).capitalized
            case .transport(let error):
                return error.localizedDescription
            }
        }
    }

    // MARK: Licenses

    struct ValidationResult: Codable, Sendable, Equatable {
        var valid: Bool
        var error: String?
        var isTrial: Bool?
        var trialExpired: Bool?
        var trialExpiresAt: Date?
        var trialDaysRemaining: Int?
        var subscriptionInactive: Bool?
    }

    /// `POST /v1/licenses/validate`. A well-formed request answers 200 whether or not the
    /// key is usable; `valid` carries the answer.
    static func validate(licenseKey: String) async throws(APIError) -> ValidationResult {
        guard let apiKey = YardConfig.apiKey else { throw .notConfigured }
        var request = URLRequest(url: YardConfig.apiBase.appending(path: "v1/licenses/validate"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = [
            "project_id": YardConfig.projectID,
            "license_key": licenseKey,
        ]
        body["sandbox"] = YardConfig.sandbox
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    // MARK: Updates

    struct Release: Codable, Sendable, Equatable {
        struct Asset: Codable, Sendable, Equatable {
            var name: String
            var size: Int?
            var browserDownloadUrl: URL
        }
        var tagName: String
        var name: String?
        var body: String?
        var publishedAt: Date?
        var assets: [Asset]
    }

    /// `GET /v1/updates/latest`, authorised by the user's own license key, so revoked,
    /// refunded or expired keys stop receiving updates without any shared secret.
    static func latestRelease(licenseKey: String) async throws(APIError) -> Release {
        var url = YardConfig.apiBase.appending(path: "v1/updates/latest")
        if let sandbox = YardConfig.sandbox {
            url.append(queryItems: [URLQueryItem(name: "sandbox", value: sandbox)])
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(licenseKey)", forHTTPHeaderField: "Authorization")
        return try await send(request)
    }

    // MARK: Plumbing

    private struct ErrorBody: Decodable {
        var error: String?
        var errorCode: String?
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(raw, strategy: .iso8601) { return date }
            if let date = try? Date(raw, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(raw)"))
        }
        return d
    }()

    private static func send<T: Decodable>(_ request: URLRequest) async throws(APIError) -> T {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SimpleNote/\(YardConfig.appVersion) (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .transport(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let body = try? decoder.decode(ErrorBody.self, from: data)
            throw .http(status: status, message: body?.error, code: body?.errorCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .transport(error)
        }
    }
}
