import Foundation
import Supabase

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
        return try? await fetchProfile(userId: session.user.id.uuidString)
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
