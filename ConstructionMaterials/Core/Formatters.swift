import Foundation

enum Formatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    static let displayDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()

    static func money(_ value: Double?) -> String {
        "\(currency.string(from: NSNumber(value: value ?? 0)) ?? "0") ₫"
    }

    static func number(_ value: Double?) -> String {
        decimal.string(from: NSNumber(value: value ?? 0)) ?? "0"
    }

    static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return isoWithFractionalSeconds.date(from: raw) ?? iso.date(from: raw)
    }

    static func date(_ raw: String?) -> String {
        guard let date = parseDate(raw) else { return "—" }
        return displayDate.string(from: date)
    }

    static func dateTime(_ raw: String?) -> String {
        guard let date = parseDate(raw) else { return "—" }
        return displayDateTime.string(from: date)
    }

    static func nowIso() -> String {
        isoWithFractionalSeconds.string(from: Date())
    }
}

func roundMoney(_ value: Double) -> Double {
    (value * 100).rounded() / 100
}
