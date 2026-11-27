import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var introFinished: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["IOS_TEST_SKIP_INTRO"] == "1"
        #else
        return false
        #endif
    }()

    var body: some View {
        ZStack {
            if introFinished {
                appContent
                    .transition(.opacity)
            } else {
                VideoSplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        introFinished = true
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: introFinished)
    }

    @ViewBuilder
    private var appContent: some View {
        if auth.isRestoring {
            SplashView()
        } else if auth.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
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
