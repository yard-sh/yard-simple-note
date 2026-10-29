import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("License", systemImage: "key") {
                LicenseSettingsView()
            }
            Tab("Updates", systemImage: "arrow.down.circle") {
                UpdateSettingsView()
            }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - License

private struct LicenseSettingsView: View {
    @Environment(LicenseManager.self) private var license
    @Environment(\.openURL) private var openURL

    @State private var confirmRemove = false

    var body: some View {
        Form {
            Section {
                if let sandbox = YardConfig.sandbox {
                    SandboxBadge(sandbox: sandbox)
                }
                LabeledContent("Status") { statusView }
                if let key = license.licenseKey {
                    LabeledContent("License Key") {
                        Text(Self.masked(key))
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("Last Verified") {
                        if let verified = license.lastVerified {
                            Text(verified, format: .relative(presentation: .named))
                        } else {
                            Text("Not yet").foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section(license.licenseKey == nil ? "Activate" : "Use a Different Key") {
                LicenseKeyForm()
                HStack {
                    Button("Buy Simple Note…") { openURL(YardConfig.storeURL) }
                    Button("Find My Key…") { openURL(YardConfig.libraryURL) }
                        .help("Your license key is in your Yard library, under License Keys.")
                }
            }

            if license.licenseKey != nil {
                Section {
                    HStack {
                        Button("Verify Again") { Task { await license.refresh() } }
                            .disabled(license.status == .checking)
                        Spacer()
                        Button("Deactivate on This Mac…", role: .destructive) { confirmRemove = true }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .confirmationDialog("Deactivate Simple Note on this Mac?", isPresented: $confirmRemove) {
            Button("Deactivate", role: .destructive) { license.removeLicense() }
        } message: {
            Text("Simple Note will ask for a license key before you can write again. Your notes stay on this Mac, and your key stays in your Yard library so you can use it here or on another Mac.")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch license.status {
        case .unlicensed:
            Text("Not activated").foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
        case .licensed(let days?):
            Label("Trial — \(days) day\(days == 1 ? "" : "s") left", systemImage: "clock")
        case .licensed(nil):
            Label("Licensed", systemImage: "checkmark.seal.fill").foregroundStyle(Palette.success)
        case .invalid(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Palette.warning)
        case .unverified(let reason):
            Label("Couldn’t verify — \(reason)", systemImage: "wifi.exclamationmark").foregroundStyle(.secondary)
        }
    }

    private static func masked(_ key: String) -> String {
        let groups = key.split(separator: "-")
        guard groups.count > 1 else { return key }
        return (groups.dropLast().map { _ in "••••" } + [String(groups.last!)]).joined(separator: "-")
    }
}

// MARK: - Updates

private struct UpdateSettingsView: View {
    @Environment(LicenseManager.self) private var license
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        @Bindable var updates = updates

        Form {
            Section {
                LabeledContent("Current Version") {
                    HStack(spacing: 10) {
                        Text(YardConfig.appVersion)
                        Button("Check Now") {
                            Task { await updates.check(licenseKey: license.licenseKey) }
                        }
                        .controlSize(.small)
                        .disabled(updates.status == .checking || license.licenseKey == nil)
                    }
                }
                Toggle("Check for updates automatically", isOn: $updates.automaticallyChecks)
                LabeledContent("Status") { statusView }
                if let lastChecked = updates.lastChecked {
                    LabeledContent("Last Checked") {
                        Text(lastChecked, format: .relative(presentation: .named))
                    }
                }
            } footer: {
                if license.licenseKey == nil {
                    Text("Updates are delivered with your license key. Activate it in the License tab.")
                        .foregroundStyle(.secondary)
                }
            }

            if case .available(let release) = updates.status {
                Section(release.name ?? release.tagName) {
                    if let body = release.body, !body.isEmpty {
                        ScrollView {
                            Text((try? AttributedString(
                                markdown: body,
                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                            )) ?? AttributedString(body))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        }
                        .frame(maxHeight: 180)
                    }
                    HStack {
                        Spacer()
                        Button("Download \(release.tagName)") {
                            Task { await updates.download(release) }
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }

        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
    }

    @ViewBuilder
    private var statusView: some View {
        switch updates.status {
        case .idle:
            Text("Not checked yet").foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
        case .upToDate:
            Label("Simple Note is up to date", systemImage: "checkmark.circle.fill").foregroundStyle(Palette.success)
        case .available(let release):
            Label("\(release.tagName) is available", systemImage: "arrow.down.circle.fill").foregroundStyle(Palette.accent)
        case .downloading:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Downloading…") }
        case .downloaded(let url):
            Label("Downloaded to \(url.deletingLastPathComponent().lastPathComponent)", systemImage: "checkmark.circle.fill")
        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Palette.warning)
        }
    }
}
