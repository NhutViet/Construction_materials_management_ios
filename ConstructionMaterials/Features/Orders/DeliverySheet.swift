import SwiftUI

struct DeliverySheet: View {
    let invoice: Invoice
    let profile: Profile
    let onDelivered: (Invoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quantities: [Int: String] = [:]
    @State private var deliveredAt = Date()
    @State private var notes = ""
    @State private var isSaving = false
    @State private var error: String?

    private let service = InvoiceService()

    private var remainingItems: [(index: Int, item: InvoiceItem)] {
        Array(invoice.items.enumerated())
            .filter { $0.element.remaining > 0 }
            .map { (index: $0.offset, item: $0.element) }
    }

    private var selectedQuantityCount: Int {
        quantities.values
            .map { parseQuantity($0) }
            .filter { $0 > 0 }
            .count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(invoice.invoiceNumber)
                                .font(.headline)
                            Spacer()
                            StatusChip(
                                text: InvoiceStatus.text(invoice.status),
                                color: InvoiceStatus.color(invoice.status)
                            )
                        }
                        Text(invoice.customerName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()

                    FormSection(title: "Số lượng giao") {
                        if remainingItems.isEmpty {
                            Text("Hóa đơn đã giao đủ.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(remainingItems, id: \.index) { entry in
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Text(entry.item.materialName)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text("Còn \(Formatters.number(entry.item.remaining)) \(entry.item.unitValue)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    HStack(spacing: 8) {
                                        Text("Giao")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        TextField("0", text: Binding(
                                            get: { quantities[entry.index] ?? "" },
                                            set: { quantities[entry.index] = $0 }
                                        ))
                                        .font(.subheadline.weight(.semibold))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 76)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 9)
                                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                        .disabled(isSaving)

                                        Text(entry.item.unitValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()
                                    }
                                }

                                if entry.index != remainingItems.last?.index {
                                    Divider()
                                }
                            }

                            Button {
                                fillAll()
                            } label: {
                                Label("Giao tất cả phần còn lại", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .foregroundStyle(AppTheme.primary)
                            .background(
                                AppTheme.primary.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                            .disabled(isSaving || remainingItems.isEmpty)
                        }
                    }

                    FormSection(title: "Thời điểm giao") {
                        DatePicker(
                            "Thời điểm giao",
                            selection: $deliveredAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .font(.subheadline)
                        .datePickerStyle(.compact)
                    }

                    FormSection(title: "Ghi chú") {
                        FormField(
                            title: "Ghi chú",
                            placeholder: "Ghi chú cho đợt giao (không bắt buộc)",
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
            .navigationTitle("Giao hàng")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FormActionBar(
                    saveTitle: "Xác nhận",
                    isSaving: isSaving,
                    canSave: selectedQuantityCount > 0,
                    onCancel: { dismiss() },
                    onSave: submit
                )
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                if quantities.isEmpty {
                    for entry in remainingItems {
                        quantities[entry.index] = ""
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func fillAll() {
        for entry in remainingItems {
            quantities[entry.index] = rawQuantity(entry.item.remaining)
        }
    }

    private func parseQuantity(_ raw: String) -> Double {
        var cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        if cleaned.contains(",") {
            cleaned = cleaned
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }
        return Double(cleaned) ?? 0
    }

    private func rawQuantity(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }

    private func submit() {
        error = nil
        var parsed: [Int: Double] = [:]
        for entry in remainingItems {
            let raw = quantities[entry.index] ?? ""
            let value = parseQuantity(raw)
            if value > 0 {
                parsed[entry.index] = value
            }
        }

        guard !parsed.isEmpty else {
            error = "Vui lòng nhập số lượng giao."
            return
        }

        isSaving = true
        Task {
            do {
                let updated = try await service.createDelivery(
                    invoice: invoice,
                    quantities: parsed,
                    deliveredAt: deliveredAt,
                    notes: notes,
                    profile: profile
                )
                onDelivered(updated)
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
