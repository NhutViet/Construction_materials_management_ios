import Foundation
import Supabase

enum InvoiceServiceError: LocalizedError {
    case notFound
    case cancelled
    case emptyDelivery
    case invalidItem
    case overDelivery(String)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Không tìm thấy hóa đơn."
        case .cancelled: return "Hóa đơn đã hủy, không thể giao hàng."
        case .emptyDelivery: return "Vui lòng nhập số lượng giao."
        case .invalidItem: return "Không tìm thấy mặt hàng."
        case .overDelivery(let text): return text
        case .message(let text): return text
        }
    }
}

private struct InvoiceUpdatePayload: Encodable {
    let items: [InvoiceItem]
    let status: String?
    let subtotal: Double
    let taxAmount: Double
    let discountAmount: Double
    let totalAmount: Double
    let paidAmount: Double
    let remainingAmount: Double
    let paymentStatus: String
    let updatedAt: String
}

struct InvoiceService {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var materialService = MaterialService()

    func fetchInvoices() async throws -> [Invoice] {
        let invoices: [Invoice] = try await client
            .from("invoices")
            .select()
            .eq("isDeleted", value: false)
            .order("createdAt", ascending: false)
            .execute()
            .value
        return invoices
    }

    func fetchInvoice(id: String) async throws -> Invoice {
        let invoices: [Invoice] = try await client
            .from("invoices")
            .select()
            .eq("_id", value: id)
            .limit(1)
            .execute()
            .value
        guard let invoice = invoices.first else {
            throw InvoiceServiceError.notFound
        }
        return invoice
    }

    func fetchDeliveryRecords(invoiceId: String) async throws -> [DeliveryRecord] {
        let records: [DeliveryRecord] = try await client
            .from("delivery_records")
            .select()
            .eq("invoiceId", value: invoiceId)
            .order("deliveredAt", ascending: false)
            .execute()
            .value
        return records
    }

    func fetchAllDeliveryRecords() async throws -> [DeliveryRecord] {
        let records: [DeliveryRecord] = try await client
            .from("delivery_records")
            .select()
            .order("deliveredAt", ascending: false)
            .limit(500)
            .execute()
            .value
        return records
    }

    func updatePriceLock(
        invoice: Invoice,
        itemIndex: Int,
        locked: Bool
    ) async throws -> Invoice {
        var items = invoice.items
        guard items.indices.contains(itemIndex) else {
            throw InvoiceServiceError.invalidItem
        }

        var item = items[itemIndex]
        let delivered = item.delivered
        let remaining = item.remaining
        let originalPrice = item.originalUnitPrice ?? item.unitPrice
        let deliveredAmount = item.deliveredAmount ?? roundMoney(delivered * originalPrice)

        if locked {
            let lockedPrice = item.lockedUnitPrice ?? originalPrice
            item.priceLocked = true
            item.lockedUnitPrice = lockedPrice
            item.priceLockedAt = Formatters.nowIso()
            item.unitPrice = lockedPrice
            item.originalUnitPrice = originalPrice
            item.deliveredAmount = deliveredAmount
            item.totalPrice = roundMoney(deliveredAmount + remaining * lockedPrice)
        } else {
            let material = try? await materialService.fetchMaterial(id: item.materialId)
            let currentPrice = material?.price ?? item.unitPrice
            item.priceLocked = false
            item.priceLockedAt = Formatters.nowIso()
            item.unitPrice = currentPrice
            item.originalUnitPrice = originalPrice
            item.deliveredAmount = deliveredAmount
            item.totalPrice = roundMoney(deliveredAmount + remaining * currentPrice)
        }

        items[itemIndex] = item
        let totals = InvoiceTotals(
            items: items,
            taxRate: invoice.taxRate ?? 0,
            discountRate: invoice.discountRate ?? 0
        )
        let payment = PaymentResult(paid: invoice.paidValue, total: totals.total)

        let payload = InvoiceUpdatePayload(
            items: items,
            status: nil,
            subtotal: totals.subtotal,
            taxAmount: totals.taxAmount,
            discountAmount: totals.discountAmount,
            totalAmount: totals.total,
            paidAmount: payment.paid,
            remainingAmount: payment.remaining,
            paymentStatus: payment.status,
            updatedAt: Formatters.nowIso()
        )

        let updated: Invoice = try await client
            .from("invoices")
            .update(payload)
            .eq("_id", value: invoice.id)
            .select()
            .single()
            .execute()
            .value
        return updated
    }

