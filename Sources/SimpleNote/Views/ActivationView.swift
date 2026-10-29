import SwiftUI

/// Fills the window until the app has a valid license: enter a key, or buy one.
struct ActivationView: View {
    @Environment(LicenseManager.self) private var license
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            VStack(spacing: 22) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(headline)
                        .font(Typography.serifItalic(36))
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LicenseKeyForm(focusOnAppear: true)
                    .frame(maxWidth: 380)

                if let sandbox = YardConfig.sandbox {
                    SandboxBadge(sandbox: sandbox)
                }

                Divider()
                    .frame(maxWidth: 380)

                VStack(spacing: 10) {
                    Button {
                        openURL(YardConfig.storeURL)
                    } label: {
                        Text("Buy Simple Note")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: 380)

                    Button("Already bought it? Find your license key") {
                        openURL(YardConfig.libraryURL)
                    }
                    .buttonStyle(.link)
                    .help("Your key is in your Yard library, on Simple Note’s License Keys tab.")
                }
            }
            .padding(40)
            .frame(maxWidth: 520)

            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
    }

    private var headline: String {
        if case .invalid = license.status { return "Reactivate Simple Note" }
        return "Activate Simple Note"
    }

    private var message: String {
        if case .invalid(let reason) = license.status {
            let sentence = reason.hasSuffix(".") ? reason : reason + "."
            return "\(sentence) Enter a valid license key to keep writing — your notes are safe and waiting."
        }
        return "Enter the license key from your purchase to start writing."
    }
}

/// Marks a test build so it's never mistaken for a release.
struct SandboxBadge: View {
    let sandbox: String

    var body: some View {
        Label("Sandbox build: \(sandbox) — accepts simulated purchases only", systemImage: "testtube.2")
            .font(.callout)
            .foregroundStyle(Palette.warning)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Palette.warning.opacity(0.12), in: Capsule())
    }
}
