import SwiftUI

struct OrderDetailView: View {
    let invoiceId: String

    @EnvironmentObject private var auth: AuthStore
    @State private var invoice: Invoice?
    @State private var records: [DeliveryRecord] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showDeliverySheet = false
    @State private var busyItemIndex: Int?

    private let service = InvoiceService()

    private var batches: [DeliveryBatch] {
        DeliveryBatch.group(records)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error {
                    ErrorBanner(message: error)
                }

                if let invoice {
                    customerCard(invoice)
                    totalsCard(invoice)
                    itemsSection(invoice)
                    historySection
                } else if isLoading {
                    LoadingStateView()
                } else {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "Không tìm thấy hóa đơn",
                        message: "Hóa đơn có thể đã bị xóa."
                    )
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(invoice?.invoiceNumber ?? "Chi tiết")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .toolbar {
            if let invoice, invoice.canDeliver {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDeliverySheet = true
                    } label: {
                        Label("Giao hàng", systemImage: "shippingbox.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showDeliverySheet) {
            if let invoice, let profile = auth.profile {
                DeliverySheet(invoice: invoice, profile: profile) { updated in
                    self.invoice = updated
                    Task { await loadRecords() }
                }
            }
        }
    }

    private func customerCard(_ invoice: Invoice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(invoice.customerName)
                    .font(.headline)
                Spacer()
                StatusChip(
                    text: InvoiceStatus.text(invoice.status),
                    color: InvoiceStatus.color(invoice.status)
                )
            }
            DetailInfoRow(label: "Số hóa đơn", value: invoice.invoiceNumber)
            DetailInfoRow(label: "Điện thoại", value: invoice.customerPhoneValue)
            DetailInfoRow(label: "Địa chỉ", value: invoice.customerAddressValue)
            DetailInfoRow(
                label: "Thanh toán",
                value: PaymentStatus.text(invoice.paymentStatus),
                valueColor: PaymentStatus.color(invoice.paymentStatus)
            )
        }
        .appCard()
    }

    private func totalsCard(_ invoice: Invoice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tổng quan")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                DetailMetric(title: "Tổng tiền", value: Formatters.money(invoice.totalValue), color: AppTheme.primary)
                DetailMetric(title: "Đã thanh toán", value: Formatters.money(invoice.paidValue), color: AppTheme.success)
                DetailMetric(title: "Còn lại", value: Formatters.money(invoice.remainingValue), color: AppTheme.danger)
                DetailMetric(title: "Đã giao", value: Formatters.money(invoice.items.reduce(0) { $0 + ($1.deliveredAmount ?? 0) }), color: AppTheme.info)
            }
        }
        .appCard()
    }

    private func itemsSection(_ invoice: Invoice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mặt hàng")

            ForEach(Array(invoice.items.enumerated()), id: \.offset) { index, item in
                OrderItemCard(
                    item: item,
                    isLocked: item.isLocked,
                    isBusy: busyItemIndex == index,
                    isDisabled: invoice.isCancelled
                ) { locked in
                    Task { await toggleLock(index: index, locked: locked) }
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Lịch sử giao hàng")

            if batches.isEmpty {
                Text("Chưa có lần giao hàng nào.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
            } else {
                ForEach(batches) { batch in
                    DeliveryBatchCard(batch: batch)
                }
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        do {
            async let invoiceTask = service.fetchInvoice(id: invoiceId)
            async let recordsTask = service.fetchDeliveryRecords(invoiceId: invoiceId)
            invoice = try await invoiceTask
            records = try await recordsTask
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func loadRecords() async {
        guard let invoice else { return }
        if let fetched = try? await service.fetchDeliveryRecords(invoiceId: invoice.id) {
            records = fetched
        }
    }

    @MainActor
    private func toggleLock(index: Int, locked: Bool) async {
        guard let invoice else { return }
        busyItemIndex = index
        error = nil
        do {
            self.invoice = try await service.updatePriceLock(
                invoice: invoice,
                itemIndex: index,
                locked: locked
            )
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        busyItemIndex = nil
    }
}

private struct DetailInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = AppTheme.muted

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.footnote.weight(.medium))
                .foregroundStyle(valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DetailMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct OrderItemCard: View {
    let item: InvoiceItem
    let isLocked: Bool
    let isBusy: Bool
    let isDisabled: Bool
    let onToggleLock: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.materialName)
                        .font(.subheadline.weight(.semibold))
                    Text("Đặt \(Formatters.number(item.quantity)) \(item.unitValue) · Đã giao \(Formatters.number(item.delivered))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusChip(
                    text: DeliveryStatus.text(item.computedDeliveryStatus),
                    color: DeliveryStatus.color(item.computedDeliveryStatus)
                )
            }

            ProgressView(value: item.progress)
                .tint(item.isFullyDelivered ? AppTheme.success : AppTheme.primary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đơn giá")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Formatters.money(item.unitPrice))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Thành tiền")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Formatters.money(item.totalPrice))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.success)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Còn lại")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Formatters.number(item.remaining)) \(item.unitValue)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.remaining == 0 ? AppTheme.success : AppTheme.warning)
                }
            }

            Toggle(isOn: Binding(
                get: { isLocked },
                set: { onToggleLock($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chốt giá")
                        .font(.caption.weight(.semibold))
                    Text(isLocked ? "Đang giữ giá gốc" : "Giá theo vật tư hiện tại")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.success)
            .disabled(isBusy || isDisabled)
        }
        .appCard(padding: 14)
        .opacity(isBusy ? 0.7 : 1)
    }
}

private struct DeliveryBatchCard: View {
    let batch: DeliveryBatch

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatters.dateTime(batch.deliveredAt))
                        .font(.caption.weight(.semibold))
                    if let name = batch.deliveredByName, !name.isEmpty {
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(Formatters.number(batch.totalQuantity)) đơn vị")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.primary)
            }

            ForEach(batch.items) { record in
                HStack {
                    Text(record.materialName)
                        .font(.caption)
                    Spacer()
                    Text("\(Formatters.number(record.quantity)) \(record.unit ?? "")")
                        .font(.caption.weight(.semibold))
                }
            }

            if let notes = batch.notes, !notes.isEmpty {
                Text("Ghi chú: \(notes)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .appCard(padding: 14)
    }
}
