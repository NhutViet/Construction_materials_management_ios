import SwiftUI

@main
struct ConstructionMaterialsApp: App {
    @StateObject private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
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
        }
    }
}
