import Foundation
import Combine

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var isRestoring = true
    @Published private(set) var isLoading = false
    @Published var error: String?

    private let service = AuthService()
    private var sessionObserver: AnyCancellable?

    init() {
        sessionObserver = NotificationCenter.default
            .publisher(for: .authSessionExpired)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.profile = nil
                    self?.error = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
                }
            }
    }

    var isAuthenticated: Bool { profile != nil }

    func restoreSession() async {
        guard isRestoring else { return }
        profile = await service.restoreProfile()
        isRestoring = false
    }

    func login(username: String, password: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            profile = try await service.signIn(username: username, password: password)
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
    }

    func logout() async {
        isLoading = true
        defer { isLoading = false }
        try? await service.signOut()
        profile = nil
        error = nil
    }

    func validateSession() async {
        guard isAuthenticated, !isRestoring else { return }
        if await service.validateSessionIfNeeded() {
            await refreshProfile()
        }
    }

    func updateProfile(fullname: String, phoneNumber: String, bankName: String, bankNumber: String) async {
        guard let current = profile else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            profile = try await service.updateProfile(
                userId: current.id,
                fullname: fullname,
                phoneNumber: phoneNumber,
                bankName: bankName,
                bankNumber: bankNumber
            )
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
    }

    func refreshProfile() async {
        guard let current = profile else { return }
        if let updated = try? await service.fetchProfile(userId: current.id) {
            profile = updated
        }
    }
}
