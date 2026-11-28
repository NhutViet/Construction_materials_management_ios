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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FormSection(title: "Hóa đơn") {
                        FormTotalRow(title: "Số hóa đơn", value: invoice.invoiceNumber)
                        FormTotalRow(title: "Tổng tiền", value: Formatters.money(invoice.totalValue))
                        FormTotalRow(title: "Đã thanh toán", value: Formatters.money(invoice.paidValue), color: AppTheme.success)
                        Divider()
                        FormTotalRow(title: "Còn lại", value: Formatters.money(invoice.remainingValue), isTotal: true, color: AppTheme.danger)
                    }

                    FormSection(title: "Thanh toán") {
                        FormNumberRow(title: "Số tiền", value: $amount, suffix: "đ", width: 120)

                        FormPickerRow(title: "Phương thức") {
                            Picker("", selection: $method) {
                                Text("Tiền mặt").tag("cash")
                                Text("Chuyển khoản").tag("online")
                                Text("Công nợ").tag("debt")
                            }
                            .labelsHidden()
                            .tint(AppTheme.primary)
                        }

                        FormField(
                            title: "Ghi chú",
                            placeholder: "Ghi chú thanh toán (không bắt buộc)",
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
            .navigationTitle("Thanh toán")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FormActionBar(
                    saveTitle: "Xác nhận",
                    isSaving: isSaving,
                    canSave: amount > 0,
                    onCancel: { dismiss() },
                    onSave: save
                )
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.large])
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
                if !error.isCancellation {
                    self.error = error.userFacingMessage
                }
            }
            isSaving = false
        }
    }
}
