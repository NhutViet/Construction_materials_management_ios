import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: String
    var username: String?
    var fullname: String?
    var email: String?
    var phoneNumber: String?
    var bankName: String?
    var bankNumber: String?
    var role: String?
    var createdAt: String?
    var updatedAt: String?

    var displayName: String {
        fullname?.isEmpty == false ? fullname! : (username ?? "Người dùng")
    }

    var initials: String {
        let source = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = source.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "U" : String(letters).uppercased()
    }
}
