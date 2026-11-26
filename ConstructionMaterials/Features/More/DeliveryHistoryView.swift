import SwiftUI

struct DeliveryHistoryView: View {
    @State private var records: [DeliveryRecord] = []
    @State private var isLoading = true
    @State private var error: String?

    private let service = InvoiceService()

    private var batches: [DeliveryBatch] {
        DeliveryBatch.group(records)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let error {
                    ErrorBanner(message: error)
                }

                if isLoading && records.isEmpty {
                    LoadingStateView(message: "Đang tải lịch sử giao hàng...")
                } else if batches.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "Chưa có lịch sử",
                        message: "Các đợt giao hàng sẽ xuất hiện tại đây."
                    )
                } else {
                    ForEach(batches) { batch in
                        DeliveryLogCard(batch: batch)
                    }
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Lịch sử giao hàng")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { if records.isEmpty { await load() } }
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
            records = try await service.fetchAllDeliveryRecords()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

private struct DeliveryLogCard: View {
    let batch: DeliveryBatch

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(batch.invoiceNumber ?? "—")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                    Text(Formatters.dateTime(batch.deliveredAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            HStack {
                if let name = batch.deliveredByName, !name.isEmpty {
                    Text("Người giao: \(name)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let notes = batch.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .appCard(padding: 14)
    }
}
