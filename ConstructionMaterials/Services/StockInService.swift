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

        var quantityByMaterial: [String: Double] = [:]
        var latestImportCostByMaterial: [String: Double] = [:]
        for draft in drafts {
            quantityByMaterial[draft.material.id, default: 0] += draft.quantity
            latestImportCostByMaterial[draft.material.id] = draft.unitPrice
        }

        struct StockUpdate {
            let id: String
            let oldQuantity: Double
            let oldImportCost: Double
            let newQuantity: Double
            let newImportCost: Double
        }

        do {
            var updates: [StockUpdate] = []
            for (materialId, quantity) in quantityByMaterial {
                guard let material = try await materialService.fetchMaterial(id: materialId) else {
                    throw StockInServiceError.message("Không tìm thấy vật tư để cộng tồn kho.")
                }
                let oldQuantity = material.quantity ?? 0
                let oldImportCost = material.importCost ?? 0
                updates.append(
                    StockUpdate(
                        id: materialId,
                        oldQuantity: oldQuantity,
                        oldImportCost: oldImportCost,
                        newQuantity: oldQuantity + quantity,
                        newImportCost: latestImportCostByMaterial[materialId] ?? oldImportCost
                    )
                )
            }

            var applied: [StockUpdate] = []
            do {
                for update in updates {
                    try await materialService.updateStock(
                        id: update.id,
                        quantity: update.newQuantity,
                        importCost: update.newImportCost
                    )
                    applied.append(update)
                }
            } catch {
                // Hoàn tác các vật tư đã cập nhật trước đó (best effort).
                for update in applied.reversed() {
                    try? await materialService.updateStock(
                        id: update.id,
                        quantity: update.oldQuantity,
                        importCost: update.oldImportCost
                    )
                }
                throw error
            }
        } catch {
            // Không để lại phiếu nhập nếu tồn kho không cập nhật được.
            _ = try? await client
                .from("stock_in")
                .delete()
                .eq("_id", value: stockIn.id)
                .execute()
            throw error
        }

        return stockIn
    }
}

private struct StockInUpdatePayload: Encodable {
    let supplier: String
    let supplierPhone: String
    let supplierAddress: String
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
    let notes: String
    let receivedDate: String?
    let updatedAt: String
}

private struct StockInDeletePayload: Encodable {
    let isDeleted: Bool
    let updatedAt: String
}

extension StockInService {
    func fetchStockIn(id: String) async throws -> StockIn {
        let results: [StockIn] = try await client
            .from("stock_in")
            .select()
            .eq("_id", value: id)
            .eq("isDeleted", value: false)
            .limit(1)
            .execute()
            .value
        guard let stockIn = results.first else {
            throw StockInServiceError.message("Không tìm thấy phiếu nhập.")
        }
        return stockIn
    }

    func updateStockIn(
        stockIn: StockIn,
        supplier: String,
        supplierPhone: String,
        supplierAddress: String,
        inputs: [StockInItemInput],
        taxRate: Double,
        discountRate: Double,
        paidAmount: Double,
        notes: String
    ) async throws -> StockIn {
        guard !inputs.isEmpty else {
            throw StockInServiceError.message("Phiếu nhập phải có ít nhất một mặt hàng.")
        }

        let items = inputs.map { input in
            StockInInsertItem(
                materialId: input.materialId,
                materialName: input.materialName,
                quantity: input.quantity,
                unitPrice: input.unitPrice,
                totalPrice: roundMoney(input.quantity * input.unitPrice),
                unit: input.unit
            )
        }

        let subtotal = roundMoney(items.reduce(0) { $0 + $1.totalPrice })
        let taxAmount = roundMoney(subtotal * taxRate / 100)
        let discountAmount = roundMoney(subtotal * discountRate / 100)
        let total = roundMoney(subtotal + taxAmount - discountAmount)
        let payment = PaymentResult(paid: min(max(0, paidAmount), total), total: total)

        let payload = StockInUpdatePayload(
            supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
            supplierPhone: supplierPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            supplierAddress: supplierAddress.trimmingCharacters(in: .whitespacesAndNewlines),
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
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            receivedDate: stockIn.receivedDate,
            updatedAt: Formatters.nowIso()
        )

        let updated: StockIn = try await client
            .from("stock_in")
            .update(payload)
            .eq("_id", value: stockIn.id)
            .select()
            .single()
            .execute()
            .value

        let oldQuantities = aggregate(stockIn.items)
        let newQuantities = aggregate(items)
        let affected = Set(oldQuantities.keys).union(newQuantities.keys)

        for materialId in affected {
            let delta = (newQuantities[materialId] ?? 0) - (oldQuantities[materialId] ?? 0)
            guard abs(delta) > 0.0001 else { continue }
            guard let material = try await materialService.fetchMaterial(id: materialId) else { continue }
            let newStock = max(0, (material.quantity ?? 0) + delta)
            try await materialService.updateQuantity(id: materialId, quantity: newStock)
        }

        try await recalculateImportCosts(materialIds: affected)
        return updated
    }

    func deleteStockIn(_ stockIn: StockIn) async throws {
        let payload = StockInDeletePayload(isDeleted: true, updatedAt: Formatters.nowIso())
        _ = try await client
            .from("stock_in")
            .update(payload)
            .eq("_id", value: stockIn.id)
            .execute()

        let quantities = aggregate(stockIn.items)
        for (materialId, quantity) in quantities {
            guard let material = try await materialService.fetchMaterial(id: materialId) else { continue }
            let newStock = max(0, (material.quantity ?? 0) - quantity)
            try await materialService.updateQuantity(id: materialId, quantity: newStock)
        }

        try await recalculateImportCosts(materialIds: Set(quantities.keys))
    }

    private func aggregate(_ items: [StockInItem]) -> [String: Double] {
        var result: [String: Double] = [:]
        for item in items {
            guard let materialId = item.materialId, !materialId.isEmpty else { continue }
            result[materialId, default: 0] += item.quantity
        }
        return result
    }

    private func aggregate(_ items: [StockInInsertItem]) -> [String: Double] {
        var result: [String: Double] = [:]
        for item in items {
            guard let materialId = item.materialId, !materialId.isEmpty else { continue }
            result[materialId, default: 0] += item.quantity
        }
        return result
    }

    private func recalculateImportCosts(materialIds: Set<String>) async throws {
        guard !materialIds.isEmpty else { return }

        let records: [StockIn] = try await client
            .from("stock_in")
            .select()
            .eq("isDeleted", value: false)
            .execute()
            .value

        let sorted = records.sorted {
            ($0.receivedDate ?? $0.createdAt ?? "") > ($1.receivedDate ?? $1.createdAt ?? "")
        }

        for materialId in materialIds {
            guard let latest = sorted.first(where: { record in
                record.items.contains { $0.materialId == materialId }
            }),
            let item = latest.items.last(where: { $0.materialId == materialId }) else {
                continue
            }
            try await materialService.updateImportCost(id: materialId, importCost: item.unitPrice)
        }
    }
}
