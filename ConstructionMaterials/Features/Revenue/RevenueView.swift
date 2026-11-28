import SwiftUI
import Charts

struct RevenueView: View {
    @State private var invoices: [Invoice] = []
    @State private var isLoading = true
    @State private var error: String?

    private let service = InvoiceService()

    private var activeInvoices: [Invoice] {
        invoices.filter { !$0.isCancelled }
    }

    private var totalRevenue: Double {
        activeInvoices.reduce(0) { $0 + $1.totalValue }
    }

    private var totalPaid: Double {
        activeInvoices.reduce(0) { $0 + $1.paidValue }
    }

    private var totalDebt: Double {
        activeInvoices.reduce(0) { $0 + $1.remainingValue }
    }

    private var deliveredValue: Double {
        activeInvoices.reduce(0) { sum, invoice in
            sum + invoice.items.reduce(0) { $0 + ($1.deliveredAmount ?? 0) }
        }
    }

    private var averageOrder: Double {
        activeInvoices.isEmpty ? 0 : roundMoney(totalRevenue / Double(activeInvoices.count))
    }

    private var monthlyRevenue: [MonthRevenue] {
        let calendar = Calendar.current
        let now = Date()
        var points: [MonthRevenue] = []

        for offset in stride(from: 5, through: 0, by: -1) {
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: now),
                  let interval = calendar.dateInterval(of: .month, for: monthDate) else {
                continue
            }
            let revenue = activeInvoices.reduce(0.0) { sum, invoice in
                guard let created = Formatters.parseDate(invoice.createdAt),
                      created >= interval.start, created < interval.end else {
                    return sum
                }
                return sum + invoice.totalValue
            }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "MM/yy"
            points.append(
                MonthRevenue(
                    label: formatter.string(from: monthDate),
                    revenue: roundMoney(revenue)
                )
            )
        }
        return points
    }

    private var topMaterials: [MaterialRevenue] {
        var totals: [String: (quantity: Double, revenue: Double)] = [:]
        for invoice in activeInvoices {
            for item in invoice.items {
                var entry = totals[item.materialName] ?? (0, 0)
                entry.quantity += item.quantity
                entry.revenue += item.totalPrice
                totals[item.materialName] = entry
            }
        }
        return totals
            .map { MaterialRevenue(name: $0.key, quantity: $0.value.quantity, revenue: roundMoney($0.value.revenue)) }
            .sorted { $0.revenue > $1.revenue }
            .prefix(6)
            .map { $0 }
    }

    private var maxMaterialRevenue: Double {
        topMaterials.map(\.revenue).max() ?? 0
    }

    private var paymentBreakdown: [(title: String, count: Int, color: Color)] {
        [
            ("Đã thanh toán", activeInvoices.filter { $0.paymentStatus == "paid" }.count, AppTheme.success),
            ("Một phần", activeInvoices.filter { $0.paymentStatus == "partial" }.count, AppTheme.warning),
            ("Chưa thanh toán", activeInvoices.filter { $0.paymentStatus == "unpaid" || $0.paymentStatus == nil }.count, AppTheme.danger),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let error {
                    ErrorBanner(message: error)
                }

                if isLoading && invoices.isEmpty {
                    LoadingStateView(message: "Đang tính toán báo cáo...")
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        SummaryCard(
                            title: "Doanh thu",
                            value: Formatters.money(totalRevenue),
                            subtitle: "\(activeInvoices.count) hóa đơn",
                            icon: "chart.line.uptrend.xyaxis",
                            color: AppTheme.primary
                        )
                        SummaryCard(
                            title: "Đã thu",
                            value: Formatters.money(totalPaid),
                            subtitle: totalRevenue > 0 ? "\(Int((totalPaid / totalRevenue) * 100))%" : "0%",
                            icon: "checkmark.circle.fill",
                            color: AppTheme.success
                        )
                        SummaryCard(
                            title: "Công nợ",
                            value: Formatters.money(totalDebt),
                            subtitle: "Cần thu",
                            icon: "exclamationmark.circle",
                            color: totalDebt > 0 ? AppTheme.danger : AppTheme.success
                        )
                        SummaryCard(
                            title: "Giá trị đã giao",
                            value: Formatters.money(deliveredValue),
                            subtitle: "Trung bình \(Formatters.money(averageOrder))/đơn",
                            icon: "shippingbox.fill",
                            color: AppTheme.info
                        )
                    }

                    chartCard
                    topMaterialsCard
                    paymentCard
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Báo cáo doanh thu")
        .navigationBarTitleDisplayMode(.inline)
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

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Doanh thu 6 tháng gần đây")

            Chart(monthlyRevenue) { point in
                BarMark(
                    x: .value("Tháng", point.label),
                    y: .value("Doanh thu", point.revenue)
                )
                .foregroundStyle(AppTheme.primary.gradient)
                .cornerRadius(6)
            }
            .frame(height: 190)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(shortMoney(amount))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .appCard()
    }

    private var topMaterialsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Top vật tư theo doanh thu")

            if topMaterials.isEmpty {
                Text("Chưa có dữ liệu.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topMaterials) { material in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(material.name)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text(Formatters.money(material.revenue))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                        }
                        GeometryReader { geometry in
                            let ratio = maxMaterialRevenue > 0 ? material.revenue / maxMaterialRevenue : 0
                            Capsule()
                                .fill(AppTheme.primary.opacity(0.15))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(AppTheme.primary)
                                        .frame(width: max(6, geometry.size.width * ratio))
                                }
                        }
                        .frame(height: 8)
                        Text("\(Formatters.number(material.quantity)) đơn vị")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .appCard()
    }

    private var paymentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tình trạng thanh toán")

            ForEach(paymentBreakdown, id: \.title) { entry in
                HStack {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 9, height: 9)
                    Text(entry.title)
                        .font(.footnote)
                    Spacer()
                    Text("\(entry.count) hóa đơn")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(entry.color)
                }
            }
        }
        .appCard()
    }

    private func shortMoney(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.1ftỷ", value / 1_000_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.0ftr", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0fk", value / 1_000)
        }
        return "\(Int(value))"
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

private struct MonthRevenue: Identifiable {
    let id = UUID()
    let label: String
    let revenue: Double
}

private struct MaterialRevenue: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Double
    let revenue: Double
}
