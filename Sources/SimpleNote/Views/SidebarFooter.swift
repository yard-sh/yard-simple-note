import SwiftUI

/// The bottom of the sidebar: a Settings row, plus a notice above it when an update is
/// available or a trial is ending soon. (Unlicensed copies see `ActivationView`.)
struct SidebarFooter: View {
    @Environment(LicenseManager.self) private var license
    @Environment(UpdateChecker.self) private var updates
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let notice {
                FooterRow(systemImage: notice.symbol, title: notice.text, tint: notice.tint) {
                    openSettings()
                }
            }
            FooterRow(systemImage: "gearshape", title: "Settings", tint: Palette.accent) {
                openSettings()
            }
            .help("License, activation and updates (⌘,)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.line).frame(height: 1)
        }
    }

    private var notice: (text: String, symbol: String, tint: Color)? {
        if let release = updates.availableRelease {
            return ("Update available: \(release.tagName)", "arrow.down.circle.fill", Palette.accent)
        }
        if case .licensed(let days?) = license.status, days <= 7 {
            return ("Trial: \(days) day\(days == 1 ? "" : "s") left", "clock", Palette.textSecondary)
        }
        return nil
    }
}

/// A sidebar-style row: icon and label, light-green highlight on hover.
/// Drops the label to just the icon when the sidebar is too narrow for it.
private struct FooterRow: View {
    let systemImage: String
    let title: String
    let tint: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    icon
                    Text(title)
                        .font(Typography.ui(13, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .fixedSize()
                    Spacer(minLength: 0)
                }
                icon
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background(
                isHovered ? Palette.selection : .clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 18)
    }
}
