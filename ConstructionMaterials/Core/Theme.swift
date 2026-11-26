import SwiftUI

enum AppTheme {
    static let primary = Color(red: 0.10, green: 0.46, blue: 0.82)
    static let primaryDark = Color(red: 0.05, green: 0.30, blue: 0.62)
    static let background = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let card = Color.white
    static let success = Color(red: 0.18, green: 0.65, blue: 0.35)
    static let warning = Color(red: 0.95, green: 0.60, blue: 0.12)
    static let danger = Color(red: 0.86, green: 0.22, blue: 0.22)
    static let info = Color(red: 0.10, green: 0.55, blue: 0.75)
    static let muted = Color.gray
    static let cornerRadius: CGFloat = 16
    static let screenPadding: CGFloat = 16
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
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
