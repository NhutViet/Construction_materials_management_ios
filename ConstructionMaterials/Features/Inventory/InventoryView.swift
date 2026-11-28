import SwiftUI

struct InventoryView: View {
    @State private var materials: [Material] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCreate = false
    @State private var editingMaterial: Material?

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
                            Button {
                                editingMaterial = material
                            } label: {
                                MaterialRow(material: material)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Hàng hoá")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Tìm vật liệu, danh mục, nhà cung cấp"
        )
        .refreshable { await load() }
        .task {
            if materials.isEmpty { await load() }
            #if DEBUG
            let screen = ProcessInfo.processInfo.environment["IOS_TEST_SCREEN"]
            if screen == "materialForm" {
                showCreate = true
            } else if screen == "materialEdit", let first = materials.first {
                editingMaterial = first
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .invoicesDidChange)) { _ in
            Task { await load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .materialsDidChange)) { _ in
            Task { await load() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .sheet(isPresented: $showCreate) {
            MaterialFormView(material: nil) { saved in
                upsert(saved)
            }
        }
        .sheet(item: $editingMaterial) { material in
            MaterialFormView(material: material) { saved in
                upsert(saved)
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
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isLoading = false
    }

    @MainActor
    private func upsert(_ material: Material) {
        if let index = materials.firstIndex(where: { $0.id == material.id }) {
            materials[index] = material
        } else {
            materials.insert(material, at: 0)
        }
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
                if material.isInactive {
                    StatusChip(text: "Ngừng hoạt động", color: AppTheme.muted)
                } else if material.isLowStock {
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
