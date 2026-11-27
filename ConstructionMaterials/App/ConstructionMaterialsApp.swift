import SwiftUI

@main
struct ConstructionMaterialsApp: App {
    @StateObject private var auth = AuthStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appAppearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(preferredColorScheme)
                .task {
                    await auth.restoreSession()
                    #if DEBUG
                    if !auth.isAuthenticated {
                        let environment = ProcessInfo.processInfo.environment
                        if let username = environment["IOS_TEST_USERNAME"],
                           let password = environment["IOS_TEST_PASSWORD"] {
                            await auth.login(username: username, password: password)
                        }
                    }
                    #endif
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await auth.validateSession() }
                }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
