import SwiftUI

struct CreateInvoiceView: View {
    let onCreated: (Invoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore

    @State private var materials: [Material] = []
    @State private var selectedMaterialId = ""
    @State private var quantity: Double = 1
    @State private var drafts: [InvoiceDraftItem] = []

    @State private var customerName = ""
    @State private var customerPhone = ""
    @State private var customerAddress = ""
    @State private var taxRate: Double = 0
    @State private var discountRate: Double = 0
    @State private var paidAmount: Double = 0
    @State private var paymentMethod = "cash"
    @State private var notes = ""

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?

    private let materialService = MaterialService()
    private let invoiceService = InvoiceService()

    private var activeMaterials: [Material] {
        materials.filter(\.isAvailable)
    }

    private var selectedMaterial: Material? {
        activeMaterials.first { $0.id == selectedMaterialId }
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
                    FormSection(title: "Khách hàng") {
                        FormField(
                            title: "Tên khách hàng *",
                            placeholder: "Nguyễn Văn A",
                            icon: "person.fill",
                            text: $customerName
                        )
                        FormField(
                            title: "Số điện thoại",
                            placeholder: "09xx xxx xxx",
                            icon: "phone.fill",
                            text: $customerPhone,
                            keyboard: .phonePad
                        )
                        FormField(
                            title: "Địa chỉ",
                            placeholder: "Địa chỉ giao hàng",
                            icon: "mappin.and.ellipse",
                            text: $customerAddress,
                            axis: .vertical,
                            lineLimit: 1...3
                        )
                    }

                    FormSection(title: "Thêm mặt hàng") {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        } else if activeMaterials.isEmpty {
                            Text("Chưa có vật tư đang hoạt động.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            FormPickerRow(title: "Vật tư") {
                                Picker("", selection: $selectedMaterialId) {
                                    ForEach(activeMaterials) { material in
                                        Text("\(material.name) · \(Formatters.money(material.priceValue))")
                                            .tag(material.id)
                                    }
                                }
                                .labelsHidden()
                                .tint(AppTheme.primary)
                            }

                            if let material = selectedMaterial {
                                HStack {
                                    Text("Giá bán")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Formatters.money(material.priceValue)) / \(material.unitValue)")
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

                            Button {
                                addDraft()
                            } label: {
                                Label("Thêm vào hóa đơn", systemImage: "plus.circle.fill")
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

                    FormSection(title: "Mặt hàng trong hóa đơn (\(drafts.count))") {
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
                                            .frame(width: 64)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 7)
                                            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        Text(draft.material.unitValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        Text(Formatters.money(draft.unitPrice))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

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

                        FormPickerRow(title: "Phương thức") {
                            Picker("", selection: $paymentMethod) {
                                Text("Tiền mặt").tag("cash")
                                Text("Chuyển khoản").tag("online")
                                Text("Công nợ").tag("debt")
                            }
                            .labelsHidden()
                            .tint(AppTheme.primary)
                        }

                        FormNumberRow(title: "Đã thanh toán", value: $paidAmount, suffix: "đ", width: 108)
                    }

                    FormSection(title: "Tổng cộng") {
                        FormTotalRow(title: "Tạm tính", value: Formatters.money(subtotal))
                        FormTotalRow(title: "Giảm giá", value: "-\(Formatters.money(discountAmount))", color: AppTheme.warning)
                        FormTotalRow(title: "Thuế", value: Formatters.money(taxAmount))
                        Divider()
                        FormTotalRow(title: "Tổng cộng", value: Formatters.money(total), isTotal: true, color: AppTheme.primary)
                        FormTotalRow(title: "Còn lại", value: Formatters.money(max(0, total - paidAmount)), color: AppTheme.danger)
                    }

                    FormSection(title: "Ghi chú") {
                        FormField(
                            title: "Ghi chú",
                            placeholder: "Ghi chú cho hóa đơn (không bắt buộc)",
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
            .navigationTitle("Tạo hóa đơn")
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
    }

    private func addDraft() {
        guard let material = selectedMaterial, quantity > 0 else { return }
        if let index = drafts.firstIndex(where: { $0.material.id == material.id }) {
            drafts[index].quantity = roundMoney(drafts[index].quantity + quantity)
        } else {
            drafts.append(
                InvoiceDraftItem(
                    material: material,
                    quantity: quantity
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
        error = nil
        isSaving = true
        Task {
            do {
                let invoice = try await invoiceService.createInvoice(
                    customerName: customerName,
                    customerPhone: customerPhone,
                    customerAddress: customerAddress,
                    drafts: drafts,
                    taxRate: taxRate,
                    discountRate: discountRate,
                    paidAmount: max(0, min(paidAmount, total)),
                    paymentMethod: paymentMethod,
                    notes: notes,
                    profile: profile
                )
                onCreated(invoice)
                NotificationCenter.default.post(name: .invoicesDidChange, object: nil)
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
            if selectedMaterialId.isEmpty, let first = activeMaterials.first {
                selectedMaterialId = first.id
            }
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isLoading = false
    }
}
