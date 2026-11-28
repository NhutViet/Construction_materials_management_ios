import SwiftUI

struct StockInEditView: View {
    let stockIn: StockIn
    let onSaved: (StockIn) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var supplier: String
    @State private var supplierPhone: String
    @State private var supplierAddress: String
    @State private var taxRate: Double
    @State private var discountRate: Double
    @State private var paidAmount: Double
    @State private var notes: String
    @State private var items: [StockInEditLine]

    @State private var materials: [Material] = []
    @State private var selectedMaterialId = ""
    @State private var isLoadingMaterials = true
    @State private var isSaving = false
    @State private var error: String?

    private let service = StockInService()
    private let materialService = MaterialService()

    init(stockIn: StockIn, onSaved: @escaping (StockIn) -> Void) {
        self.stockIn = stockIn
        self.onSaved = onSaved
        _supplier = State(initialValue: stockIn.supplier ?? "")
        _supplierPhone = State(initialValue: stockIn.supplierPhone ?? "")
        _supplierAddress = State(initialValue: stockIn.supplierAddress ?? "")
        _taxRate = State(initialValue: stockIn.taxRate ?? 0)
        _discountRate = State(initialValue: stockIn.discountRate ?? 0)
        _paidAmount = State(initialValue: stockIn.paidValue)
        _notes = State(initialValue: stockIn.notes ?? "")
        _items = State(initialValue: stockIn.items.map { item in
            StockInEditLine(
                materialId: item.materialId,
                materialName: item.materialName,
                unit: item.unit ?? "",
                quantity: item.quantity,
                unitPrice: item.unitPrice
            )
        })
    }

    private var subtotal: Double {
        roundMoney(items.reduce(0) { $0 + $1.total })
    }

    private var taxAmount: Double {
        roundMoney(subtotal * taxRate / 100)
    }

    private var discountAmount: Double {
        roundMoney(subtotal * discountRate / 100)
    }

    private var total: Double {
        roundMoney(subtotal + taxAmount - discountAmount)
    }

