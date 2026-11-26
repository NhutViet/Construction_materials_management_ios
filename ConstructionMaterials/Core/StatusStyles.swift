import SwiftUI

enum InvoiceStatus {
    static func text(_ value: String) -> String {
        switch value {
        case "pending": return "Chờ xử lý"
        case "confirmed": return "Đang giao một phần"
        case "delivered": return "Đã giao"
        case "cancelled": return "Đã hủy"
        case "shipped": return "Đang giao"
        default: return value.isEmpty ? "—" : value
        }
    }

    static func color(_ value: String) -> Color {
        switch value {
        case "delivered": return AppTheme.success
        case "confirmed": return AppTheme.info
        case "cancelled": return AppTheme.danger
        default: return AppTheme.warning
        }
    }
}

enum PaymentStatus {
    static func text(_ value: String?) -> String {
        switch value {
        case "paid": return "Đã thanh toán"
        case "partial": return "Thanh toán một phần"
        case "unpaid": return "Chưa thanh toán"
        default: return "—"
        }
    }

    static func color(_ value: String?) -> Color {
        switch value {
        case "paid": return AppTheme.success
        case "partial": return AppTheme.warning
        default: return AppTheme.danger
        }
    }
}

enum DeliveryStatus {
    static func text(_ value: String?) -> String {
        switch value {
        case "delivered": return "Đã giao"
        case "partial": return "Giao một phần"
        default: return "Chờ giao"
        }
    }

    static func color(_ value: String?) -> Color {
        switch value {
        case "delivered": return AppTheme.success
        case "partial": return AppTheme.info
        default: return AppTheme.warning
        }
    }
}
