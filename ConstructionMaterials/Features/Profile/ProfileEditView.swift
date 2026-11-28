import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore

    @State private var fullname: String
    @State private var phoneNumber: String
    @State private var bankName: String
    @State private var bankNumber: String
    @State private var isSaving = false
    @State private var error: String?

    init(profile: Profile) {
        _fullname = State(initialValue: profile.fullname ?? "")
        _phoneNumber = State(initialValue: profile.phoneNumber ?? "")
        _bankName = State(initialValue: profile.bankName ?? "")
        _bankNumber = State(initialValue: profile.bankNumber ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FormSection(title: "Tài khoản") {
                        FormTotalRow(title: "Tên đăng nhập", value: auth.profile?.username ?? "—")
                        FormTotalRow(title: "Email", value: auth.profile?.email ?? "—")
                    }

                    FormSection(title: "Thông tin cá nhân") {
                        FormField(
                            title: "Họ và tên",
                            placeholder: "Nguyễn Văn A",
                            icon: "person.fill",
                            text: $fullname
                        )
                        FormField(
                            title: "Số điện thoại",
                            placeholder: "09xx xxx xxx",
                            icon: "phone.fill",
                            text: $phoneNumber,
                            keyboard: .phonePad
                        )
                    }

                    FormSection(title: "Thông tin thanh toán") {
                        FormField(
                            title: "Ngân hàng",
                            placeholder: "Tên ngân hàng",
                            icon: "building.columns.fill",
                            text: $bankName
                        )
                        FormField(
                            title: "Số tài khoản",
                            placeholder: "Số tài khoản nhận tiền",
                            icon: "creditcard.fill",
                            text: $bankNumber,
                            keyboard: .numberPad
                        )
                    }

                    if let error {
                        ErrorBanner(message: error)
                    }
                }
                .padding(AppTheme.screenPadding)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Sửa hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FormActionBar(
                    isSaving: isSaving,
                    onCancel: { dismiss() },
                    onSave: save
                )
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.large])
    }

    private func save() {
        guard !fullname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Vui lòng nhập họ và tên."
            return
        }
        error = nil
        isSaving = true
        Task {
            await auth.updateProfile(
                fullname: fullname,
                phoneNumber: phoneNumber,
                bankName: bankName,
                bankNumber: bankNumber
            )
            if let authError = auth.error {
                self.error = authError
                isSaving = false
            } else {
                dismiss()
            }
        }
    }
}