    func createDelivery(
        invoice: Invoice,
        quantities: [Int: Double],
        deliveredAt: Date,
        notes: String,
        profile: Profile
    ) async throws -> Invoice {
        guard !invoice.isCancelled else {
            throw InvoiceServiceError.cancelled
        }

        let requested = quantities
            .filter { $0.value > 0 }
            .sorted { $0.key < $1.key }
        guard !requested.isEmpty else {
            throw InvoiceServiceError.emptyDelivery
        }

        let deliveredAtString = Formatters.isoWithFractionalSeconds.string(from: deliveredAt)
        let createdAt = Formatters.nowIso()
        let batchId = UUID().uuidString.lowercased()
        let deliveredByName = profile.displayName

        var items = invoice.items
        var inserts: [DeliveryRecordInsert] = []
        var stockChanges: [(materialId: String, quantity: Double)] = []

        for (index, quantity) in requested {
            guard items.indices.contains(index) else {
                throw InvoiceServiceError.invalidItem
            }

            var item = items[index]
            guard quantity <= item.remaining + 0.0001 else {
                throw InvoiceServiceError.overDelivery(
                    "\(item.materialName) chỉ còn \(Formatters.number(item.remaining)) \(item.unitValue)."
                )
            }

            let batchPrice = item.unitPrice
            let previousDeliveredAmount = item.deliveredAmount
                ?? roundMoney(item.delivered * (item.originalUnitPrice ?? item.unitPrice))
            let newDeliveredAmount = roundMoney(previousDeliveredAmount + quantity * batchPrice)
            let newDelivered = roundMoney(item.delivered + quantity)
            let remainingAfter = max(0, item.quantity - newDelivered)
            let newTotalPrice = roundMoney(newDeliveredAmount + remainingAfter * batchPrice)

            item.deliveredQuantity = newDelivered
            item.deliveredAmount = newDeliveredAmount
            item.totalPrice = newTotalPrice
            item.deliveryStatus = newDelivered >= item.quantity ? "delivered" : "partial"
            item.deliveredAt = deliveredAtString
            item.deliveredBy = profile.id
            item.originalUnitPrice = item.originalUnitPrice ?? batchPrice
            item.originalTotalPrice = item.originalTotalPrice ?? roundMoney(batchPrice * item.quantity)
            items[index] = item

            inserts.append(
                DeliveryRecordInsert(
                    invoiceId: invoice.id,
                    invoiceNumber: invoice.invoiceNumber,
                    batchId: batchId,
                    itemIndex: index,
                    materialId: item.materialId,
                    materialName: item.materialName,
                    unit: item.unitValue,
                    quantity: quantity,
                    deliveredAt: deliveredAtString,
                    deliveredBy: profile.id,
                    deliveredByName: deliveredByName,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    createdAt: createdAt
                )
            )

            if item.shouldDeductStock, let materialId = item.materialId {
                stockChanges.append((materialId, quantity))
            }
        }

        let allDelivered = items.allSatisfy { $0.remaining <= 0 }
        let anyDelivered = items.contains { $0.delivered > 0 }
        let status = allDelivered ? "delivered" : (anyDelivered ? "confirmed" : invoice.status)

        let totals = InvoiceTotals(
            items: items,
            taxRate: invoice.taxRate ?? 0,
            discountRate: invoice.discountRate ?? 0
        )
        let payment = PaymentResult(paid: invoice.paidValue, total: totals.total)

        let payload = InvoiceUpdatePayload(
            items: items,
            status: status,
            subtotal: totals.subtotal,
            taxAmount: totals.taxAmount,
            discountAmount: totals.discountAmount,
            totalAmount: totals.total,
            paidAmount: payment.paid,
            remainingAmount: payment.remaining,
            paymentStatus: payment.status,
            updatedAt: createdAt
        )

        let updated: Invoice = try await client
            .from("invoices")
            .update(payload)
            .eq("_id", value: invoice.id)
            .select()
            .single()
            .execute()
            .value

        _ = try await client
            .from("delivery_records")
            .insert(inserts)
            .execute()

        for change in stockChanges {
            guard let material = try? await materialService.fetchMaterial(id: change.materialId) else {
                continue
            }
            let newQuantity = max(0, (material.quantity ?? 0) - change.quantity)
            try? await materialService.updateQuantity(id: change.materialId, quantity: newQuantity)
        }

        return updated
    }
}
