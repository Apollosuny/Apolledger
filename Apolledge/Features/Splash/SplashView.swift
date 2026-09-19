//
//  SplashView.swift
//  Apolledge
//

import SwiftUI

struct SplashView: View {
    @State private var progress: CGFloat = 0

    private let progressBarWidth: CGFloat = 130

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                BrandMark(
                    width: 56,
                    lineWidth: 3,
                    accent: AppColors.Splash.accent,
                    foreground: AppColors.Splash.foreground
                )

                Text("Apolledge")
                    .font(AppTypography.brand)
                    .foregroundStyle(AppColors.Splash.foreground)

                Text("Sổ ghi chép tài chính của riêng bạn")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.Splash.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 220)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(spacing: 10) {
                progressBar

                Text("phiên bản \(Self.appVersion)")
                    .appLabelStyle()
                    .tracking(1.2)
                    .foregroundStyle(AppColors.Splash.textTertiary)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.Splash.background)
        .statusBarHidden()
        .onAppear {
            withAnimation(.easeInOut(duration: 1)) {
                progress = 1
            }
        }
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(AppColors.Splash.track)
            Capsule()
                .fill(AppColors.Splash.accent)
                .frame(width: progressBarWidth * progress)
        }
        .frame(width: progressBarWidth, height: 2)
        .accessibilityHidden(true)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

#Preview {
    SplashView()
}
