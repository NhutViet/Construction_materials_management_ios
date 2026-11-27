import SwiftUI

private struct OpenSideMenuKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSideMenu: () -> Void {
        get { self[OpenSideMenuKey.self] }
        set { self[OpenSideMenuKey.self] = newValue }
    }
}

struct SideMenuButton: View {
    @Environment(\.openSideMenu) private var openSideMenu

    var body: some View {
        Button {
            openSideMenu()
        } label: {
            Image(systemName: "line.3.horizontal")
        }
        .accessibilityLabel("Mở menu")
    }
}

extension View {
    /// Gắn nút mở menu trái vào toolbar của màn hình gốc.
    func sideMenuToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SideMenuButton()
            }
        }
    }
}
