import SwiftUI

struct CustomerDetailView: View {
    let customerKey: String

    @State private var invoices: [Invoice] = []
    @State private var isLoading = true
    @State private var error: String?

    private let service = InvoiceService()

    private var customerInvoices: [Invoice] {
        invoices
            .filter { !$0.isCancelled && CustomerSummary.key(for: $0) == customerKey }
            .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
    }

    private var summary: CustomerSummary? {
        CustomerSummary.from(invoices: customerInvoices).first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error {
                    ErrorBanner(message: error)
                }

                if isLoading && invoices.isEmpty {
                    LoadingStateView()
                } else if let summary {
                    header(summary)
                    SectionHeader(title: "Hóa đơn (\(customerInvoices.count))")
                    LazyVStack(spacing: 12) {
                        ForEach(customerInvoices) { invoice in
                            NavigationLink {
                                OrderDetailView(invoiceId: invoice.id)
                            } label: {
                                OrderRow(invoice: invoice)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "Không tìm thấy khách hàng",
                        message: "Dữ liệu khách hàng có thể đã thay đổi."
                    )
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(summary?.name ?? "Khách hàng")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { if invoices.isEmpty { await load() } }
    }

    private func header(_ summary: CustomerSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(summary.name)
                    .font(.headline)
                Spacer()
                StatusChip(
                    text: summary.remaining > 0 ? "Còn nợ" : "Đã thanh toán",
                    color: summary.remaining > 0 ? AppTheme.warning : AppTheme.success
                )
            }
            if !summary.phone.isEmpty {
                Label(summary.phone, systemImage: "phone.fill")
                    .font(.footnote)
            }
            if !summary.address.isEmpty {
                Label(summary.address, systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let lastOrderDate = summary.lastOrderDate {
                Label("Đơn gần nhất: \(Formatters.date(lastOrderDate))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 12) {
                metric("Tổng mua", Formatters.money(summary.totalSpent), AppTheme.primary)
                metric("Đã trả", Formatters.money(summary.totalPaid), AppTheme.success)
                metric("Còn nợ", Formatters.money(summary.remaining), AppTheme.danger)
            }
        }
        .appCard()
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        do {
            invoices = try await service.fetchInvoices()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
