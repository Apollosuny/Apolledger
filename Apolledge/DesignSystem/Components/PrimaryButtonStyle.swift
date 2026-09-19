//
//  PrimaryButtonStyle.swift
//  Apolledge
//

import SwiftUI

/// Full-width ink button. Disabled state uses hairline fill per the design system.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration)
    }

    private struct PrimaryButton: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(AppTypography.button)
                .foregroundStyle(isEnabled ? AppColors.paper : AppColors.inkTertiary)
                .frame(maxWidth: .infinity, minHeight: AppSpacing.primaryButtonHeight)
                .background(
                    isEnabled ? AppColors.ink : AppColors.hairline,
                    in: RoundedRectangle(cornerRadius: AppRadius.control)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.control))
                .scaleEffect(configuration.isPressed ? AppMotion.pressedScale : 1)
                .animation(AppMotion.standard, value: configuration.isPressed)
                .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                    isPressed
                }
        }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

#Preview {
    VStack(spacing: 12) {
        Button("Đăng nhập") {}
            .buttonStyle(.primary)
        Button("Đăng nhập") {}
            .buttonStyle(.primary)
            .disabled(true)
    }
    .padding()
    .background(AppColors.paper)
}