    private var availableMaterials: [Material] {
        materials.filter { material in
            material.isAvailable && !items.contains { $0.materialId == material.id }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FormSection(title: "Nhà cung cấp") {
                        FormField(
                            title: "Tên nhà cung cấp",
                            placeholder: "Tên nhà cung cấp",
                            icon: "building.2.fill",
                            text: $supplier
                        )
                        FormField(
                            title: "Số điện thoại",
                            placeholder: "09xx xxx xxx",
                            icon: "phone.fill",
                            text: $supplierPhone,
                            keyboard: .phonePad
                        )
                        FormField(
                            title: "Địa chỉ",
                            placeholder: "Địa chỉ nhà cung cấp",
                            icon: "mappin.and.ellipse",
                            text: $supplierAddress,
                            axis: .vertical,
                            lineLimit: 1...3
                        )
                    }

                    FormSection(title: "Mặt hàng (\(items.count))") {
                        ForEach($items) { $item in
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    Text(item.materialName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(Formatters.money(item.total))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(AppTheme.success)
                                }

                                HStack(spacing: 8) {
                                    Text("SL")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    TextField("0", value: $item.quantity, format: .number)
                                        .font(.subheadline.weight(.medium))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    Text(item.unit)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    TextField("Giá", value: $item.unitPrice, format: .number)
                                        .font(.caption.weight(.medium))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 82)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    Button {
                                        items.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(AppTheme.danger)
                                            .frame(width: 32, height: 32)
                                            .background(AppTheme.danger.opacity(0.10), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if item.id != items.last?.id {
                                Divider()
                            }
                        }

                        if isLoadingMaterials {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        } else if availableMaterials.isEmpty {
                            Text("Tất cả vật tư đã có trong phiếu.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            FormPickerRow(title: "Thêm vật tư") {
                                Picker("", selection: $selectedMaterialId) {
                                    Text("Chọn vật tư").tag("")
                                    ForEach(availableMaterials) { material in
                                        Text("\(material.name) · \(Formatters.money(material.importCost ?? 0))")
                                            .tag(material.id)
                                    }
                                }
                                .labelsHidden()
                                .tint(AppTheme.primary)
                            }

                            Button {
                                addMaterial()
                            } label: {
                                Label("Thêm vào phiếu", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .foregroundStyle(AppTheme.primary)
                            .background(
                                AppTheme.primary.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                            .disabled(selectedMaterialId.isEmpty)
                        }
                    }

                    FormSection(title: "Thanh toán") {
                        FormNumberRow(title: "Giảm giá", value: $discountRate, suffix: "%", width: 66)
                        FormNumberRow(title: "Thuế", value: $taxRate, suffix: "%", width: 66)
                        FormNumberRow(title: "Đã trả NCC", value: $paidAmount, suffix: "đ", width: 108)
                    }

                    FormSection(title: "Tổng cộng") {
                        FormTotalRow(title: "Tạm tính", value: Formatters.money(subtotal))
                        FormTotalRow(title: "Giảm giá", value: "-\(Formatters.money(discountAmount))", color: AppTheme.warning)
                        FormTotalRow(title: "Thuế", value: Formatters.money(taxAmount))
                        Divider()
                        FormTotalRow(title: "Tổng cộng", value: Formatters.money(total), isTotal: true, color: AppTheme.primary)
                        FormTotalRow(title: "Còn nợ", value: Formatters.money(max(0, total - paidAmount)), color: AppTheme.danger)
                    }

                    FormSection(title: "Ghi chú") {
                        FormField(
                            title: "Ghi chú",
                            placeholder: "Ghi chú cho phiếu nhập (không bắt buộc)",
                            icon: "text.alignleft",
                            text: $notes,
                            axis: .vertical,
                            lineLimit: 2...4
                        )
                    }

                    if let error {
                        ErrorBanner(message: error)
                    }
                }
                .padding(AppTheme.screenPadding)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Sửa phiếu nhập")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FormActionBar(
                    isSaving: isSaving,
                    canSave: !items.isEmpty,
                    onCancel: { dismiss() },
                    onSave: save
                )
            }
            .interactiveDismissDisabled(isSaving)
            .task { await loadMaterials() }
        }
        .presentationDetents([.large])
    }

    private func addMaterial() {
        guard let material = materials.first(where: { $0.id == selectedMaterialId }) else { return }
        items.append(
            StockInEditLine(
                materialId: material.id,
                materialName: material.name,
                unit: material.unitValue,
                quantity: 1,
                unitPrice: material.importCost ?? material.priceValue
            )
        )
        selectedMaterialId = ""
    }

    private func save() {
        guard items.allSatisfy({ $0.quantity > 0 }) else {
            error = "Số lượng mỗi mặt hàng phải lớn hơn 0."
            return
        }

        error = nil
        isSaving = true
        Task {
            do {
                let updated = try await service.updateStockIn(
                    stockIn: stockIn,
                    supplier: supplier,
                    supplierPhone: supplierPhone,
                    supplierAddress: supplierAddress,
                    inputs: items.map(\.input),
                    taxRate: taxRate,
                    discountRate: discountRate,
                    paidAmount: min(paidAmount, total),
                    notes: notes
                )
                NotificationCenter.default.post(name: .materialsDidChange, object: nil)
                NotificationCenter.default.post(name: .stockInsDidChange, object: nil)
                onSaved(updated)
                dismiss()
            } catch {
                if !error.isCancellation {
                    self.error = error.userFacingMessage
                }
            }
            isSaving = false
        }
    }

    @MainActor
    private func loadMaterials() async {
        isLoadingMaterials = true
        do {
            materials = try await materialService.fetchMaterials()
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isLoadingMaterials = false
    }
}

private struct StockInEditLine: Identifiable {
    let id = UUID()
    var materialId: String?
    var materialName: String
    var unit: String
    var quantity: Double
    var unitPrice: Double

    var total: Double { roundMoney(quantity * unitPrice) }

    var input: StockInItemInput {
        StockInItemInput(
            materialId: materialId,
            materialName: materialName,
            unit: unit,
            quantity: quantity,
            unitPrice: unitPrice
        )
    }
}
