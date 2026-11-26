import Foundation

struct CustomerSummary: Identifiable {
    let id: String
    let name: String
    let phone: String
    let address: String
    let invoiceCount: Int
    let totalSpent: Double
    let totalPaid: Double
    let remaining: Double
    let lastOrderDate: String?

    static func from(invoices: [Invoice]) -> [CustomerSummary] {
        let active = invoices.filter { !$0.isCancelled }
        let grouped = Dictionary(grouping: active) { key(for: $0) }

        return grouped.map { key, values in
            let latest = values.max { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
            return CustomerSummary(
                id: key,
                name: latest?.customerName ?? values.first?.customerName ?? "—",
                phone: latest?.customerPhone ?? "",
                address: latest?.customerAddress ?? "",
                invoiceCount: values.count,
                totalSpent: values.reduce(0) { $0 + $1.totalValue },
                totalPaid: values.reduce(0) { $0 + $1.paidValue },
                remaining: values.reduce(0) { $0 + $1.remainingValue },
                lastOrderDate: latest?.createdAt
            )
        }
        .sorted { $0.totalSpent > $1.totalSpent }
    }

    static func key(for invoice: Invoice) -> String {
        let phone = invoice.customerPhone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return phone.isEmpty ? invoice.customerName : phone
    }
}
