import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Tổng quan", systemImage: "chart.bar.fill") }

            NavigationStack {
                OrdersView()
            }
            .tabItem { Label("Đơn hàng", systemImage: "doc.text.fill") }

            NavigationStack {
                InventoryView()
            }
            .tabItem { Label("Hàng hoá", systemImage: "shippingbox.fill") }

            NavigationStack {
                MoreView()
            }
            .tabItem { Label("Khác", systemImage: "ellipsis.circle.fill") }
        }
        .tint(AppTheme.primary)
    }
}
