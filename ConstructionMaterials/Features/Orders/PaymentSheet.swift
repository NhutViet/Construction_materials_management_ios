import SwiftUI

struct PaymentSheet: View {
    let invoice: Invoice
    let onPaid: (Invoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double
    @State private var method = "cash"
    @State private var notes = ""
    @State private var isSaving = false
    @State private var error: String?

    private let service = InvoiceService()

    init(invoice: Invoice, onPaid: @escaping (Invoice) -> Void) {
        self.invoice = invoice
        self.onPaid = onPaid
        _amount = State(initialValue: invoice.remainingValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Hóa đơn", value: invoice.invoiceNumber)
                    LabeledContent("Tổng tiền", value: Formatters.money(invoice.totalValue))
                    LabeledContent("Đã thanh toán", value: Formatters.money(invoice.paidValue))
                    LabeledContent("Còn lại", value: Formatters.money(invoice.remainingValue))
                }

                Section("Thanh toán") {
                    HStack {
                        Text("Số tiền")
                        Spacer()
                        TextField("0", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }

                    Picker("Phương thức", selection: $method) {
                        Text("Tiền mặt").tag("cash")
                        Text("Chuyển khoản").tag("online")
                        Text("Công nợ").tag("debt")
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
            .navigationTitle("Thanh toán")
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
                            Text("Xác nhận")
                        }
                    }
                    .disabled(isSaving || amount <= 0)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard amount > 0 else {
            error = "Số tiền phải lớn hơn 0."
            return
        }
        guard amount <= invoice.remainingValue + 0.01 else {
            error = "Số tiền không được vượt quá số còn lại."
            return
        }

        error = nil
        isSaving = true
        Task {
            do {
                let updated = try await service.addPayment(
                    invoice: invoice,
                    amount: amount,
                    method: method,
                    notes: notes
                )
                onPaid(updated)
                dismiss()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSaving = false
        }
    }
}
