import SwiftUI

struct OrdersView: View {
    @State private var invoices: [Invoice] = []
    @State private var searchText = ""
    @State private var statusFilter: String?
    @State private var isLoading = true
    @State private var error: String?

    private let service = InvoiceService()

    private let filters: [(value: String?, title: String)] = [
        (nil, "Tất cả"),
        ("pending", "Chờ xử lý"),
        ("confirmed", "Đang giao"),
        ("delivered", "Đã giao"),
        ("cancelled", "Đã hủy"),
    ]

    private var filteredInvoices: [Invoice] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return invoices.filter { invoice in
            let matchesStatus = statusFilter == nil || invoice.status == statusFilter
            let matchesSearch = query.isEmpty
                || invoice.invoiceNumber.localizedCaseInsensitiveContains(query)
                || invoice.customerName.localizedCaseInsensitiveContains(query)
                || (invoice.customerPhone ?? "").localizedCaseInsensitiveContains(query)
            return matchesStatus && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                filterBar

                if isLoading && invoices.isEmpty {
                    LoadingStateView(message: "Đang tải hóa đơn...")
                } else {
                    if let error {
                        ErrorBanner(message: error)
                    }

                    if filteredInvoices.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.magnifyingglass",
                            title: "Không có hóa đơn",
                            message: "Thử đổi từ khóa tìm kiếm hoặc bộ lọc trạng thái."
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredInvoices) { invoice in
                                NavigationLink {
                                    OrderDetailView(invoiceId: invoice.id)
                                } label: {
                                    OrderRow(invoice: invoice)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Đơn hàng")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Tìm mã HĐ, khách hàng, SĐT"
        )
        .refreshable { await load() }
        .task { if invoices.isEmpty { await load() } }
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.title) { filter in
                    Button {
                        statusFilter = filter.value
                    } label: {
                        Text(filter.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(statusFilter == filter.value ? .white : AppTheme.primary)
                            .background(
                                statusFilter == filter.value
                                    ? AppTheme.primary
                                    : AppTheme.primary.opacity(0.10)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
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
