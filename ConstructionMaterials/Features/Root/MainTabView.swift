import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: String = {
        let tab = ProcessInfo.processInfo.environment["IOS_TEST_TAB"] ?? "dashboard"
        return tab == "more" ? "profile" : tab
    }()
    @State private var showSideMenu = false
    @State private var activeMenuPage: SideMenuPage?

    var body: some View {
        ZStack(alignment: .leading) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView()
                        .sideMenuToolbar()
                }
                .tabItem { Label("Tổng quan", systemImage: "chart.bar.fill") }
                .tag("dashboard")

                NavigationStack {
                    OrdersView()
                        .sideMenuToolbar()
                }
                .tabItem { Label("Đơn hàng", systemImage: "doc.text.fill") }
                .tag("orders")

                NavigationStack {
                    InventoryView()
                        .sideMenuToolbar()
                }
                .tabItem { Label("Hàng hoá", systemImage: "shippingbox.fill") }
                .tag("inventory")

                NavigationStack {
                    DeliveryHistoryView()
                        .sideMenuToolbar()
                }
                .tabItem { Label("Lịch sử", systemImage: "clock.arrow.circlepath") }
                .tag("deliveryHistory")

                NavigationStack {
                    ProfileView()
                        .sideMenuToolbar()
                }
                .tabItem { Label("Cá nhân", systemImage: "person.crop.circle.fill") }
                .tag("profile")
            }
            .tint(AppTheme.primary)

            if showSideMenu {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeSideMenu() }
                    .transition(.opacity)

                SideMenuView(
                    onSelect: { page in
                        closeSideMenu()
                        activeMenuPage = page
                    },
                    onOpenProfile: {
                        closeSideMenu()
                        selectedTab = "profile"
                    },
                    onClose: closeSideMenu
                )
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showSideMenu)
        .environment(\.openSideMenu) {
            withAnimation(.easeOut(duration: 0.2)) {
                showSideMenu = true
            }
        }
        .fullScreenCover(item: $activeMenuPage) { page in
            NavigationStack {
                page.destination
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                activeMenuPage = nil
                            } label: {
                                Label("Đóng", systemImage: "xmark")
                            }
                        }
                    }
            }
        }
        .task {
            #if DEBUG
            if let screen = ProcessInfo.processInfo.environment["IOS_TEST_SCREEN"] {
                switch screen {
                case "customers": activeMenuPage = .customers
                case "stockin": activeMenuPage = .stockIn
                case "revenue": activeMenuPage = .revenue
                case "sideMenu": showSideMenu = true
                default: break
                }
            }
            #endif
        }
    }

    private func closeSideMenu() {
        withAnimation(.easeOut(duration: 0.2)) {
            showSideMenu = false
        }
    }
}
