import SwiftUI

struct MaterialFormView: View {
    let material: Material?
    let onSaved: (Material) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore

    @State private var name: String
    @State private var category: String
    @State private var unit: String
    @State private var price: Double
    @State private var importCost: Double
    @State private var quantity: Double
    @State private var minStock: Double
    @State private var supplier: String
    @State private var materialDescription: String
    @State private var location: String
    @State private var isActive: Bool

    @State private var isSaving = false
    @State private var error: String?

    private let service = MaterialService()
    private let invoiceService = InvoiceService()

    private static let categories = [
        "Vật liệu xây dựng",
        "Thiết bị điện",
        "Thiết bị nước",
        "Vật liệu trang trí",
        "Công cụ",
        "An toàn lao động",
        "Vật liệu nội thất",
        "Khác"
    ]

    private static let units = [
        "viên", "kg", "m", "m²", "m³", "lít", "thùng", "cuộn", "tấm", "bộ", "bao", "cái"
    ]

    private var categoryOptions: [String] {
        var options = Self.categories
        if !category.isEmpty, !options.contains(category) {
            options.insert(category, at: 0)
        }
        return options
    }

    private var unitOptions: [String] {
        var options = Self.units
        if !unit.isEmpty, !options.contains(unit) {
            options.insert(unit, at: 0)
        }
        return options
    }

    init(material: Material?, onSaved: @escaping (Material) -> Void) {
        self.material = material
        self.onSaved = onSaved
        let initialCategory = material?.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let initialUnit = material?.unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        _name = State(initialValue: material?.name ?? "")
        _category = State(initialValue: initialCategory.isEmpty ? Self.categories[0] : initialCategory)
        _unit = State(initialValue: initialUnit.isEmpty ? "cái" : initialUnit)
        _price = State(initialValue: material?.priceValue ?? 0)
        _importCost = State(initialValue: material?.importCost ?? 0)
        _quantity = State(initialValue: material?.quantityValue ?? 0)
        _minStock = State(initialValue: material?.minStockValue ?? 10)
        _supplier = State(initialValue: material?.supplier ?? "")
        _materialDescription = State(initialValue: material?.description ?? "")
        _location = State(initialValue: material?.location ?? "")
        _isActive = State(initialValue: material?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FormSection(title: "Thông tin vật tư") {
                        FormField(
                            title: "Tên vật tư *",
                            placeholder: "Ví dụ: Xi măng Hà Tiên",
                            icon: "shippingbox.fill",
                            text: $name
                        )
                        FormSelectField(
                            title: "Danh mục",
                            icon: "square.grid.2x2.fill",
                            selection: $category,
                            options: categoryOptions
                        )
                        FormSelectField(
                            title: "Đơn vị",
                            icon: "ruler.fill",
                            selection: $unit,
                            options: unitOptions
                        )
                        FormField(
                            title: "Nhà cung cấp",
                            placeholder: "Tên nhà cung cấp",
                            icon: "building.2.fill",
                            text: $supplier
                        )
                        FormField(
                            title: "Vị trí kho",
                            placeholder: "Khu A, kệ 2...",
                            icon: "mappin.and.ellipse",
                            text: $location
                        )
                        FormField(
                            title: "Mô tả",
                            placeholder: "Mô tả vật tư (không bắt buộc)",
                            icon: "text.alignleft",
                            text: $materialDescription,
                            axis: .vertical,
                            lineLimit: 2...4
                        )
                    }

                    FormSection(title: "Giá & tồn kho") {
                        FormNumberRow(title: "Giá nhập", value: $importCost, suffix: "đ", width: 120)
                        FormNumberRow(title: "Giá bán", value: $price, suffix: "đ", width: 120)
                        FormNumberRow(
                            title: "Tồn kho",
                            value: $quantity,
                            suffix: unit.isEmpty ? nil : unit,
                            width: 100
                        )
                        FormNumberRow(
                            title: "Tồn tối thiểu",
                            value: $minStock,
                            suffix: unit.isEmpty ? nil : unit,
                            width: 100
                        )
                    }

                    FormSection(title: "Trạng thái") {
                        Toggle("Đang hoạt động", isOn: $isActive)
                            .font(.subheadline)
                            .tint(AppTheme.primary)
                    }

                    if let error {
                        ErrorBanner(message: error)
                    }
                }
                .padding(AppTheme.screenPadding)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(material == nil ? "Thêm vật tư" : "Sửa vật tư")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FormActionBar(
                    isSaving: isSaving,
                    onCancel: { dismiss() },
                    onSave: save
                )
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.large])
    }

    private func save() {
        if material == nil, auth.profile == nil {
            error = "Phiên đăng nhập không hợp lệ."
            return
        }

        error = nil
        isSaving = true
        Task {
            do {
                if let material {
                    let priceChanged = abs(price - material.priceValue) > 0.001
                    let updated = try await service.updateMaterial(
                        id: material.id,
                        name: name,
                        category: category,
                        unit: unit,
                        quantity: quantity,
                        price: price,
                        importCost: importCost,
                        supplier: supplier,
                        description: materialDescription,
                        minStock: minStock,
                        maxStock: material.maxStock ?? 0,
                        location: location,
                        isActive: isActive
                    )
                    if priceChanged {
                        _ = try? await invoiceService.repriceRemainingItems(
                            materialId: updated.id,
                            newPrice: updated.priceValue
                        )
                    }
                    onSaved(updated)
                } else if let profile = auth.profile {
                    let created = try await service.createMaterial(
                        name: name,
                        category: category,
                        unit: unit,
                        quantity: quantity,
                        price: price,
                        importCost: importCost,
                        supplier: supplier,
                        description: materialDescription,
                        minStock: minStock,
                        maxStock: 0,
                        location: location,
                        isActive: isActive,
                        profile: profile
                    )
                    onSaved(created)
                }
                dismiss()
            } catch {
                if !error.isCancellation {
                    self.error = error.userFacingMessage
                }
            }
            isSaving = false
        }
    }
}
