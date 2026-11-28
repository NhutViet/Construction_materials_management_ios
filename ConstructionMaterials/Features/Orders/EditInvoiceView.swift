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
                                        .frame(width: 64)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    Text(item.unit ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text(Formatters.money(item.unitPrice))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

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
                                    .disabled(!item.canRemove)
                                    .opacity(item.canRemove ? 1 : 0.35)
                                }

                                if item.delivered > 0 {
                                    Label(
                                        "Đã giao \(Formatters.number(item.delivered)) \(item.unit ?? "") · không thể giảm dưới mức này",
                                        systemImage: "info.circle"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.warning)
                                }
                            }

                            if item.id != items.last?.id {
                                Divider()
                            }
                        }

                        if availableMaterials.isEmpty {
                            Text("Tất cả vật tư đã có trong hóa đơn.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            FormPickerRow(title: "Thêm vật tư") {
                                Picker("", selection: $selectedMaterialId) {
                                    Text("Chọn vật tư").tag("")
                                    ForEach(availableMaterials) { material in
                                        Text("\(material.name) · \(Formatters.money(material.priceValue))")
                                            .tag(material.id)
                                    }
                                }
                                .labelsHidden()
                                .tint(AppTheme.primary)
                            }

                            Button {
                                addMaterial()
                            } label: {
                                Label("Thêm vào hóa đơn", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                            }
                            .foregroundStyle(.white)
                            .background(
                                selectedMaterialId.isEmpty
                                    ? Color.gray.opacity(0.4)
                                    : AppTheme.primary,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                            .disabled(selectedMaterialId.isEmpty)
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
                    }

                    FormSection(title: "Tổng cộng") {
                        FormTotalRow(title: "Tạm tính", value: Formatters.money(subtotal))
                        FormTotalRow(title: "Giảm giá", value: "-\(Formatters.money(discountAmount))", color: AppTheme.warning)
                        FormTotalRow(title: "Thuế", value: Formatters.money(taxAmount))
                        Divider()
                        FormTotalRow(title: "Tổng cộng", value: Formatters.money(total), isTotal: true, color: AppTheme.primary)
                    }

                    FormSection(title: "Giao hàng") {
                        Toggle("Hẹn ngày giao", isOn: $hasDeliveryDate)
                            .font(.subheadline)
                            .tint(AppTheme.primary)

                        if hasDeliveryDate {
                            DatePicker("Ngày giao", selection: $deliveryDate, displayedComponents: [.date])
                                .font(.subheadline)
                                .datePickerStyle(.compact)
                        }
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
            .navigationTitle("Sửa hóa đơn")
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
                if !error.isCancellation {
                    self.error = error.userFacingMessage
                }
            }
            isSaving = false
        }
    }

    @MainActor
    private func loadMaterials() async {
        do {
            materials = try await materialService.fetchMaterials()
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
    }
}
