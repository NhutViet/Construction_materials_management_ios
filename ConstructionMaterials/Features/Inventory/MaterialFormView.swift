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

    init(material: Material?, onSaved: @escaping (Material) -> Void) {
        self.material = material
        self.onSaved = onSaved
        _name = State(initialValue: material?.name ?? "")
        _category = State(initialValue: material?.category ?? "")
        _unit = State(initialValue: material?.unit ?? "")
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
            Form {
                Section("Thông tin vật tư") {
                    TextField("Tên vật tư *", text: $name)
                    TextField("Danh mục", text: $category)
                    TextField("Đơn vị", text: $unit)
                    TextField("Nhà cung cấp", text: $supplier)
                    TextField("Vị trí kho", text: $location)
                    TextField("Mô tả", text: $materialDescription, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Giá & tồn kho") {
                    HStack {
                        Text("Giá nhập")
                        Spacer()
                        TextField("0", value: $importCost, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                    HStack {
                        Text("Giá bán")
                        Spacer()
                        TextField("0", value: $price, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                    HStack {
                        Text("Tồn kho")
                        Spacer()
                        TextField("0", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                    HStack {
                        Text("Tồn tối thiểu")
                        Spacer()
                        TextField("0", value: $minStock, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }

                Section {
                    Toggle("Đang hoạt động", isOn: $isActive)
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }
                }
            }
            .navigationTitle(material == nil ? "Thêm vật tư" : "Sửa vật tư")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Lưu")
                        }
                    }
                    .disabled(isSaving)
                }
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
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSaving = false
        }
    }
}
