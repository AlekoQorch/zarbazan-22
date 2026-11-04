import SwiftUI

enum NovaTheme {
    enum Fallback {
        static let backgroundDark = Color.black
        static let backgroundLight = Color(red: 0.949, green: 0.949, blue: 0.969)
        static let surfaceDark = Color(red: 0.071, green: 0.071, blue: 0.078)
        static let surfaceLight = Color.white
        static let elevatedDark = Color(red: 0.110, green: 0.110, blue: 0.118)
        static let elevatedLight = Color(red: 0.922, green: 0.922, blue: 0.941)
        static let textPrimaryDark = Color.white
        static let textPrimaryLight = Color.black
        static let textSecondaryDark = Color(red: 0.557, green: 0.557, blue: 0.576)
        static let textSecondaryLight = Color(red: 0.424, green: 0.424, blue: 0.439)
        /// Warm rose — music-native, not cyan/tech.
        static let accentDark = Color(red: 1.0, green: 0.231, blue: 0.361)
        static let accentLight = Color(red: 0.882, green: 0.114, blue: 0.282)
        static let destructive = Color(red: 1.0, green: 0.271, blue: 0.227)
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 14
        static let artwork: CGFloat = 12
        static let artworkLarge: CGFloat = 18
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
    static var novaBackground: Color { Color("NovaBackground", bundle: .main) }
    static var novaSurface: Color { Color("NovaSurface", bundle: .main) }
    static var novaSurfaceElevated: Color { Color("NovaSurfaceElevated", bundle: .main) }
    static var novaTextPrimary: Color { Color("NovaTextPrimary", bundle: .main) }
    static var novaTextSecondary: Color { Color("NovaTextSecondary", bundle: .main) }
    static var novaAccent: Color { Color("NovaAccent", bundle: .main) }
    static var novaDestructive: Color { Color("NovaDestructive", bundle: .main) }
    static var novaSeparator: Color { Color("NovaSeparator", bundle: .main) }
}

struct NovaBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.novaBackground.ignoresSafeArea())
    }
}

extension View {
    func novaScreen() -> some View {
        modifier(NovaBackground())
    }
}
