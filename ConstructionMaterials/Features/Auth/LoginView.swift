import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username
        case password
    }

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !auth.isLoading
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Quản lý vật liệu")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Đăng nhập để tiếp tục quản lý kho hàng")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 48)

                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tên đăng nhập")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(AppTheme.primary)
                                TextField("Nhập username hoặc email", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textContentType(.username)
                                    .focused($focusedField, equals: .username)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mật khẩu")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(AppTheme.primary)

                                Group {
                                    if showPassword {
                                        TextField("Nhập mật khẩu", text: $password)
                                    } else {
                                        SecureField("Nhập mật khẩu", text: $password)
                                    }
                                }
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    if canSubmit {
                                        submit()
                                    }
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu")
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        if let error = auth.error {
                            Text(error)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: submit) {
                            HStack(spacing: 10) {
                                if auth.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                Text(auth.isLoading ? "Đang đăng nhập..." : "Đăng nhập")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .foregroundStyle(.white)
                            .background(canSubmit ? AppTheme.primary : Color.gray.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(!canSubmit)

                        Text("Tài khoản test: viet3557 / 123456789")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(22)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: AppTheme.cardShadow, radius: 24, x: 0, y: 12)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 22)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            focusedField = .username
        }
    }

    private func submit() {
        guard canSubmit else { return }
        focusedField = nil
        Task {
            await auth.login(username: username, password: password)
        }
    }
}
