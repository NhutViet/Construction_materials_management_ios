import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        Group {
            if auth.isRestoring {
                SplashView()
            } else if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)
                Text("Quản lý vật liệu")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                ProgressView()
                    .tint(.white)
            }
        }
    }
}
