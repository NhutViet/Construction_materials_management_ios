import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var showLogoutConfirm = false
    @State private var showEditProfile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let profile = auth.profile {
                    profileCard(profile)
                    contactCard(profile)
                }

                SectionHeader(title: "Thông tin")
                infoCard

                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.danger)
                .disabled(auth.isLoading)
            }
            .padding(AppTheme.screenPadding)
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Cá nhân")
        .sheet(isPresented: $showEditProfile) {
            if let profile = auth.profile {
                ProfileEditView(profile: profile)
            }
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
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["IOS_TEST_SCREEN"] == "profileEdit" {
                showEditProfile = true
            }
            #endif
        }
    }

    private func profileCard(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Text(profile.initials)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(AppTheme.primary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(.title3.weight(.bold))
                    if let username = profile.username {
                        Text("@\(username)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let email = profile.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
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
                .accessibilityLabel("Sửa hồ sơ")
            }

            Button {
                showEditProfile = true
            } label: {
                Label("Sửa hồ sơ", systemImage: "pencil")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .appCard()
    }

    private func contactCard(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Liên hệ & thanh toán")
                .font(.headline)

            infoRow(
                icon: "phone.fill",
                title: "Điện thoại",
                value: profile.phoneNumber?.isEmpty == false ? profile.phoneNumber! : "Chưa cập nhật"
            )
            infoRow(
                icon: "building.columns.fill",
                title: "Ngân hàng",
                value: profile.bankName?.isEmpty == false ? profile.bankName! : "Chưa cập nhật"
            )
            infoRow(
                icon: "creditcard.fill",
                title: "Số tài khoản",
                value: profile.bankNumber?.isEmpty == false ? profile.bankNumber! : "Chưa cập nhật"
            )
        }
        .appCard()
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(icon: "app.badge", title: "Phiên bản", value: appVersion)
            Divider().padding(.vertical, 10)
            infoRow(icon: "cloud.fill", title: "Backend", value: "Supabase")
        }
        .appCard()
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 22)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
