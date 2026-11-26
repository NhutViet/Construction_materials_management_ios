import SwiftUI

struct OrderRow: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoice.invoiceNumber)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                    Text(invoice.customerName)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(invoice.customerPhoneValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusChip(
                    text: InvoiceStatus.text(invoice.status),
                    color: InvoiceStatus.color(invoice.status)
                )
            }

            HStack {
                Label(Formatters.money(invoice.totalValue), systemImage: "banknote")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("Còn \(Formatters.money(invoice.remainingValue))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.danger)
            }

            VStack(alignment: .leading, spacing: 5) {
                ProgressView(value: invoice.deliveryProgress)
                    .tint(invoice.deliveryProgress >= 1 ? AppTheme.success : AppTheme.primary)
                Text("Đã giao \(Formatters.number(invoice.deliveredQuantity))/\(Formatters.number(invoice.totalQuantity))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .appCard(padding: 14)
    }
}
