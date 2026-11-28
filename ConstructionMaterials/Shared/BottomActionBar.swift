import SwiftUI

struct FormActionBar: View {
    var cancelTitle: String = "Hủy"
    var saveTitle: String = "Lưu"
    var isSaving: Bool = false
    var canSave: Bool = true
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text(cancelTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .foregroundStyle(.primary)
            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(isSaving)

            Button(action: onSave) {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(saveTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .foregroundStyle(.white)
            .background(
                canSave && !isSaving ? AppTheme.primary : Color.gray.opacity(0.45),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .disabled(isSaving || !canSave)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: 6)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(AppTheme.background.ignoresSafeArea(edges: .bottom))
    }
}

struct OrderActionBar: View {
    let canDeliver: Bool
    let canPay: Bool
    let isCancelled: Bool
    let onDeliver: () -> Void
    let onPay: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            if canDeliver || canPay {
                HStack(spacing: 10) {
                    if canDeliver {
                        button(
                            title: "Giao hàng",
                            icon: "shippingbox.fill",
                            foreground: .white,
                            background: AppTheme.primary,
                            action: onDeliver
                        )
                    }
                    if canPay {
                        button(
                            title: "Thanh toán",
                            icon: "creditcard.fill",
                            foreground: AppTheme.primary,
                            background: AppTheme.background,
                            action: onPay
                        )
                    }
                }
            }

            HStack(spacing: 10) {
                button(
                    title: "Sửa hóa đơn",
                    icon: "pencil",
                    foreground: AppTheme.primary,
                    background: AppTheme.background,
                    action: onEdit
                )
                if !isCancelled {
                    button(
                        title: "Hủy đơn",
                        icon: "xmark.circle",
                        foreground: AppTheme.danger,
                        background: AppTheme.danger.opacity(0.12),
                        action: onCancel
                    )
                }
            }
        }
        .padding(10)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: 6)
    }

    private func button(
        title: String,
        icon: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
