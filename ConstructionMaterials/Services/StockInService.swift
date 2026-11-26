import Foundation
import Supabase

enum StockInServiceError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

struct StockInService {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var materialService = MaterialService()

    func fetchStockIns() async throws -> [StockIn] {
        let stockIns: [StockIn] = try await client
            .from("stock_in")
            .select()
            .eq("isDeleted", value: false)
            .order("createdAt", ascending: false)
            .execute()
            .value
        return stockIns
    }

    func createStockIn(
        supplier: String,
        supplierPhone: String,
        supplierAddress: String,
        drafts: [StockInDraftItem],
        taxRate: Double,
        discountRate: Double,
        paidAmount: Double,
        notes: String,
        profile: Profile
    ) async throws -> StockIn {
        guard !drafts.isEmpty else {
            throw StockInServiceError.message("Vui lòng thêm ít nhất một mặt hàng.")
        }

        let items = drafts.map { draft in
            StockInInsertItem(
                materialId: draft.material.id,
                materialName: draft.material.name,
                quantity: draft.quantity,
                unitPrice: draft.unitPrice,
                totalPrice: draft.total,
                unit: draft.material.unit ?? ""
            )
        }

        let subtotal = roundMoney(items.reduce(0) { $0 + $1.totalPrice })
        let taxAmount = roundMoney(subtotal * taxRate / 100)
        let discountAmount = roundMoney(subtotal * discountRate / 100)
        let total = roundMoney(subtotal + taxAmount - discountAmount)
        let payment = PaymentResult(paid: paidAmount, total: total)
        let now = Formatters.nowIso()
        let suffix = String(Int(Date().timeIntervalSince1970 * 1000)).suffix(8)

        let payload = StockInInsertPayload(
            stockInNumber: "PN-\(suffix)",
            userId: profile.id,
            items: items,
            subtotal: subtotal,
            taxRate: taxRate,
            taxAmount: taxAmount,
            discountRate: discountRate,
            discountAmount: discountAmount,
            totalAmount: total,
            paymentStatus: payment.status,
            paidAmount: payment.paid,
            remainingAmount: payment.remaining,
            paymentNotes: "",
            status: "pending",
            supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
            supplierPhone: supplierPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            supplierAddress: supplierAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            receivedDate: now,
            createdBy: profile.id,
            isDeleted: false,
            createdAt: now,
            updatedAt: now
        )

        let stockIn: StockIn = try await client
            .from("stock_in")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        for draft in drafts {
            guard let material = try? await materialService.fetchMaterial(id: draft.material.id) else {
                continue
            }
            let newQuantity = (material.quantity ?? 0) + draft.quantity
            try? await materialService.updateQuantity(id: draft.material.id, quantity: newQuantity)
        }

        return stockIn
    }
}
