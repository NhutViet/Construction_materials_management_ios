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

                    FormSection(title: "Thêm mặt hàng") {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        } else if materials.isEmpty {
                            Text("Chưa có vật tư. Hãy thêm vật tư trước.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            FormPickerRow(title: "Vật tư") {
                                Picker("", selection: $selectedMaterialId) {
                                    Text("Chọn vật tư").tag("")
                                    ForEach(materials) { material in
                                        Text("\(material.name) · tồn \(Formatters.number(material.quantityValue))")
                                            .tag(material.id)
                                    }
                                }
                                .labelsHidden()
                                .tint(AppTheme.primary)
                                .onChange(of: selectedMaterialId) { _, newValue in
                                    if let material = materials.first(where: { $0.id == newValue }) {
                                        unitPrice = material.importCost ?? material.priceValue
                                    }
                                }
                            }

                            if let material = selectedMaterial {
                                HStack {
                                    Text("Tồn hiện tại")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Formatters.number(material.quantityValue)) \(material.unitValue)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                            }

                            FormNumberRow(
                                title: "Số lượng",
                                value: $quantity,
                                suffix: selectedMaterial?.unitValue,
                                width: 88
                            )
                            FormNumberRow(
                                title: "Giá nhập",
                                value: $unitPrice,
                                suffix: "/\(selectedMaterial?.unitValue ?? "đv")",
                                width: 100
                            )

                            Button {
                                addDraft()
                            } label: {
                                Label("Thêm vào phiếu nhập", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                            }
                            .foregroundStyle(.white)
                            .background(
                                selectedMaterial != nil && quantity > 0
                                    ? AppTheme.primary
                                    : Color.gray.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                            .disabled(selectedMaterial == nil || quantity <= 0)
                        }
                    }

                    FormSection(title: "Mặt hàng nhập (\(drafts.count))") {
                        if drafts.isEmpty {
                            Text("Chưa có mặt hàng nào.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach($drafts) { $draft in
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Text(draft.material.name)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(Formatters.money(draft.total))
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(AppTheme.success)
                                    }

                                    HStack(spacing: 8) {
                                        Text("SL")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        TextField("0", value: $draft.quantity, format: .number)
                                            .font(.subheadline.weight(.medium))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 60)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 7)
                                            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        Text(draft.material.unitValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        TextField("Giá", value: $draft.unitPrice, format: .number)
                                            .font(.caption.weight(.medium))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 82)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 7)
                                            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        Button {
                                            drafts.removeAll { $0.id == draft.id }
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

                                if draft.id != drafts.last?.id {
                                    Divider()
                                }
                            }
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
            .navigationTitle("Phiếu nhập hàng")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FormActionBar(
                    isSaving: isSaving,
                    canSave: !drafts.isEmpty,
                    onCancel: { dismiss() },
                    onSave: save
                )
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
                if !error.isCancellation {
                    self.error = error.userFacingMessage
                }
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
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isLoading = false
    }
}
