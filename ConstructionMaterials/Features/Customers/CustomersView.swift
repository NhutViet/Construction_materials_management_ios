import SwiftUI

struct CustomersView: View {
    @State private var invoices: [Invoice] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var error: String?

    private let service = InvoiceService()

    private var customers: [CustomerSummary] {
        CustomerSummary.from(invoices: invoices)
    }

    private var filteredCustomers: [CustomerSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return customers }
        return customers.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.phone.localizedCaseInsensitiveContains(query)
                || $0.address.localizedCaseInsensitiveContains(query)
        }
    }

    private var totalDebt: Double {
        customers.reduce(0) { $0 + $1.remaining }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let error {
                    ErrorBanner(message: error)
                }

                if isLoading && invoices.isEmpty {
                    LoadingStateView(message: "Đang tải khách hàng...")
                } else if filteredCustomers.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "Chưa có khách hàng",
                        message: "Khách hàng sẽ xuất hiện sau khi có hóa đơn."
                    )
                } else {
                    if searchText.isEmpty {
                        HStack(spacing: 12) {
                            SummaryCard(
                                title: "Khách hàng",
                                value: "\(customers.count)",
                                subtitle: "Đang giao dịch",
                                icon: "person.2.fill",
                                color: AppTheme.primary
                            )
                            SummaryCard(
                                title: "Tổng công nợ",
                                value: Formatters.money(totalDebt),
                                subtitle: "Cần thu",
                                icon: "banknote.fill",
                                color: totalDebt > 0 ? AppTheme.danger : AppTheme.success
                            )
                        }
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(filteredCustomers) { customer in
                            NavigationLink {
                                CustomerDetailView(customerKey: customer.id)
                            } label: {
                                CustomerRow(customer: customer)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Khách hàng")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Tìm tên, SĐT, địa chỉ")
        .refreshable { await load() }
        .task { if invoices.isEmpty { await load() } }
        .onReceive(NotificationCenter.default.publisher(for: .invoicesDidChange)) { _ in
            Task { await load() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        do {
            invoices = try await service.fetchInvoices()
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isLoading = false
    }
}

private struct CustomerRow: View {
    let customer: CustomerSummary

    private var initials: String {
        let parts = customer.name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "KH" : String(letters).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(initials)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.primary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(customer.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(customer.phone.isEmpty ? "Chưa có SĐT" : customer.phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(Formatters.money(customer.totalSpent))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                    Text("\(customer.invoiceCount) hóa đơn")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if customer.remaining > 0 {
                HStack {
                    Text("Còn nợ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Formatters.money(customer.remaining))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.danger)
                }
            }
        }
        .appCard(padding: 14)
    }
}
