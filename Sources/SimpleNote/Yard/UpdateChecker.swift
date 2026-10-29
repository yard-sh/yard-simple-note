import AppKit
import Foundation
import Observation

/// Checks Yard's update server with the user's license key and downloads new releases.
@MainActor
@Observable
final class UpdateChecker {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(YardAPI.Release)
        case downloading(YardAPI.Release)
        case downloaded(URL)
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastChecked: Date?

    var automaticallyChecks: Bool {
        didSet { defaults.set(automaticallyChecks, forKey: Keys.automatic) }
    }

    var availableRelease: YardAPI.Release? {
        if case .available(let release) = status { return release }
        return nil
    }

    @ObservationIgnored private let defaults: UserDefaults
    private enum Keys {
        static let automatic = "updates.automatic"
        static let lastChecked = "updates.lastChecked"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        automaticallyChecks = defaults.object(forKey: Keys.automatic) as? Bool ?? true
        lastChecked = defaults.object(forKey: Keys.lastChecked) as? Date
    }

    /// Launch-time check, at most once a day, and only when the user hasn't turned it off.
    func checkInBackgroundIfDue(licenseKey: String?) async {
        guard automaticallyChecks, let licenseKey else { return }
        if let lastChecked, Date.now.timeIntervalSince(lastChecked) < 24 * 60 * 60 { return }
        await check(licenseKey: licenseKey)
    }

    func check(licenseKey: String?) async {
        guard let licenseKey else {
            status = .failed("Enter your license key to receive updates.")
            return
        }
        status = .checking
        do {
            let release = try await YardAPI.latestRelease(licenseKey: licenseKey)
            lastChecked = .now
            defaults.set(lastChecked, forKey: Keys.lastChecked)
            status = Self.isNewer(release.tagName, than: YardConfig.appVersion) ? .available(release) : .upToDate
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Downloads the Mac build of `release` into ~/Downloads and reveals it in Finder.
    func download(_ release: YardAPI.Release) async {
        guard let asset = Self.macAsset(in: release) else {
            status = .failed("This release has no Mac download yet.")
            return
        }
        status = .downloading(release)
        do {
            let (temp, response) = try await URLSession.shared.download(from: asset.browserDownloadUrl)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                status = .failed("The download didn't complete. Please try again.")
                return
            }
            let downloads = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let destination = Self.uniqueURL(for: asset.name, in: downloads)
            try FileManager.default.moveItem(at: temp, to: destination)
            status = .downloaded(destination)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Compares dotted numeric versions, ignoring a leading "v" ("v1.10.0" > "1.9").
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                .split(separator: "-").first
                .map { $0.split(separator: ".").map { Int($0) ?? 0 } } ?? []
        }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func macAsset(in release: YardAPI.Release) -> YardAPI.Release.Asset? {
        let preferred = [".dmg", ".zip", ".pkg"]
        for ext in preferred {
            let matches = release.assets.filter { $0.name.lowercased().hasSuffix(ext) }
            if let mac = matches.first(where: { $0.name.lowercased().contains("mac") }) { return mac }
            if let any = matches.first { return any }
        }
        return nil
    }

    private static func uniqueURL(for name: String, in directory: URL) -> URL {
        var url = directory.appending(path: name)
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appending(path: "\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return url
    }
}
