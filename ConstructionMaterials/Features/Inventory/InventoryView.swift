import SwiftUI

struct InventoryView: View {
    @State private var materials: [Material] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var error: String?

    private let service = MaterialService()

    private var filteredMaterials: [Material] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return materials }
        return materials.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.category ?? "").localizedCaseInsensitiveContains(query)
                || ($0.supplier ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let error {
                    ErrorBanner(message: error)
                }

                if isLoading && materials.isEmpty {
                    LoadingStateView(message: "Đang tải hàng hoá...")
                } else if filteredMaterials.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "Không có vật liệu",
                        message: "Thử đổi từ khóa tìm kiếm."
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredMaterials) { material in
                            MaterialRow(material: material)
                        }
                    }
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Hàng hoá")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Tìm vật liệu, danh mục, nhà cung cấp"
        )
        .refreshable { await load() }
        .task { if materials.isEmpty { await load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        do {
            materials = try await service.fetchMaterials()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

private struct MaterialRow: View {
    let material: Material

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(material.name)
                        .font(.subheadline.weight(.semibold))
                    Text(material.category ?? "Chưa phân loại")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if material.isLowStock {
                    StatusChip(text: "Tồn kho thấp", color: AppTheme.warning)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Giá bán")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Formatters.money(material.priceValue))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tồn kho")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Formatters.number(material.quantityValue)) \(material.unitValue)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(material.isLowStock ? AppTheme.warning : AppTheme.success)
                }
            }

            if let supplier = material.supplier, !supplier.isEmpty {
                Text("NCC: \(supplier)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .appCard(padding: 14)
    }
}
