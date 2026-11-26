import Foundation

struct InvoiceItem: Codable {
    var materialId: String?
    var materialName: String
    var quantity: Double
    var unitPrice: Double
    var totalPrice: Double
    var unit: String?
    var deliveredQuantity: Double?
    var deliveredAmount: Double?
    var deliveryStatus: String?
    var deliveredAt: String?
    var deliveredBy: String?
    var originalUnitPrice: Double?
    var originalTotalPrice: Double?
    var adjustedUnitPrice: Double?
    var adjustedTotalPrice: Double?
    var priceAdjustmentAmount: Double?
    var priceAdjustmentReason: String?
    var priceAdjustedAt: String?
    var priceLocked: Bool?
    var lockedUnitPrice: Double?
    var priceLockedAt: String?
    var stockDeductedAtCreation: Bool?

    var delivered: Double { deliveredQuantity ?? 0 }
    var remaining: Double { max(0, quantity - delivered) }
    var progress: Double { quantity > 0 ? min(1, delivered / quantity) : 0 }
    var isFullyDelivered: Bool { remaining <= 0 }
    var isLocked: Bool { priceLocked == true }
    var unitValue: String { unit?.isEmpty == false ? unit! : "đơn vị" }

    var computedDeliveryStatus: String {
        if isFullyDelivered { return "delivered" }
        if delivered > 0 { return "partial" }
        return "pending"
    }

    var shouldDeductStock: Bool { stockDeductedAtCreation == false }
}

struct Invoice: Codable, Identifiable {
    let id: String
    var invoiceNumber: String
    var customerName: String
    var customerPhone: String?
    var customerAddress: String?
    var items: [InvoiceItem]
    var subtotal: Double?
    var taxRate: Double?
    var taxAmount: Double?
    var discountRate: Double?
    var discountAmount: Double?
    var totalAmount: Double?
    var status: String
    var paymentMethod: String?
    var paymentStatus: String?
    var paidAmount: Double?
    var remainingAmount: Double?
    var notes: String?
    var deliveryDate: String?
    var isDeleted: Bool?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case invoiceNumber, customerName, customerPhone, customerAddress
        case items, subtotal, taxRate, taxAmount, discountRate, discountAmount, totalAmount
        case status, paymentMethod, paymentStatus, paidAmount, remainingAmount
        case notes, deliveryDate, isDeleted, createdAt, updatedAt
    }

    var totalValue: Double { totalAmount ?? 0 }
    var paidValue: Double { paidAmount ?? 0 }
    var remainingValue: Double { remainingAmount ?? max(0, totalValue - paidValue) }
    var customerPhoneValue: String { customerPhone?.isEmpty == false ? customerPhone! : "—" }
    var customerAddressValue: String { customerAddress?.isEmpty == false ? customerAddress! : "—" }
    var isCancelled: Bool { status == "cancelled" }

    var totalQuantity: Double { items.reduce(0) { $0 + $1.quantity } }
    var deliveredQuantity: Double { items.reduce(0) { $0 + $1.delivered } }
    var deliveryProgress: Double {
        totalQuantity > 0 ? min(1, deliveredQuantity / totalQuantity) : 0
    }
    var remainingItems: [(index: Int, item: InvoiceItem)] {
        Array(items.enumerated())
            .filter { $0.element.remaining > 0 }
            .map { (index: $0.offset, item: $0.element) }
    }
    var canDeliver: Bool { !isCancelled && !remainingItems.isEmpty }
}

struct InvoiceTotals {
    let subtotal: Double
    let taxAmount: Double
    let discountAmount: Double
    let total: Double

    init(items: [InvoiceItem], taxRate: Double, discountRate: Double) {
        let subtotalValue = roundMoney(items.reduce(0) { $0 + $1.totalPrice })
        subtotal = subtotalValue
        taxAmount = roundMoney(subtotalValue * taxRate / 100)
        discountAmount = roundMoney(subtotalValue * discountRate / 100)
        total = roundMoney(subtotalValue + taxAmount - discountAmount)
    }
}

struct PaymentResult {
    let paid: Double
    let remaining: Double
    let status: String

    init(paid: Double, total: Double) {
        let paidValue = max(0, roundMoney(paid))
        let totalValue = max(0, roundMoney(total))
        let remainingValue = max(0, roundMoney(totalValue - paidValue))
        self.paid = paidValue
        self.remaining = remainingValue
        self.status = remainingValue == 0 ? "paid" : (paidValue > 0 ? "partial" : "unpaid")
    }
}
