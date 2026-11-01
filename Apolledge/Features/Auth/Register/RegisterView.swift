//
//  RegisterView.swift
//  Apolledge
//
//  Created by Trung Trần on 12/10/26.
//

import SwiftUI

struct RegisterView: View {
    enum Field: Hashable {
        case username
        case email
        case password
    }

    @Environment(AppSession.self) private var session
    @State private var viewModel = RegisterViewModel()
    @FocusState private var focusedField: Field?

    var onShowLogin: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                backButton
                header
                fields
                terms
                actions
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.paper)
    }

    private var backButton: some View {
        Button(action: onShowLogin) {
            Label("Đăng nhập", systemImage: "chevron.left")
                .font(AppTypography.row)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tạo tài khoản")
                .font(AppTypography.registerTitle)
                .tracking(-0.32)
                .foregroundStyle(AppColors.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Bắt đầu ghi sổ chỉ trong một phút.")
                .font(AppTypography.subtitle)
                .foregroundStyle(AppColors.inkSecondary)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            .onSubmit { focusedField = .email }

            AppTextField(
                label: "Email",
                text: $viewModel.email,
                field: .email,
                focus: $focusedField
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
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
            .textContentType(.newPassword)
            .submitLabel(.done)

            if let errorMessage = viewModel.errorMessage {
                InlineError(message: errorMessage)
            }
        }
        .animation(AppMotion.standard, value: viewModel.errorMessage)
    }

    private var terms: some View {
        Button {
            viewModel.acceptedTerms.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(viewModel.acceptedTerms ? AppColors.paper : .clear)
                    .frame(width: 18, height: 18)
                    .background(viewModel.acceptedTerms ? AppColors.ink : .clear, in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5).strokeBorder(AppColors.ink, lineWidth: 1.5)
                    }
                    .padding(.top, 1)

                Text("Tôi đồng ý với Điều khoản sử dụng và Chính sách bảo mật.")
                    .font(.custom("Geist-Regular", size: 12.5))
                    .foregroundStyle(AppColors.inkSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(minHeight: 44, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.acceptedTerms ? .isSelected : [])
    }

    private var actions: some View {
        VStack(spacing: 14) {
            Button(action: submit) {
                ZStack {
                    Text("Tạo tài khoản")
                        .opacity(viewModel.isSubmitting ? 0 : 1)
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(AppColors.paper)
                    }
                }
            }
            .buttonStyle(.primary)
            .disabled(!viewModel.isFormValid)
            .allowsHitTesting(!viewModel.isSubmitting)
            .accessibilityLabel(viewModel.isSubmitting ? "Đang tạo tài khoản" : "Tạo tài khoản")

            Button(action: onShowLogin) {
                Text("Đã có tài khoản? \(loginLinkText)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }

    private var loginLinkText: Text {
        Text("Đăng nhập")
            .font(AppTypography.captionStrong)
            .foregroundStyle(AppColors.ink)
            .underline(color: AppColors.ink.opacity(0.35))
    }

    private func submit() {
        focusedField = nil
        Task {
            await viewModel.submit(register: session.register)
        }
    }
}

#Preview {
    RegisterView()
        .environment(AppContainer.preview().session)
}
