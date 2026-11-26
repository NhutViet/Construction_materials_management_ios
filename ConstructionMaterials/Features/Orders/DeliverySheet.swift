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
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.invoiceNumber)
                            .font(.headline)
                        Text(invoice.customerName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Số lượng giao") {
                    if remainingItems.isEmpty {
                        Text("Hóa đơn đã giao đủ.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(remainingItems, id: \.index) { entry in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.item.materialName)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Còn \(Formatters.number(entry.item.remaining)) \(entry.item.unitValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                TextField("0", text: Binding(
                                    get: { quantities[entry.index] ?? "" },
                                    set: { quantities[entry.index] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 88)
                                .disabled(isSaving)
                                Text(entry.item.unitValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }

                        Button {
                            fillAll()
                        } label: {
                            Label("Giao tất cả phần còn lại", systemImage: "checkmark.circle")
                        }
                        .disabled(isSaving || remainingItems.isEmpty)
                    }
                }

                Section {
                    DatePicker(
                        "Thời điểm giao",
                        selection: $deliveredAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField("Ghi chú (không bắt buộc)", text: $notes, axis: .vertical)
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
            .navigationTitle("Giao hàng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Xác nhận")
                        }
                    }
                    .disabled(isSaving || selectedQuantityCount == 0)
                }
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
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSaving = false
        }
    }
}
