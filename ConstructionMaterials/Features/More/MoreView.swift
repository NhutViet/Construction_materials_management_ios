import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var showLogoutConfirm = false

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
                    }
                    .padding(.vertical, 6)
                }
            }

            Section("Quản lý") {
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
        .navigationTitle("Khác")
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
