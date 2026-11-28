import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var invoices: [Invoice] = []
    @State private var materials: [Material] = []
    @State private var isLoading = true
    @State private var error: String?

    private let invoiceService = InvoiceService()
    private let materialService = MaterialService()

    private var activeInvoices: [Invoice] {
        invoices.filter { !$0.isCancelled }
    }

    private var totalRevenue: Double {
        activeInvoices.reduce(0) { $0 + $1.totalValue }
    }

    private var totalDebt: Double {
        activeInvoices.reduce(0) { $0 + $1.remainingValue }
    }

    private var lowStockCount: Int {
        materials.filter { $0.isAvailable && $0.isLowStock }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                greeting

                if isLoading && invoices.isEmpty {
                    LoadingStateView()
                } else {
                    if let error {
                        ErrorBanner(message: error)
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        SummaryCard(
                            title: "Tổng doanh thu",
                            value: Formatters.money(totalRevenue),
                            subtitle: "\(activeInvoices.count) hóa đơn",
                            icon: "chart.line.uptrend.xyaxis",
                            color: AppTheme.primary
                        )
                        SummaryCard(
                            title: "Tổng nợ",
                            value: Formatters.money(totalDebt),
                            subtitle: "Cần thu",
                            icon: "exclamationmark.circle",
                            color: AppTheme.danger
                        )
                        SummaryCard(
                            title: "Đơn hàng",
                            value: "\(invoices.count)",
                            subtitle: "Tất cả hóa đơn",
                            icon: "doc.text",
                            color: AppTheme.info
                        )
                        SummaryCard(
                            title: "Tồn kho thấp",
                            value: "\(lowStockCount)",
                            subtitle: "Vật liệu cần nhập",
                            icon: "shippingbox",
                            color: lowStockCount > 0 ? AppTheme.warning : AppTheme.success
                        )
                    }
                }

                SectionHeader(title: "Đơn hàng gần đây")

                if activeInvoices.isEmpty && !isLoading {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "Chưa có đơn hàng",
                        message: "Các hóa đơn mới sẽ xuất hiện tại đây."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(activeInvoices.prefix(5)) { invoice in
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
            .padding(AppTheme.screenPadding)
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Tổng quan")
        .refreshable { await load() }
        .task { if invoices.isEmpty { await load() } }
        .onReceive(NotificationCenter.default.publisher(for: .invoicesDidChange)) { _ in
            Task { await load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .materialsDidChange)) { _ in
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

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Xin chào,")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(auth.profile?.displayName ?? "Quản lý")
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 16)
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        do {
            async let fetchedInvoices = invoiceService.fetchInvoices()
            async let fetchedMaterials = materialService.fetchMaterials()
            invoices = try await fetchedInvoices
            materials = try await fetchedMaterials
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isLoading = false
    }
}
