import SwiftUI

struct StockInFormView: View {
    let onCreated: (StockIn) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore

    @State private var materials: [Material] = []
    @State private var drafts: [StockInDraftItem] = []
    @State private var selectedMaterialId = ""
    @State private var quantity: Double = 1
    @State private var unitPrice: Double = 0

    @State private var supplier = ""
    @State private var supplierPhone = ""
    @State private var supplierAddress = ""
    @State private var taxRate: Double = 0
    @State private var discountRate: Double = 0
    @State private var paidAmount: Double = 0
    @State private var notes = ""

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?

    private let materialService = MaterialService()
    private let service = StockInService()

    private var selectedMaterial: Material? {
        materials.first { $0.id == selectedMaterialId }
    }

    private var subtotal: Double {
        roundMoney(drafts.reduce(0) { $0 + $1.total })
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Nhà cung cấp") {
                    TextField("Tên nhà cung cấp", text: $supplier)
                    TextField("Số điện thoại", text: $supplierPhone)
                        .keyboardType(.phonePad)
                    TextField("Địa chỉ", text: $supplierAddress, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Thêm mặt hàng") {
                    if isLoading {
                        ProgressView()
                    } else if materials.isEmpty {
                        Text("Chưa có vật tư. Hãy thêm vật tư trước.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Vật tư", selection: $selectedMaterialId) {
                            Text("Chọn vật tư").tag("")
                            ForEach(materials) { material in
                                Text("\(material.name) · tồn \(Formatters.number(material.quantityValue)) \(material.unitValue)")
                                    .tag(material.id)
                            }
                        }
                        .onChange(of: selectedMaterialId) { _, newValue in
                            if let material = materials.first(where: { $0.id == newValue }) {
                                unitPrice = material.importCost ?? material.priceValue
                            }
                        }

                        HStack {
                            Text("Số lượng")
                            Spacer()
                            TextField("0", value: $quantity, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Text(selectedMaterial?.unitValue ?? "")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Giá nhập")
                            Spacer()
                            TextField("0", value: $unitPrice, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                            Text("/\(selectedMaterial?.unitValue ?? "đv")")
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            addDraft()
                        } label: {
                            Label("Thêm vào phiếu nhập", systemImage: "plus.circle")
                        }
                        .disabled(selectedMaterial == nil || quantity <= 0)
                    }
                }

                Section("Mặt hàng nhập") {
                    if drafts.isEmpty {
                        Text("Chưa có mặt hàng.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($drafts) { $draft in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(draft.material.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(Formatters.money(draft.total))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(AppTheme.success)
                                }
                                HStack(spacing: 8) {
                                    TextField("SL", value: $draft.quantity, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 70)
                                    Text(draft.material.unitValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("Giá", value: $draft.unitPrice, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                    Spacer()
                                    Button(role: .destructive) {
                                        drafts.removeAll { $0.id == draft.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Thanh toán") {
                    HStack {
                        Text("Giảm giá (%)")
                        Spacer()
                        TextField("0", value: $discountRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    HStack {
                        Text("Thuế (%)")
                        Spacer()
                        TextField("0", value: $taxRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    HStack {
                        Text("Đã trả NCC")
                        Spacer()
                        TextField("0", value: $paidAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                Section("Tổng") {
                    LabeledContent("Tạm tính", value: Formatters.money(subtotal))
                    LabeledContent("Giảm giá", value: "-\(Formatters.money(discountAmount))")
                    LabeledContent("Thuế", value: Formatters.money(taxAmount))
                    LabeledContent("Tổng cộng", value: Formatters.money(total))
                    LabeledContent("Còn nợ", value: Formatters.money(max(0, total - paidAmount)))
                }

                Section("Ghi chú") {
                    TextField("Ghi chú", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }
                }
            }
            .navigationTitle("Phiếu nhập hàng")
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
                    .disabled(isSaving || drafts.isEmpty)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .task { await loadMaterials() }
        }
        .presentationDetents([.large])
    }

    private func addDraft() {
        guard let material = selectedMaterial, quantity > 0 else { return }
        if let index = drafts.firstIndex(where: { $0.material.id == material.id }) {
            drafts[index].quantity = roundMoney(drafts[index].quantity + quantity)
            drafts[index].unitPrice = unitPrice
        } else {
            drafts.append(
                StockInDraftItem(
                    material: material,
                    quantity: quantity,
                    unitPrice: unitPrice
                )
            )
        }
        quantity = 1
    }

    private func save() {
        guard let profile = auth.profile else {
            error = "Phiên đăng nhập không hợp lệ."
            return
        }
        guard drafts.allSatisfy({ $0.quantity > 0 }) else {
            error = "Số lượng mỗi mặt hàng phải lớn hơn 0."
            return
        }

        error = nil
        isSaving = true
        Task {
            do {
                let created = try await service.createStockIn(
                    supplier: supplier,
                    supplierPhone: supplierPhone,
                    supplierAddress: supplierAddress,
                    drafts: drafts,
                    taxRate: taxRate,
                    discountRate: discountRate,
                    paidAmount: max(0, min(paidAmount, total)),
                    notes: notes,
                    profile: profile
                )
                onCreated(created)
                dismiss()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSaving = false
        }
    }

    @MainActor
    private func loadMaterials() async {
        isLoading = true
        do {
            materials = try await materialService.fetchMaterials()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
