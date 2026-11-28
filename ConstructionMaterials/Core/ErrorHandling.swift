import Foundation

extension Notification.Name {
    /// Phát ra sau khi hóa đơn thay đổi (tạo, sửa, giao hàng, thanh toán, chốt giá, hủy).
    static let invoicesDidChange = Notification.Name("ConstructionMaterials.invoicesDidChange")
}

extension Error {
    /// Lỗi do SwiftUI/Task bị hủy khi màn hình biến mất, không phải lỗi nghiệp vụ.
    var isCancellation: Bool {
        if self is CancellationError { return true }

        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return true
        }
        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }
        return false
    }

    var userFacingMessage: String {
        if let localized = (self as? LocalizedError)?.errorDescription,
           !localized.isEmpty {
            return localized
        }
        return localizedDescription
    }
}
