import Foundation
import Supabase

struct MaterialService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func fetchMaterials() async throws -> [Material] {
        let materials: [Material] = try await client
            .from("materials")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
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
