import Foundation
import Supabase

extension Notification.Name {
    /// Phát ra khi phiên đăng nhập không còn hợp lệ để AuthStore đưa người dùng về màn hình đăng nhập.
    static let authSessionExpired = Notification.Name("ConstructionMaterials.authSessionExpired")
}

enum AuthServiceError: LocalizedError {
    case invalidCredentials
    case profileNotFound
    case missingSession
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Sai tên đăng nhập hoặc mật khẩu."
        case .profileNotFound:
            return "Không tìm thấy hồ sơ người dùng."
        case .missingSession:
            return "Phiên đăng nhập đã hết hạn."
        case .message(let text):
            return text
        }
    }
}

struct AuthService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func restoreProfile() async -> Profile? {
        guard let session = client.auth.currentSession else { return nil }

        do {
            // Access token hết hạn nhưng refresh token còn hiệu lực: chủ động làm mới.
            // Nếu không làm mới, các request đọc bảng chỉ dành cho authenticated
            // (ví dụ materials) sẽ bị trả về rỗng dù người dùng vẫn thấy giao diện chính.
            if isExpired(session) {
                _ = try await client.auth.refreshSession()
            }
            let user = try await client.auth.user()
            return try await fetchProfile(userId: user.id.uuidString)
        } catch {
            try? await client.auth.signOut()
            return nil
        }
    }

    /// Kiểm tra nhanh phiên đăng nhập khi app quay lại foreground.
    /// Chỉ gọi mạng khi access token đã hết hạn để tránh đăng xuất oan khi mất mạng.
    func validateSessionIfNeeded() async -> Bool {
        guard let session = client.auth.currentSession else {
            notifyExpired()
            return false
        }
        guard isExpired(session) else { return true }

        do {
            _ = try await client.auth.refreshSession()
            return true
        } catch {
            try? await client.auth.signOut()
            notifyExpired()
            return false
        }
    }

    /// Xác thực mạnh với server. Dùng khi dữ liệu chỉ dành cho authenticated trả về rỗng
    /// để phân biệt "không có dữ liệu" với "mất phiên đăng nhập".
    func hasValidSession() async -> Bool {
        guard let session = client.auth.currentSession else {
            notifyExpired()
            return false
        }

        if isExpired(session) {
            do {
                _ = try await client.auth.refreshSession()
            } catch {
                try? await client.auth.signOut()
                notifyExpired()
                return false
            }
        }

        do {
            _ = try await client.auth.user()
            return true
        } catch {
            try? await client.auth.signOut()
            notifyExpired()
            return false
        }
    }

    private func isExpired(_ session: Session) -> Bool {
        session.expiresAt <= Date().addingTimeInterval(30).timeIntervalSince1970
    }

    private func notifyExpired() {
        NotificationCenter.default.post(name: .authSessionExpired, object: nil)
    }

    func signIn(username: String, password: String) async throws -> Profile {
        let input = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !password.isEmpty else {
            throw AuthServiceError.invalidCredentials
        }

        var email = input
        if !input.contains("@") {
            let profiles: [Profile] = try await client
                .from("profiles")
                .select()
                .eq("username", value: input)
                .limit(1)
                .execute()
                .value
            guard let profile = profiles.first,
                  let profileEmail = profile.email,
                  !profileEmail.isEmpty else {
                throw AuthServiceError.invalidCredentials
            }
            email = profileEmail
        }

        let session = try await client.auth.signIn(email: email, password: password)
        return try await fetchProfile(userId: session.user.id.uuidString)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func fetchProfile(userId: String) async throws -> Profile {
        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        guard let profile = profiles.first else {
            throw AuthServiceError.profileNotFound
        }
        return profile
    }
}

private struct ProfileUpdatePayload: Encodable {
    let fullname: String
    let phoneNumber: String
    let bankName: String
    let bankNumber: String
}

extension AuthService {
    func updateProfile(
        userId: String,
        fullname: String,
        phoneNumber: String,
        bankName: String,
        bankNumber: String
    ) async throws -> Profile {
        let payload = ProfileUpdatePayload(
            fullname: fullname.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines),
            bankNumber: bankNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let profile: Profile = try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value
        return profile
    }
}
