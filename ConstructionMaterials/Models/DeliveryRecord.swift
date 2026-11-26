import Foundation

struct DeliveryRecord: Codable, Identifiable {
    let id: String
    var invoiceId: String
    var invoiceNumber: String?
    var batchId: String
    var itemIndex: Int
    var materialId: String?
    var materialName: String
    var unit: String?
    var quantity: Double
    var deliveredAt: String?
    var deliveredByName: String?
    var notes: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case invoiceId, invoiceNumber, batchId, itemIndex, materialId
        case materialName, unit, quantity, deliveredAt, deliveredByName, notes, createdAt
    }
}

struct DeliveryRecordInsert: Encodable {
    let invoiceId: String
    let invoiceNumber: String
    let batchId: String
    let itemIndex: Int
    let materialId: String?
    let materialName: String
    let unit: String
    let quantity: Double
    let deliveredAt: String
    let deliveredBy: String
    let deliveredByName: String
    let notes: String
    let createdAt: String
}

struct DeliveryBatch: Identifiable {
    let id: String
    let invoiceId: String
    let invoiceNumber: String?
    let deliveredAt: String?
    let deliveredByName: String?
    let notes: String?
    let items: [DeliveryRecord]

    var totalQuantity: Double { items.reduce(0) { $0 + $1.quantity } }

    static func group(_ records: [DeliveryRecord]) -> [DeliveryBatch] {
        let grouped = Dictionary(grouping: records, by: { $0.batchId })
        return grouped.map { batchId, values in
            let sortedValues = values.sorted { ($0.itemIndex) < ($1.itemIndex) }
            let first = sortedValues.first
            return DeliveryBatch(
                id: batchId,
                invoiceId: first?.invoiceId ?? "",
                invoiceNumber: first?.invoiceNumber,
                deliveredAt: first?.deliveredAt,
                deliveredByName: first?.deliveredByName,
                notes: first?.notes,
                items: sortedValues
            )
        }
        .sorted { ($0.deliveredAt ?? "") > ($1.deliveredAt ?? "") }
    }
}
