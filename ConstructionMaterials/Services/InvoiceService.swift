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

private struct InvoiceInsertPayload: Encodable {
    let invoiceNumber: String
    let customerId: String
    let customerName: String
    let customerPhone: String
    let customerAddress: String
    let items: [InvoiceItem]
    let subtotal: Double
    let taxRate: Double
    let taxAmount: Double
    let discountRate: Double
    let discountAmount: Double
    let totalAmount: Double
    let status: String
    let paymentMethod: String
    let paymentStatus: String
    let paidAmount: Double
    let remainingAmount: Double
    let notes: String
    let deliveryDate: String?
    let createdBy: String
    let isDeleted: Bool
    let createdAt: String
    let updatedAt: String
}

private struct InvoicePaymentPayload: Encodable {
    let paidAmount: Double
    let remainingAmount: Double
    let paymentStatus: String
    let paymentMethod: String
    let notes: String
    let updatedAt: String
}

extension InvoiceService {
    func createInvoice(
        customerName: String,
        customerPhone: String,
        customerAddress: String,
        drafts: [InvoiceDraftItem],
        taxRate: Double,
        discountRate: Double,
        paidAmount: Double,
        paymentMethod: String,
        notes: String,
        profile: Profile
    ) async throws -> Invoice {
        let name = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw InvoiceServiceError.message("Vui lòng nhập tên khách hàng.")
        }
        guard !drafts.isEmpty else {
            throw InvoiceServiceError.message("Vui lòng thêm ít nhất một mặt hàng.")
        }

        let items = drafts.map { draft in
            let total = roundMoney(draft.unitPrice * draft.quantity)
            return InvoiceItem(
                materialId: draft.material.id,
                materialName: draft.material.name,
                quantity: draft.quantity,
                unitPrice: draft.unitPrice,
                totalPrice: total,
                unit: draft.material.unit
            )
        }

        let totals = InvoiceTotals(items: items, taxRate: taxRate, discountRate: discountRate)
        let payment = PaymentResult(paid: paidAmount, total: totals.total)
        let now = Formatters.nowIso()
        let suffix = String(Int(Date().timeIntervalSince1970 * 1000)).suffix(8)
        let phone = customerPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = customerAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = InvoiceInsertPayload(
            invoiceNumber: "HD-\(suffix)",
            customerId: phone.isEmpty ? name : phone,
            customerName: name,
            customerPhone: phone,
            customerAddress: address,
            items: items,
            subtotal: totals.subtotal,
            taxRate: taxRate,
            taxAmount: totals.taxAmount,
            discountRate: discountRate,
            discountAmount: totals.discountAmount,
            totalAmount: totals.total,
            status: "pending",
            paymentMethod: paymentMethod,
            paymentStatus: payment.status,
            paidAmount: payment.paid,
            remainingAmount: payment.remaining,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            deliveryDate: nil,
            createdBy: profile.id,
            isDeleted: false,
            createdAt: now,
            updatedAt: now
        )

