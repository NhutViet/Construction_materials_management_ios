import Foundation

struct StockInItem: Codable {
    var materialId: String?
    var materialName: String
    var quantity: Double
    var unitPrice: Double
    var totalPrice: Double
    var unit: String?
}

struct StockIn: Codable, Identifiable {
    let id: String
    var stockInNumber: String
    var items: [StockInItem]
    var subtotal: Double?
    var taxRate: Double?
    var taxAmount: Double?
    var discountRate: Double?
    var discountAmount: Double?
    var totalAmount: Double?
    var paymentStatus: String?
    var paidAmount: Double?
    var remainingAmount: Double?
    var paymentNotes: String?
    var status: String
    var supplier: String?
    var supplierPhone: String?
    var supplierAddress: String?
    var notes: String?
    var receivedDate: String?
    var createdBy: String?
    var approvedBy: String?
    var approvedAt: String?
    var isDeleted: Bool?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case stockInNumber, items, subtotal, taxRate, taxAmount, discountRate, discountAmount
        case totalAmount, paymentStatus, paidAmount, remainingAmount, paymentNotes, status
        case supplier, supplierPhone, supplierAddress, notes, receivedDate
        case createdBy, approvedBy, approvedAt, isDeleted, createdAt, updatedAt
    }

    var totalValue: Double { totalAmount ?? 0 }
    var paidValue: Double { paidAmount ?? 0 }
    var remainingValue: Double { remainingAmount ?? max(0, totalValue - paidValue) }
    var supplierValue: String { supplier?.isEmpty == false ? supplier! : "—" }
    var itemCount: Int { items.count }
}

struct StockInInsertItem: Encodable {
    let materialId: String?
    let materialName: String
    let quantity: Double
    let unitPrice: Double
    let totalPrice: Double
    let unit: String
}

struct StockInInsertPayload: Encodable {
    let stockInNumber: String
    let userId: String
    let items: [StockInInsertItem]
    let subtotal: Double
    let taxRate: Double
    let taxAmount: Double
    let discountRate: Double
    let discountAmount: Double
    let totalAmount: Double
    let paymentStatus: String
    let paidAmount: Double
    let remainingAmount: Double
    let paymentNotes: String
    let status: String
    let supplier: String
    let supplierPhone: String
    let supplierAddress: String
    let notes: String
    let receivedDate: String
    let createdBy: String
    let isDeleted: Bool
    let createdAt: String
    let updatedAt: String
}

struct StockInDraftItem: Identifiable {
    let id = UUID()
    var material: Material
    var quantity: Double
    var unitPrice: Double
    var isNewMaterial: Bool = false

    var total: Double { roundMoney(quantity * unitPrice) }
}

struct StockInItemInput {
    let materialId: String?
    let materialName: String
    let unit: String
    let quantity: Double
    let unitPrice: Double
}
