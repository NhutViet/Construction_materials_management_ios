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
            Form {
                Section("Tài khoản") {
                    LabeledContent("Tên đăng nhập", value: auth.profile?.username ?? "—")
                    LabeledContent("Email", value: auth.profile?.email ?? "—")
                }

                Section("Thông tin cá nhân") {
                    TextField("Họ và tên", text: $fullname)
                    TextField("Số điện thoại", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Thông tin thanh toán") {
                    TextField("Ngân hàng", text: $bankName)
                    TextField("Số tài khoản", text: $bankNumber)
                        .keyboardType(.numberPad)
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }
                }
            }
            .navigationTitle("Sửa hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Lưu")
                        }
                    }
                    .disabled(isSaving)
                }
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
