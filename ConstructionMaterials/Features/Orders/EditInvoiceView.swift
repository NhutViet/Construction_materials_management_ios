import SwiftUI

struct EditInvoiceView: View {
    let invoice: Invoice
    let onSaved: (Invoice) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var materials: [Material] = []
    @State private var items: [InvoiceEditableItem]
    @State private var selectedMaterialId = ""

    @State private var customerName: String
    @State private var customerPhone: String
    @State private var customerAddress: String
    @State private var taxRate: Double
    @State private var discountRate: Double
    @State private var paymentMethod: String
    @State private var notes: String
    @State private var hasDeliveryDate: Bool
    @State private var deliveryDate: Date

    @State private var isSaving = false
    @State private var error: String?

    private let service = InvoiceService()
    private let materialService = MaterialService()

    init(invoice: Invoice, onSaved: @escaping (Invoice) -> Void) {
        self.invoice = invoice
        self.onSaved = onSaved
        _items = State(initialValue: InvoiceEditableItem.from(invoice: invoice))
        _customerName = State(initialValue: invoice.customerName)
        _customerPhone = State(initialValue: invoice.customerPhone ?? "")
        _customerAddress = State(initialValue: invoice.customerAddress ?? "")
        _taxRate = State(initialValue: invoice.taxRate ?? 0)
        _discountRate = State(initialValue: invoice.discountRate ?? 0)
        _paymentMethod = State(initialValue: invoice.paymentMethod ?? "cash")
        _notes = State(initialValue: invoice.notes ?? "")
        let parsedDate = Formatters.parseDate(invoice.deliveryDate)
        _hasDeliveryDate = State(initialValue: parsedDate != nil)
        _deliveryDate = State(initialValue: parsedDate ?? Date())
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
            !items.contains { $0.materialId == material.id }
        }
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

                Section("Mặt hàng") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 8) {
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
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Text(item.unit ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(Formatters.money(item.unitPrice))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    items.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .disabled(!item.canRemove)
                            }

                            if item.delivered > 0 {
                                Text("Đã giao \(Formatters.number(item.delivered)) \(item.unit ?? "") · không thể giảm dưới mức này")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.warning)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if availableMaterials.isEmpty {
                        Text("Tất cả vật tư đã có trong hóa đơn.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Thêm vật tư", selection: $selectedMaterialId) {
                            Text("Chọn vật tư").tag("")
                            ForEach(availableMaterials) { material in
                                Text("\(material.name) · \(Formatters.money(material.priceValue))/\(material.unitValue)")
                                    .tag(material.id)
                            }
                        }
                        Button {
                            addMaterial()
                        } label: {
                            Label("Thêm vào hóa đơn", systemImage: "plus.circle")
                        }
                        .disabled(selectedMaterialId.isEmpty)
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
                }

                Section("Tổng") {
                    LabeledContent("Tạm tính", value: Formatters.money(subtotal))
                    LabeledContent("Giảm giá", value: "-\(Formatters.money(discountAmount))")
                    LabeledContent("Thuế", value: Formatters.money(taxAmount))
                    LabeledContent("Tổng cộng", value: Formatters.money(total))
                }

                Section {
                    Toggle("Hẹn ngày giao", isOn: $hasDeliveryDate)
                    if hasDeliveryDate {
                        DatePicker("Ngày giao", selection: $deliveryDate, displayedComponents: [.date])
                    }
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
            .navigationTitle("Sửa hóa đơn")
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
                    .disabled(isSaving || items.isEmpty)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .task { await loadMaterials() }
        }
        .presentationDetents([.large])
    }

    private func addMaterial() {
        guard let material = materials.first(where: { $0.id == selectedMaterialId }) else { return }
        items.append(InvoiceEditableItem.from(material: material))
        selectedMaterialId = ""
    }

    private func save() {
        let invalidItem = items.first { $0.quantity < $0.delivered - 0.0001 }
        if let invalidItem {
            error = "\"\(invalidItem.materialName)\" đã giao \(Formatters.number(invalidItem.delivered)), không thể giảm số lượng xuống \(Formatters.number(invalidItem.quantity))."
            return
        }
        guard items.allSatisfy({ $0.quantity > 0 }) else {
            error = "Số lượng mỗi mặt hàng phải lớn hơn 0."
            return
        }

        error = nil
        isSaving = true
        let deliveryDateValue = hasDeliveryDate
            ? Formatters.isoWithFractionalSeconds.string(from: deliveryDate)
            : nil

        Task {
            do {
                let updated = try await service.updateInvoice(
                    invoice: invoice,
                    customerName: customerName,
                    customerPhone: customerPhone,
                    customerAddress: customerAddress,
                    taxRate: taxRate,
                    discountRate: discountRate,
                    paymentMethod: paymentMethod,
                    notes: notes,
                    deliveryDate: deliveryDateValue,
                    inputs: items.map(\.input)
                )
                onSaved(updated)
                dismiss()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSaving = false
        }
    }

    @MainActor
    private func loadMaterials() async {
        do {
            materials = try await materialService.fetchMaterials()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
