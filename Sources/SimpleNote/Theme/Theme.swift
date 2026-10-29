import SwiftUI
import AppKit

/// Simple Note's palette: warm paper, ink and leaf green in Light; a deep green in Dark.
/// Each colour resolves per appearance, so the app follows the system Light/Dark setting.
enum Palette {
    static let bg            = Color(nsColor: NS.bg)
    static let sidebar       = Color(nsColor: NS.sidebar)
    /// A light wash of the sidebar colour laid over the native sidebar material, so the
    /// sidebar stays on-theme while keeping its translucency and blur.
    static let sidebarTint   = Color(nsColor: NS.sidebar).opacity(0.12)
    static let surface       = Color(nsColor: NS.surface)
    static let line          = Color(nsColor: NS.line)
    static let text          = Color(nsColor: NS.text)
    static let textSecondary = Color(nsColor: NS.textSecondary)
    static let textMuted     = Color(nsColor: NS.textMuted)
    static let textFaint     = Color(nsColor: NS.textFaint)
    /// Green for text and icons. Light in Dark mode so it reads on the dark background.
    static let accent        = Color(nsColor: NS.accent)
    /// Green for filled controls that carry white text (selection, prominent buttons).
    /// Deeper than `accent` in Dark mode so white text keeps at least 4.5:1 contrast.
    static let accentFill    = Color(nsColor: NS.accentFill)
    /// Light-green fill for selected rows.
    static let selection     = Color(nsColor: NS.selection)
    static let success       = Color(nsColor: NS.accent)
    static let warning       = Color(nsColor: NS.warning)
    static let danger        = Color(nsColor: NS.danger)

    /// AppKit versions, for the NSTextView editor.
    enum NS {
        static let bg            = NSColor(light: 0xF6F7F2, dark: 0x18201C)
        static let sidebar       = NSColor(light: 0xECEEE8, dark: 0x1F2924)
        static let surface       = NSColor(light: 0xFFFDF7, dark: 0x232D28)
        static let line          = NSColor(light: 0xD8D2C7, dark: 0x34413A)
        static let text          = NSColor(light: 0x17211D, dark: 0xEEF0E8)
        static let textSecondary = NSColor(light: 0x4F5951, dark: 0xB7C0B5)
        static let textMuted     = NSColor(light: 0x69706A, dark: 0x8C968D)
        static let textFaint     = NSColor(light: 0x90968F, dark: 0x5F6961)
        static let accent        = NSColor(light: 0x37634B, dark: 0x8DC49B)
        static let accentFill    = NSColor(light: 0x37634B, dark: 0x3E7A57)
        static let selection     = NSColor(light: 0xD8E5D7, dark: 0x2C4436)
        static let warning       = NSColor(light: 0xA86B12, dark: 0xE6BB5D)
        static let danger        = NSColor(light: 0xB5483F, dark: 0xE27D73)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }

    /// A colour that resolves to `light` or `dark` with the view's appearance.
    convenience init(light: UInt32, dark: UInt32) {
        self.init(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }
    }
}

enum Typography {
    /// Bundled fonts are registered by AppKit at launch via `ATSApplicationFontsPath`
    /// in Info.plist. When they're missing (e.g. `swift run`), `Font.custom` falls back
    /// to the system font.
    static let onestFamily           = "Onest"
    static let serifItalicPostScript = "InstrumentSerif-Italic"
    static let monoPostScript        = "JetBrainsMono-Regular"
    static let monoMediumPostScript  = "JetBrainsMono-Medium"

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(onestFamily, size: size, relativeTo: style).weight(weight)
    }

    static func serifItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(serifItalicPostScript, size: size, relativeTo: style)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let ps = (weight == .medium || weight == .semibold || weight == .bold) ? monoMediumPostScript : monoPostScript
        return .custom(ps, size: size, relativeTo: style)
    }

    static func editorNSFont(size: CGFloat = 16) -> NSFont {
        NSFont(name: onestFamily, size: size) ?? .systemFont(ofSize: size)
    }
}