        let invoice: Invoice = try await client
            .from("invoices")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return invoice
    }

    func addPayment(
        invoice: Invoice,
        amount: Double,
        method: String,
        notes: String
    ) async throws -> Invoice {
        guard amount > 0 else {
            throw InvoiceServiceError.message("Số tiền thanh toán phải lớn hơn 0.")
        }

        let payment = PaymentResult(
            paid: invoice.paidValue + amount,
            total: invoice.totalValue
        )
        let payload = InvoicePaymentPayload(
            paidAmount: payment.paid,
            remainingAmount: payment.remaining,
            paymentStatus: payment.status,
            paymentMethod: method,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (invoice.notes ?? "")
                : notes.trimmingCharacters(in: .whitespacesAndNewlines),
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
}

private struct InvoiceEditPayload: Encodable {
    let customerName: String
    let customerPhone: String
    let customerAddress: String
    let items: [InvoiceItem]
    let subtotal: Double
    let taxRate: Double
    let taxAmount: Double
    let discountRate: Double
    let discountAmount: Double
    let totalAmount: Double
    let paymentMethod: String
    let paidAmount: Double
    let remainingAmount: Double
    let paymentStatus: String
    let notes: String
    let deliveryDate: String?
    let updatedAt: String
}

private struct InvoiceStatusPayload: Encodable {
    let status: String
    let notes: String
    let updatedAt: String
}

extension InvoiceService {
    func updateInvoice(
        invoice: Invoice,
        customerName: String,
        customerPhone: String,
        customerAddress: String,
        taxRate: Double,
        discountRate: Double,
        paymentMethod: String,
        notes: String,
        deliveryDate: String?,
        inputs: [InvoiceItemInput]
    ) async throws -> Invoice {
        let name = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw InvoiceServiceError.message("Vui lòng nhập tên khách hàng.")
        }
        guard !inputs.isEmpty else {
            throw InvoiceServiceError.message("Hóa đơn phải có ít nhất một mặt hàng.")
        }

        var items: [InvoiceItem] = []
        for input in inputs {
            let oldItem = invoice.items.first {
                $0.materialId != nil && $0.materialId == input.materialId
            } ?? invoice.items.first { $0.materialName == input.materialName }

            if let oldItem, oldItem.delivered > 0, input.quantity < oldItem.delivered - 0.0001 {
                throw InvoiceServiceError.message(
                    "\"\(oldItem.materialName)\" đã giao \(Formatters.number(oldItem.delivered)) \(oldItem.unitValue), không thể giảm số lượng xuống \(Formatters.number(input.quantity))."
                )
            }

            if let oldItem {
                let delivered = roundMoney(min(oldItem.delivered, input.quantity))
                let deliveredAmount = oldItem.deliveredAmount
                    ?? roundMoney(delivered * (oldItem.originalUnitPrice ?? oldItem.unitPrice))
                let remaining = max(0, input.quantity - delivered)
                var item = oldItem
                item.materialName = input.materialName
                item.unit = input.unit
                item.quantity = input.quantity
                item.unitPrice = input.unitPrice
                item.deliveredQuantity = delivered
                item.deliveredAmount = deliveredAmount
                item.totalPrice = roundMoney(deliveredAmount + remaining * input.unitPrice)
                item.deliveryStatus = delivered >= input.quantity ? "delivered" : (delivered > 0 ? "partial" : "pending")
                item.originalUnitPrice = oldItem.originalUnitPrice ?? oldItem.unitPrice
                item.originalTotalPrice = oldItem.originalTotalPrice
                    ?? roundMoney((oldItem.originalUnitPrice ?? oldItem.unitPrice) * input.quantity)
                items.append(item)
            } else {
                items.append(
                    InvoiceItem(
                        materialId: input.materialId,
                        materialName: input.materialName,
                        quantity: input.quantity,
                        unitPrice: input.unitPrice,
                        totalPrice: roundMoney(input.unitPrice * input.quantity),
                        unit: input.unit
                    )
                )
            }
        }

        for oldItem in invoice.items where oldItem.delivered > 0 {
            let kept = items.contains {
                ($0.materialId != nil && $0.materialId == oldItem.materialId)
                    || ($0.materialId == nil && $0.materialName == oldItem.materialName)
            }
            if !kept {
                throw InvoiceServiceError.message(
                    "Không thể xóa mặt hàng \"\(oldItem.materialName)\" vì đã giao \(Formatters.number(oldItem.delivered)) \(oldItem.unitValue)."
                )
            }
        }

        let totals = InvoiceTotals(items: items, taxRate: taxRate, discountRate: discountRate)
        let payment = PaymentResult(paid: invoice.paidValue, total: totals.total)
        let payload = InvoiceEditPayload(
            customerName: name,
            customerPhone: customerPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            customerAddress: customerAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            items: items,
            subtotal: totals.subtotal,
            taxRate: taxRate,
            taxAmount: totals.taxAmount,
            discountRate: discountRate,
            discountAmount: totals.discountAmount,
            totalAmount: totals.total,
            paymentMethod: paymentMethod,
            paidAmount: payment.paid,
            remainingAmount: payment.remaining,
            paymentStatus: payment.status,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            deliveryDate: deliveryDate,
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

    func updateStatus(invoice: Invoice, status: String) async throws -> Invoice {
        if status == "delivered" {
            guard invoice.items.allSatisfy({ $0.remaining <= 0.0001 }) else {
                throw InvoiceServiceError.message(
                    "Hóa đơn còn hàng chưa giao. Vui lòng ghi nhận giao đủ trước khi chuyển sang trạng thái Đã giao."
                )
            }
        }
        let payload = InvoiceStatusPayload(
            status: status,
            notes: invoice.notes ?? "",
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
}

extension InvoiceService {
    /// Khi giá vật tư thay đổi, chỉ cập nhật phần chưa giao của các hóa đơn.
    /// Phần đã giao giữ nguyên giá và thành tiền; mặt hàng đã chốt giá được bỏ qua.
    func repriceRemainingItems(materialId: String, newPrice: Double) async throws -> [Invoice] {
        let activeInvoices = try await fetchInvoices().filter { !$0.isCancelled }
        var updatedInvoices: [Invoice] = []

        for invoice in activeInvoices {
            guard invoice.items.contains(where: { $0.materialId == materialId }) else { continue }

            var items = invoice.items
            var changed = false

            for index in items.indices where items[index].materialId == materialId {
                var item = items[index]
                if item.isLocked { continue }

                let delivered = item.delivered
                let remaining = item.remaining
                let deliveredAmount = item.deliveredAmount
                    ?? roundMoney(delivered * (item.originalUnitPrice ?? item.unitPrice))

                if remaining <= 0 {
                    let normalizedTotal = roundMoney(deliveredAmount)
                    if abs(normalizedTotal - item.totalPrice) > 0.001 {
                        item.deliveredAmount = deliveredAmount
                        item.totalPrice = normalizedTotal
                        changed = true
                        items[index] = item
                    }
                    continue
                }

                let originalUnitPrice = item.originalUnitPrice ?? item.unitPrice
                let oldTotal = roundMoney(deliveredAmount + remaining * item.unitPrice)
                let newTotal = roundMoney(deliveredAmount + remaining * newPrice)
                guard abs(newTotal - oldTotal) > 0.001 else { continue }

                item.originalUnitPrice = originalUnitPrice
                item.originalTotalPrice = item.originalTotalPrice
                    ?? roundMoney(originalUnitPrice * item.quantity)
                item.unitPrice = newPrice
                item.totalPrice = newTotal
                item.deliveredAmount = deliveredAmount
                item.adjustedUnitPrice = newPrice
                item.adjustedTotalPrice = newTotal
                item.priceAdjustmentAmount = roundMoney(
                    newTotal - (deliveredAmount + remaining * originalUnitPrice)
                )
                item.priceAdjustmentReason = "Cập nhật giá vật tư"
                item.priceAdjustedAt = Formatters.nowIso()
                changed = true
                items[index] = item
            }

            guard changed else { continue }

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
            updatedInvoices.append(updated)
        }

        return updatedInvoices
    }
}
