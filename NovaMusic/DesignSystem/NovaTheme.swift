import SwiftUI

enum NovaTheme {
    enum ColorToken {
        static let background = Color("NovaBackground", bundle: nil)
        static let surface = Color("NovaSurface", bundle: nil)
        static let surfaceElevated = Color("NovaSurfaceElevated", bundle: nil)
        static let textPrimary = Color("NovaTextPrimary", bundle: nil)
        static let textSecondary = Color("NovaTextSecondary", bundle: nil)
        static let accent = Color("NovaAccent", bundle: nil)
        static let destructive = Color("NovaDestructive", bundle: nil)
        static let separator = Color("NovaSeparator", bundle: nil)
    }

    // Fallback literals when asset catalog colors are unavailable at preview time.
    enum Fallback {
        static let backgroundDark = Color(red: 0.039, green: 0.039, blue: 0.043)
        static let backgroundLight = Color(red: 0.969, green: 0.969, blue: 0.973)
        static let surfaceDark = Color(red: 0.086, green: 0.086, blue: 0.094)
        static let surfaceLight = Color.white
        static let elevatedDark = Color(red: 0.118, green: 0.118, blue: 0.133)
        static let elevatedLight = Color(red: 0.941, green: 0.941, blue: 0.949)
        static let textPrimaryDark = Color(red: 0.961, green: 0.961, blue: 0.969)
        static let textPrimaryLight = Color(red: 0.039, green: 0.039, blue: 0.043)
        static let textSecondaryDark = Color(red: 0.631, green: 0.631, blue: 0.651)
        static let textSecondaryLight = Color(red: 0.431, green: 0.431, blue: 0.451)
        static let accentDark = Color(red: 0.239, green: 0.859, blue: 0.851)
        static let accentLight = Color(red: 0.039, green: 0.620, blue: 0.612)
        static let destructive = Color(red: 1.0, green: 0.271, blue: 0.227)
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let artwork: CGFloat = 16
        static let artworkLarge: CGFloat = 24
        static let sheet: CGFloat = 20
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Motion {
        static let quick = Animation.easeInOut(duration: 0.18)
        static let standard = Animation.easeInOut(duration: 0.28)
        static let gentle = Animation.spring(response: 0.42, dampingFraction: 0.86)
        static let artwork = Animation.spring(response: 0.55, dampingFraction: 0.78)
    }
}

extension Color {
    static var novaBackground: Color {
        Color("NovaBackground", bundle: .main)
    }

    static var novaSurface: Color {
        Color("NovaSurface", bundle: .main)
    }

    static var novaSurfaceElevated: Color {
        Color("NovaSurfaceElevated", bundle: .main)
    }

    static var novaTextPrimary: Color {
        Color("NovaTextPrimary", bundle: .main)
    }

    static var novaTextSecondary: Color {
        Color("NovaTextSecondary", bundle: .main)
    }

    static var novaAccent: Color {
        Color("NovaAccent", bundle: .main)
    }

    static var novaDestructive: Color {
        Color("NovaDestructive", bundle: .main)
    }

    static var novaSeparator: Color {
        Color("NovaSeparator", bundle: .main)
    }
}

struct NovaBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.novaBackground.ignoresSafeArea())
    }
}

extension View {
    func novaScreen() -> some View {
        modifier(NovaBackground())
    }
}
