//
//  AppTextField.swift
//  Apolledge
//

import SwiftUI

/// Labeled text field. Keyboard traits (content type, submit label, capitalization) are applied by the caller.
struct AppTextField<Field: Hashable>: View {
    enum Kind {
        case plain
        case secure
    }

    let label: LocalizedStringKey
    @Binding var text: String
    let field: Field
    let focus: FocusState<Field?>.Binding
    var kind: Kind = .plain

    @State private var isSecureTextRevealed = false

    private var isFocused: Bool { focus.wrappedValue == field }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .appLabelStyle()
                .accessibilityHidden(true)

            HStack(spacing: AppSpacing.xs) {
                input
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                    .focused(focus, equals: field)
                    .accessibilityLabel(Text(label))

                if kind == .secure {
                    revealButton
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, kind == .secure ? 2 : 14)
            .frame(height: AppSpacing.controlHeight)
            .background(AppColors.paper, in: RoundedRectangle(cornerRadius: AppRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .strokeBorder(isFocused ? AppColors.income : AppColors.hairlineStrong, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.control))
            .onTapGesture { focus.wrappedValue = field }
            .animation(AppMotion.standard, value: isFocused)
        }
    }

    @ViewBuilder
    private var input: some View {
        if kind == .secure && !isSecureTextRevealed {
            SecureField("", text: $text)
        } else {
            TextField("", text: $text)
        }
    }

    private var revealButton: some View {
        Button {
            isSecureTextRevealed.toggle()
        } label: {
            Image(systemName: isSecureTextRevealed ? "eye.slash" : "eye")
                .font(.system(size: 16))
                .foregroundStyle(AppColors.inkTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSecureTextRevealed ? "Ẩn mật khẩu" : "Hiện mật khẩu")
    }
}
