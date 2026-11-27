import Foundation
import Supabase

enum MaterialServiceError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

struct MaterialService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func fetchMaterials() async throws -> [Material] {
        let materials: [Material] = try await client
            .from("materials")
            .select()
            .order("name", ascending: true)
            .execute()
            .value

        // Bảng materials chỉ cho phép người đã đăng nhập đọc. Nếu phiên đăng nhập
        // không hợp lệ, Supabase trả về mảng rỗng thay vì lỗi, dễ bị hiểu nhầm là
        // "không có vật liệu". Kiểm tra lại phiên để báo đúng nguyên nhân.
        if materials.isEmpty, !(await AuthService().hasValidSession()) {
            throw MaterialServiceError.message("Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.")
        }
        return materials
    }

    func fetchMaterial(id: String?) async throws -> Material? {
        guard let id, !id.isEmpty else { return nil }
        let materials: [Material] = try await client
            .from("materials")
            .select()
            .eq("_id", value: id)
            .limit(1)
            .execute()
            .value
        return materials.first
    }

    func updateQuantity(id: String, quantity: Double) async throws {
        struct Payload: Encodable {
            let quantity: Double
            let updatedAt: String
        }
        let payload = Payload(quantity: max(0, roundMoney(quantity)), updatedAt: Formatters.nowIso())
        _ = try await client
            .from("materials")
            .update(payload)
            .eq("_id", value: id)
            .execute()
    }
}

private struct MaterialCreatePayload: Encodable {
    let name: String
    let category: String
    let unit: String
    let quantity: Double
    let price: Double
    let importCost: Double
    let supplier: String
    let description: String
    let minStock: Double
    let maxStock: Double
    let location: String
    let isActive: Bool
    let userId: String
    let createdAt: String
    let updatedAt: String
}

private struct MaterialUpdatePayload: Encodable {
    let name: String
    let category: String
    let unit: String
    let quantity: Double
    let price: Double
    let importCost: Double
    let supplier: String
    let description: String
    let minStock: Double
    let maxStock: Double
    let location: String
    let isActive: Bool
    let updatedAt: String
}

extension MaterialService {
    func createMaterial(
        name: String,
        category: String,
        unit: String,
        quantity: Double,
        price: Double,
        importCost: Double,
        supplier: String,
        description: String,
        minStock: Double,
        maxStock: Double,
        location: String,
        isActive: Bool,
        profile: Profile
    ) async throws -> Material {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw MaterialServiceError.message("Vui lòng nhập tên vật tư.")
        }
        let now = Formatters.nowIso()
        let payload = MaterialCreatePayload(
            name: trimmedName,
            category: category.isEmpty ? "Khác" : category,
            unit: unit,
            quantity: quantity,
            price: price,
            importCost: importCost,
            supplier: supplier,
            description: description,
            minStock: minStock,
            maxStock: maxStock,
            location: location,
            isActive: isActive,
            userId: profile.id,
            createdAt: now,
            updatedAt: now
        )
        let material: Material = try await client
            .from("materials")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return material
    }

    func updateMaterial(
        id: String,
        name: String,
        category: String,
        unit: String,
        quantity: Double,
        price: Double,
        importCost: Double,
        supplier: String,
        description: String,
        minStock: Double,
        maxStock: Double,
        location: String,
        isActive: Bool
    ) async throws -> Material {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw MaterialServiceError.message("Vui lòng nhập tên vật tư.")
        }
        let payload = MaterialUpdatePayload(
            name: trimmedName,
            category: category.isEmpty ? "Khác" : category,
            unit: unit,
            quantity: quantity,
            price: price,
            importCost: importCost,
            supplier: supplier,
            description: description,
            minStock: minStock,
            maxStock: maxStock,
            location: location,
            isActive: isActive,
            updatedAt: Formatters.nowIso()
        )
        let material: Material = try await client
            .from("materials")
            .update(payload)
            .eq("_id", value: id)
            .select()
            .single()
            .execute()
            .value
        return material
    }
}
