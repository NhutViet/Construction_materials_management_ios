import SwiftUI

enum SideMenuPage: String, CaseIterable, Identifiable {
    case profile
    case customers
    case revenue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Cá nhân"
        case .customers: return "Khách hàng"
        case .revenue: return "Báo cáo doanh thu"
        }
    }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle.fill"
        case .customers: return "person.2.fill"
        case .revenue: return "chart.line.uptrend.xyaxis"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .profile: ProfileView()
        case .customers: CustomersView()
        case .revenue: RevenueView()
        }
    }
}

struct SideMenuView: View {
    @EnvironmentObject private var auth: AuthStore

    let onSelect: (SideMenuPage) -> Void
    let onOpenProfile: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Divider()
                    menuList
                    footer
                }
                .frame(width: min(proxy.size.width * 0.82, 330))
                .frame(maxHeight: .infinity, alignment: .top)
                .background(AppTheme.card.ignoresSafeArea())

                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Menu")
                    .font(.title2.weight(.bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.background)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Đóng menu")
            }

            Button(action: onOpenProfile) {
                HStack(spacing: 12) {
                    Text(auth.profile?.initials ?? "U")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.primary)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(auth.profile?.displayName ?? "Người dùng")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let username = auth.profile?.username {
                            Text("@\(username)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(AppTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var menuList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                menuSection(title: "TÀI KHOẢN", pages: [.profile])
                menuSection(title: "QUẢN LÝ", pages: [.customers, .revenue])
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
    }

    private func menuSection(title: String, pages: [SideMenuPage]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ForEach(pages) { page in
                Button {
                    onSelect(page)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: page.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.primary.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text(page.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Label("Phiên bản", systemImage: "info.circle")
                Spacer()
                Text(appVersion)
            }
            HStack {
                Label("Backend", systemImage: "cloud")
                Spacer()
                Text("Supabase")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(16)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
