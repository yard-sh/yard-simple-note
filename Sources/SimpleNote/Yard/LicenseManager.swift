import Foundation
import Observation

/// Holds the user's Yard license key and its last known validation result.
///
/// Without a valid license the app shows only the activation screen. A key that can't be
/// re-checked (offline, Yard unreachable) keeps its last answer, so a paying user is never
/// locked out by a network problem.
@MainActor
@Observable
final class LicenseManager {
    enum Status: Equatable {
        case unlicensed
        case checking
        case licensed(trialDaysRemaining: Int?)
        case invalid(String)
        /// A key is stored but couldn't be verified (offline, or no API key in this build).
        case unverified(String)
    }

    private(set) var licenseKey: String?
    private(set) var status: Status = .unlicensed
    /// When Yard last answered for the stored key.
    private(set) var lastVerified: Date?

    var isLicensed: Bool {
        if case .licensed = status { return true }
        return false
    }

    /// True when there's no key, or Yard said the stored key isn't valid (refunded, revoked,
    /// trial expired, subscription lapsed). Checking or unverifiable keys keep access.
    var requiresActivation: Bool {
        switch status {
        case .unlicensed, .invalid: return true
        case .checking, .licensed, .unverified: return false
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    private enum Keys {
        static let licenseKey = "license.key"
        static let lastResult = "license.lastResult"
        static let lastVerified = "license.lastVerified"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        licenseKey = defaults.string(forKey: Keys.licenseKey)
        lastVerified = defaults.object(forKey: Keys.lastVerified) as? Date
        if licenseKey != nil {
            status = cachedResult.map { Self.status(for: $0) } ?? .unverified("Not verified yet.")
        }
    }

    /// Re-validates the stored key. Called at launch.
    func refresh() async {
        guard let key = licenseKey else { return }
        status = .checking
        do {
            let result = try await YardAPI.validate(licenseKey: key)
            // The user may have removed or replaced the key while this was in flight.
            guard licenseKey == key else { return }
            cachedResult = result
            markVerified()
            status = Self.status(for: result)
        } catch {
            guard licenseKey == key else { return }
            if let cached = cachedResult, error.keepsLastAnswer {
                status = Self.status(for: cached)
            } else {
                status = .unverified(error.localizedDescription)
            }
        }
    }

    /// Validates a key the user typed in and stores it if Yard accepts it.
    /// Returns a message to show when it doesn't; the current license is left untouched.
    func activate(_ input: String) async -> String? {
        let key = Self.normalize(input)
        guard !key.isEmpty else { return "Enter a license key." }
        do {
            let result = try await YardAPI.validate(licenseKey: key)
            guard result.valid else { return result.error ?? "This license key isn't valid." }
            licenseKey = key
            defaults.set(key, forKey: Keys.licenseKey)
            cachedResult = result
            markVerified()
            status = Self.status(for: result)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Forgets the key on this Mac. The license itself is untouched in the user's Yard library.
    func removeLicense() {
        licenseKey = nil
        cachedResult = nil
        lastVerified = nil
        defaults.removeObject(forKey: Keys.licenseKey)
        defaults.removeObject(forKey: Keys.lastVerified)
        status = .unlicensed
    }

    // MARK: - Private

    private func markVerified() {
        lastVerified = .now
        defaults.set(lastVerified, forKey: Keys.lastVerified)
    }

    private static func status(for result: YardAPI.ValidationResult, now: Date = .now) -> Status {
        guard result.valid else { return .invalid(result.error ?? "This license key isn't valid.") }
        guard result.isTrial == true else { return .licensed(trialDaysRemaining: nil) }
        // Count down from the expiry date so a cached answer stays accurate offline.
        if let expires = result.trialExpiresAt {
            if expires <= now { return .invalid("Trial period has expired") }
            return .licensed(trialDaysRemaining: Int((expires.timeIntervalSince(now) / 86_400).rounded(.up)))
        }
        return .licensed(trialDaysRemaining: result.trialDaysRemaining)
    }

    private var cachedResult: YardAPI.ValidationResult? {
        get {
            defaults.data(forKey: Keys.lastResult).flatMap { try? JSONDecoder().decode(YardAPI.ValidationResult.self, from: $0) }
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.lastResult)
            } else {
                defaults.removeObject(forKey: Keys.lastResult)
            }
        }
    }

    /// Yard ignores letter case and surrounding spaces; normalise so storage is stable.
    nonisolated static func normalize(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

private extension YardAPI.APIError {
    /// Errors that say nothing about the user's key: network trouble, rate limits, server
    /// errors, 401/402/403 (the team's API key or plan) and a build without an API key.
    var keepsLastAnswer: Bool {
        switch self {
        case .transport, .notConfigured: return true
        case .http(let status, _, _): return [401, 402, 403, 429].contains(status) || status >= 500
        }
    }
}
