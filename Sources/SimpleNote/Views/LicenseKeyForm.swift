import SwiftUI

/// License key field with an Activate button and inline errors. Used by the activation
/// screen and the License settings tab.
struct LicenseKeyForm: View {
    @Environment(LicenseManager.self) private var license

    @State private var input = ""
    @State private var activationError: String?
    @State private var isActivating = false
    @FocusState private var fieldFocused: Bool

    var focusOnAppear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("License Key", text: $input, prompt: Text("XXXX-XXXX-XXXX-XXXX"))
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .focused($fieldFocused)
                    .onSubmit(activate)
                    .disabled(isActivating)
                    .labelsHidden()

                Button(action: activate) {
                    if isActivating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Activate")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
            }
            if let activationError {
                Label(activationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { if focusOnAppear { fieldFocused = true } }
        .onChange(of: input) { _, _ in activationError = nil }
    }

    private func activate() {
        guard !isActivating, !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isActivating = true
        activationError = nil
        Task {
            activationError = await license.activate(input)
            if activationError == nil { input = "" }
            isActivating = false
        }
    }
}
