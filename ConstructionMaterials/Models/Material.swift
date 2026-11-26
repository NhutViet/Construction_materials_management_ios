import Foundation

struct Material: Codable, Identifiable {
    let id: String
    var name: String
    var category: String?
    var price: Double?
    var importCost: Double?
    var quantity: Double?
    var unit: String?
    var supplier: String?
    var description: String?
    var minStock: Double?
    var maxStock: Double?
    var location: String?
    var isActive: Bool?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, category, price, importCost, quantity, unit, supplier, description
        case minStock, maxStock, location, isActive, createdAt, updatedAt
    }

    var quantityValue: Double { quantity ?? 0 }
    var minStockValue: Double { minStock ?? 10 }
    var isLowStock: Bool { quantityValue <= minStockValue }
    var priceValue: Double { price ?? 0 }
    var unitValue: String { unit?.isEmpty == false ? unit! : "đơn vị" }
}
