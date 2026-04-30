import SwiftUI

enum Palette {
    static let bg              = Color(hex: 0x0A0A0F)
    static let bg1             = Color(hex: 0x0E0E14)
    static let surface         = Color(hex: 0x12121A)
    static let surfaceHigh     = Color(hex: 0x181824)
    static let line            = Color(white: 1.0, opacity: 0.06)
    static let line2           = Color(white: 1.0, opacity: 0.10)
    static let line3           = Color(white: 1.0, opacity: 0.16)
    static let text            = Color(hex: 0xECECF0)
    static let textSecondary   = Color(hex: 0xB5B5C0)
    static let textMuted       = Color(hex: 0x75757F)
    static let textFaint       = Color(hex: 0x4A4A55)
    static let accent          = Color(hex: 0xA78BFA)
    static let accentSoft      = Color(hex: 0xC7D2FE)
    static let accentPink      = Color(hex: 0xF0ABFC)
    static let success         = Color(hex: 0x86EFAC)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum Typography {
    /// Onest is shipped as a single variable TTF; we reference the family name and let
    /// SwiftUI's `.weight(...)` modifier (applied below) select an instance on the wght axis.
    static let onestFamily                = "Onest"
    static let onestSemiBoldPostScript    = "Onest-SemiBold"   // also used by InlineMarkdown for **bold**
    static let serifItalicPostScript      = "InstrumentSerif-Italic"
    static let serifPostScript            = "InstrumentSerif-Regular"
    static let monoPostScript             = "JetBrainsMono-Regular"
    static let monoMediumPostScript       = "JetBrainsMono-Medium"

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(onestFamily, size: size, relativeTo: style).weight(weight)
    }

    static func serifItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(serifItalicPostScript, size: size, relativeTo: style)
    }

    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(serifPostScript, size: size, relativeTo: style)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let ps = (weight == .medium || weight == .semibold || weight == .bold) ? monoMediumPostScript : monoPostScript
        return .custom(ps, size: size, relativeTo: style)
    }
}

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 18
}
