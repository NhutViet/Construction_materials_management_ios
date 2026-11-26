import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var showLogoutConfirm = false
    @State private var showEditProfile = false
    @State private var debugPath: String?

    var body: some View {
        List {
            if let profile = auth.profile {
                Section {
                    HStack(spacing: 14) {
                        Text(profile.initials)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(AppTheme.primary)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName)
                                .font(.headline)
                            if let username = profile.username {
                                Text("@\(username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let email = profile.email, !email.isEmpty {
                                Text(email)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)

                    if let phone = profile.phoneNumber, !phone.isEmpty {
                        LabeledContent("Điện thoại", value: phone)
                    }
                    if let bank = profile.bankName, !bank.isEmpty {
                        LabeledContent("Ngân hàng", value: bank)
                    }
                    if let account = profile.bankNumber, !account.isEmpty {
                        LabeledContent("Số tài khoản", value: account)
                    }
                }
            }

            Section("Quản lý") {
                NavigationLink {
                    CustomersView()
                } label: {
                    Label("Khách hàng", systemImage: "person.2.fill")
                }

                NavigationLink {
                    StockInListView()
                } label: {
                    Label("Nhập hàng", systemImage: "tray.and.arrow.down.fill")
                }

                NavigationLink {
                    RevenueView()
                } label: {
                    Label("Báo cáo doanh thu", systemImage: "chart.line.uptrend.xyaxis")
                }

                NavigationLink {
                    DeliveryHistoryView()
                } label: {
                    Label("Lịch sử giao hàng", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("Thông tin") {
                LabeledContent("Phiên bản", value: appVersion)
                LabeledContent("Backend", value: "Supabase")
            }

            Section {
                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(auth.isLoading)
            }
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationTitle("Khác")
        .navigationDestination(item: $debugPath) { screen in
            switch screen {
            case "customers": CustomersView()
            case "stockin": StockInListView()
            case "revenue": RevenueView()
            case "deliveryHistory": DeliveryHistoryView()
            default: EmptyView()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            if let profile = auth.profile {
                ProfileEditView(profile: profile)
            }
        }
        .task {
            #if DEBUG
            let environment = ProcessInfo.processInfo.environment
            if let screen = environment["IOS_TEST_SCREEN"], !screen.isEmpty, debugPath == nil {
                if screen == "profile" {
                    showEditProfile = true
                } else {
                    debugPath = screen
                }
            }
            #endif
        }
        .confirmationDialog(
            "Bạn có chắc muốn đăng xuất?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("Đăng xuất", role: .destructive) {
                Task { await auth.logout() }
            }
            Button("Hủy", role: .cancel) {}
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
