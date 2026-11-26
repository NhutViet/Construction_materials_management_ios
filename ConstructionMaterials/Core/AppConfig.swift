import Foundation

enum AppConfig {
    static var supabaseURL: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: raw)
        else {
            fatalError("Thiếu SupabaseURL trong Info.plist / Config/Secrets.xcconfig")
        }
        return url
    }

    static var supabaseKey: String {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !key.isEmpty
        else {
            fatalError("Thiếu SupabaseAnonKey trong Info.plist / Config/Secrets.xcconfig")
        }
        return key
    }
}
