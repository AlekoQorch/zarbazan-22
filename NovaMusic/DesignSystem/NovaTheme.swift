import SwiftUI

enum NovaTheme {
    /// Spotify-simple: black surfaces, muted gray text, green only for active/CTA.
    enum Fallback {
        static let backgroundDark = Color.black
        static let backgroundLight = Color.white
        static let surfaceDark = Color(red: 0.071, green: 0.071, blue: 0.071) // #121212
        static let surfaceLight = Color(red: 0.95, green: 0.95, blue: 0.95)
        static let elevatedDark = Color(red: 0.094, green: 0.094, blue: 0.094) // #181818
        static let elevatedLight = Color(red: 0.92, green: 0.92, blue: 0.92)
        static let textPrimaryDark = Color.white
        static let textPrimaryLight = Color.black
        static let textSecondaryDark = Color(red: 0.702, green: 0.702, blue: 0.702) // #B3B3B3
        static let textSecondaryLight = Color(red: 0.45, green: 0.45, blue: 0.45)
        static let accentDark = Color(red: 0.114, green: 0.725, blue: 0.329) // #1DB954
        static let accentLight = Color(red: 0.09, green: 0.60, blue: 0.26)
        static let destructive = Color(red: 1.0, green: 0.271, blue: 0.227)
    }

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let artwork: CGFloat = 6
        static let artworkLarge: CGFloat = 8
        static let sheet: CGFloat = 16
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
