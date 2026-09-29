//
//  LoginView.swift
//  Apolledge
//

import SwiftUI

struct LoginView: View {
    enum Field: Hashable {
        case username
        case password
    }

    @Environment(AppSession.self) private var session
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    var onForgotPassword: () -> Void = {}
    var onRegister: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                fields
                actions
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 28)
            .padding(.bottom, AppSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Chào bạn\ntrở lại")
                .font(AppTypography.display)
                .tracking(-0.36)
                .foregroundStyle(AppColors.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Đăng nhập để tiếp tục ghi sổ.")
                .font(AppTypography.subtitle)
                .foregroundStyle(AppColors.inkSecondary)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AppTextField(
                label: "Tên đăng nhập",
                text: $viewModel.username,
                field: .username,
                focus: $focusedField
            )
            .textContentType(.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .onSubmit { focusedField = .password }

            AppTextField(
                label: "Mật khẩu",
                text: $viewModel.password,
                field: .password,
                focus: $focusedField,
                kind: .secure
            )
            .textContentType(.password)
            .submitLabel(.go)
            .onSubmit(submit)

            if let errorMessage = viewModel.errorMessage {
                // Design system reserves the expense color for money going out, not for errors.
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.ink)
                    .transition(.opacity)
            }

            Button("Quên mật khẩu?", action: onForgotPassword)
                .font(AppTypography.link)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .animation(AppMotion.standard, value: viewModel.errorMessage)
    }

    private var actions: some View {
        VStack(spacing: 14) {
            Button(action: submit) {
                ZStack {
                    Text("Đăng nhập")
                        .opacity(viewModel.isSubmitting ? 0 : 1)
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(AppColors.paper)
                    }
                }
            }
            .buttonStyle(.primary)
            .disabled(!viewModel.isFormFilled)
            .allowsHitTesting(!viewModel.isSubmitting)
            .accessibilityLabel(viewModel.isSubmitting ? "Đang đăng nhập" : "Đăng nhập")

            Button(action: onRegister) {
                Text("Chưa có tài khoản? \(registerLinkText)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }

    private var registerLinkText: Text {
        Text("Đăng ký")
            .font(AppTypography.captionStrong)
            .foregroundStyle(AppColors.ink)
            .underline(color: AppColors.ink.opacity(0.35))
    }

    private func submit() {
        focusedField = nil
        Task {
            await viewModel.submit(signIn: session.signIn)
        }
    }
}

#Preview {
    LoginView()
        .environment(AppContainer.preview().session)
}
