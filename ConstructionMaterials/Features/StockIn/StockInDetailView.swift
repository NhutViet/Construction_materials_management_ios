import SwiftUI

struct StockInDetailView: View {
    let stockInId: String

    @Environment(\.dismiss) private var dismiss
    @State private var stockIn: StockIn?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    private let service = StockInService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error {
                    ErrorBanner(message: error)
                }

                if let stockIn {
                    headerCard(stockIn)
                    itemsCard(stockIn)
                    totalsCard(stockIn)
                    infoCard(stockIn)
                } else if isLoading {
                    LoadingStateView(message: "Đang tải phiếu nhập...")
                } else {
                    EmptyStateView(
                        icon: "tray.and.arrow.down",
                        title: "Không tìm thấy phiếu nhập",
                        message: "Phiếu nhập có thể đã bị xoá."
                    )
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(stockIn?.stockInNumber ?? "Phiếu nhập")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await load() }
        .task { await load() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let stockIn {
                actionBar(stockIn)
            }
        }
        .sheet(isPresented: $showEdit) {
            if let stockIn {
                StockInEditView(stockIn: stockIn) { updated in
                    self.stockIn = updated
                    NotificationCenter.default.post(name: .materialsDidChange, object: nil)
                    NotificationCenter.default.post(name: .stockInsDidChange, object: nil)
                }
            }
        }
        .confirmationDialog(
            "Xoá phiếu nhập này?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Xoá phiếu nhập", role: .destructive) {
                Task { await deleteStockIn() }
            }
            Button("Giữ lại", role: .cancel) {}
        } message: {
            Text("Tồn kho sẽ được trừ lại theo số lượng đã nhập trong phiếu này.")
        }
    }

    private func headerCard(_ stockIn: StockIn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stockIn.stockInNumber)
                    .font(.headline)
                Spacer()
                StatusChip(
                    text: PaymentStatus.text(stockIn.paymentStatus),
                    color: PaymentStatus.color(stockIn.paymentStatus)
                )
            }
            Text(stockIn.supplierValue)
                .font(.title3.weight(.bold))
            HStack(spacing: 12) {
                Label(Formatters.dateTime(stockIn.receivedDate ?? stockIn.createdAt), systemImage: "calendar")
                Spacer()
                Text("\(stockIn.itemCount) mặt hàng")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func itemsCard(_ stockIn: StockIn) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mặt hàng")
                .font(.headline)

            ForEach(Array(stockIn.items.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.materialName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(Formatters.money(item.totalPrice))
                            .font(.subheadline.weight(.bold))
                    }

                    HStack {
                        Text("\(Formatters.number(item.quantity)) \(item.unit ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Formatters.money(item.unitPrice)) / \(item.unit ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if index < stockIn.items.count - 1 {
                    Divider()
                }
            }
        }
        .appCard()
    }

    private func totalsCard(_ stockIn: StockIn) -> some View {
        VStack(spacing: 9) {
            FormTotalRow(title: "Tạm tính", value: Formatters.money(stockIn.subtotal))
            FormTotalRow(title: "Giảm giá", value: "-\(Formatters.money(stockIn.discountAmount))", color: AppTheme.warning)
            FormTotalRow(title: "Thuế", value: Formatters.money(stockIn.taxAmount))
            Divider()
            FormTotalRow(title: "Tổng cộng", value: Formatters.money(stockIn.totalAmount), isTotal: true, color: AppTheme.primary)
            FormTotalRow(title: "Đã trả", value: Formatters.money(stockIn.paidAmount), color: AppTheme.success)
            FormTotalRow(title: "Còn nợ", value: Formatters.money(stockIn.remainingValue), color: AppTheme.danger)
        }
        .appCard()
    }

    private func infoCard(_ stockIn: StockIn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Thông tin")
                .font(.headline)

            infoRow(icon: "phone.fill", title: "Điện thoại", value: stockIn.supplierPhone?.isEmpty == false ? stockIn.supplierPhone! : "—")
            infoRow(icon: "mappin.and.ellipse", title: "Địa chỉ", value: stockIn.supplierAddress?.isEmpty == false ? stockIn.supplierAddress! : "—")

            if let notes = stockIn.notes, !notes.isEmpty {
                Divider()
                Text("Ghi chú")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(notes)
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actionBar(_ stockIn: StockIn) -> some View {
        HStack(spacing: 10) {
            Button {
                showEdit = true
            } label: {
                Label("Sửa phiếu", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .foregroundStyle(.white)
            .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                showDeleteConfirm = true
            } label: {
                Group {
                    if isDeleting {
                        ProgressView()
                            .tint(AppTheme.danger)
                    } else {
                        Label("Xoá phiếu", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .foregroundStyle(AppTheme.danger)
            .background(AppTheme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(isDeleting)
        }
        .padding(10)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: 6)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.background.ignoresSafeArea(edges: .bottom))
        .opacity(isDeleting ? 0.85 : 1)
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        do {
            stockIn = try await service.fetchStockIn(id: stockInId)
            #if DEBUG
            if ProcessInfo.processInfo.environment["IOS_TEST_SCREEN"] == "stockInEdit" {
                showEdit = true
            }
            #endif
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isLoading = false
    }

    @MainActor
    private func deleteStockIn() async {
        guard let stockIn else { return }
        isDeleting = true
        error = nil
        do {
            try await service.deleteStockIn(stockIn)
            NotificationCenter.default.post(name: .materialsDidChange, object: nil)
            NotificationCenter.default.post(name: .stockInsDidChange, object: nil)
            dismiss()
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isDeleting = false
    }
}
