import SwiftUI

struct StockInListView: View {
    @State private var stockIns: [StockIn] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCreate = false

    private let service = StockInService()

    private var totalValue: Double {
        stockIns.reduce(0) { $0 + $1.totalValue }
    }

    private var unpaidValue: Double {
        stockIns.reduce(0) { $0 + $1.remainingValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !stockIns.isEmpty {
                    HStack(spacing: 12) {
                        SummaryCard(
                            title: "Tổng giá trị nhập",
                            value: Formatters.money(totalValue),
                            subtitle: "\(stockIns.count) phiếu nhập",
                            icon: "tray.and.arrow.down.fill",
                            color: AppTheme.primary
                        )
                        SummaryCard(
                            title: "Còn nợ NCC",
                            value: Formatters.money(unpaidValue),
                            subtitle: "Cần thanh toán",
                            icon: "exclamationmark.circle",
                            color: unpaidValue > 0 ? AppTheme.danger : AppTheme.success
                        )
                    }
                }

                if let error {
                    ErrorBanner(message: error)
                }

                if isLoading && stockIns.isEmpty {
                    LoadingStateView(message: "Đang tải phiếu nhập...")
                } else if stockIns.isEmpty {
                    EmptyStateView(
                        icon: "tray.and.arrow.down",
                        title: "Chưa có phiếu nhập",
                        message: "Nhấn + để tạo phiếu nhập hàng mới."
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(stockIns) { stockIn in
                            StockInCard(stockIn: stockIn)
                        }
                    }
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Nhập hàng")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { if stockIns.isEmpty { await load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .sheet(isPresented: $showCreate) {
            StockInFormView { created in
                stockIns.insert(created, at: 0)
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        do {
            stockIns = try await service.fetchStockIns()
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isLoading = false
    }
}

private struct StockInCard: View {
    let stockIn: StockIn

    private var paymentColor: Color {
        switch stockIn.paymentStatus {
        case "paid": return AppTheme.success
        case "partial": return AppTheme.warning
        default: return AppTheme.danger
        }
    }

    private var paymentText: String {
        switch stockIn.paymentStatus {
        case "paid": return "Đã thanh toán"
        case "partial": return "Thanh toán một phần"
        default: return "Chưa thanh toán"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stockIn.stockInNumber)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                    Text(stockIn.supplierValue)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(Formatters.dateTime(stockIn.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusChip(text: paymentText, color: paymentColor)
            }

            HStack {
                Label(Formatters.money(stockIn.totalValue), systemImage: "banknote")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(stockIn.itemCount) mặt hàng")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if stockIn.remainingValue > 0 {
                Text("Còn nợ \(Formatters.money(stockIn.remainingValue))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.danger)
            }
        }
        .appCard(padding: 14)
    }
}
