import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = ProcessInfo.processInfo.environment["IOS_TEST_TAB"] ?? "dashboard"

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Tổng quan", systemImage: "chart.bar.fill") }
            .tag("dashboard")

            NavigationStack {
                OrdersView()
            }
            .tabItem { Label("Đơn hàng", systemImage: "doc.text.fill") }
            .tag("orders")

            NavigationStack {
                InventoryView()
            }
            .tabItem { Label("Hàng hoá", systemImage: "shippingbox.fill") }
            .tag("inventory")

            NavigationStack {
                MoreView()
            }
            .tabItem { Label("Khác", systemImage: "ellipsis.circle.fill") }
            .tag("more")
        }
        .tint(AppTheme.primary)
    }
}
