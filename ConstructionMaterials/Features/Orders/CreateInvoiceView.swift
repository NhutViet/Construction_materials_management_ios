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
                Section("Khách hàng") {
                    TextField("Tên khách hàng *", text: $customerName)
                    TextField("Số điện thoại", text: $customerPhone)
                        .keyboardType(.phonePad)
                    TextField("Địa chỉ", text: $customerAddress, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Thêm mặt hàng") {
                    if isLoading {
                        ProgressView()
                    } else if materials.isEmpty {
                        Text("Chưa có vật liệu.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Vật tư", selection: $selectedMaterialId) {
                            ForEach(materials) { material in
                                Text("\(material.name) · \(Formatters.money(material.priceValue))/\(material.unitValue)")
                                    .tag(material.id)
                            }
                        }
                        HStack {
                            Text("Số lượng")
                            Spacer()
                            TextField("0", value: $quantity, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 110)
                            Text(selectedMaterial?.unitValue ?? "")
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            addDraft()
                        } label: {
                            Label("Thêm vào hóa đơn", systemImage: "plus.circle")
                        }
                        .disabled(selectedMaterial == nil || quantity <= 0)
                    }
                }

                Section("Mặt hàng trong hóa đơn") {
                    if drafts.isEmpty {
                        Text("Chưa có mặt hàng.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(drafts.indices, id: \.self) { index in
                            let draft = drafts[index]
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(draft.material.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(Formatters.money(draft.total))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(AppTheme.success)
                                }
                                HStack {
                                    Text("SL")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("0", value: $drafts[index].quantity, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 90)
                                    Text(draft.material.unitValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(Formatters.money(draft.unitPrice))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Button(role: .destructive) {
                                        drafts.remove(at: index)
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
                    Picker("Phương thức", selection: $paymentMethod) {
                        Text("Tiền mặt").tag("cash")
                        Text("Chuyển khoản").tag("online")
                        Text("Công nợ").tag("debt")
                    }
                    HStack {
                        Text("Đã thanh toán")
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
                    LabeledContent("Còn lại", value: Formatters.money(max(0, total - paidAmount)))
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
            .navigationTitle("Tạo hóa đơn")
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
            if selectedMaterialId.isEmpty, let first = materials.first {
                selectedMaterialId = first.id
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
