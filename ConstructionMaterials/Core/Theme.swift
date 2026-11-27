import SwiftUI
import UIKit

enum AppTheme {
    static let primary = dynamic(
        light: (0.10, 0.46, 0.82),
        dark: (0.32, 0.64, 0.98)
    )
    static let primaryDark = dynamic(
        light: (0.05, 0.30, 0.62),
        dark: (0.08, 0.24, 0.50)
    )
    static let background = dynamic(
        light: (0.96, 0.97, 0.98),
        dark: (0.04, 0.05, 0.07)
    )
    static let card = dynamic(
        light: (1.00, 1.00, 1.00),
        dark: (0.09, 0.11, 0.14)
    )
    static let success = dynamic(
        light: (0.18, 0.65, 0.35),
        dark: (0.30, 0.82, 0.50)
    )
    static let warning = dynamic(
        light: (0.95, 0.60, 0.12),
        dark: (1.00, 0.72, 0.30)
    )
    static let danger = dynamic(
        light: (0.86, 0.22, 0.22),
        dark: (1.00, 0.42, 0.42)
    )
    static let info = dynamic(
        light: (0.10, 0.55, 0.75),
        dark: (0.35, 0.75, 0.95)
    )
    static let muted = Color.secondary

    static let cornerRadius: CGFloat = 16
    static let screenPadding: CGFloat = 16

    /// Màu đổ bóng của card: nhẹ ở Light Mode, đậm hơn ở Dark Mode.
    static let cardShadow = Color(uiColor: UIColor { trait in
        UIColor.black.withAlphaComponent(trait.userInterfaceStyle == .dark ? 0.45 : 0.05)
    })

    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(uiColor: UIColor { trait in
            let value = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.background.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }
}
