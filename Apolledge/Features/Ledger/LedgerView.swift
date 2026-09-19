//
//  LedgerView.swift
//  Apolledge
//

import SwiftUI

/// Placeholder for the "Sổ" tab until the screen is implemented.
struct LedgerView: View {
    let username: String
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Sổ")
                .font(AppTypography.month)
                .foregroundStyle(AppColors.ink)

            Text("Đã đăng nhập: \(username)")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkSecondary)

            Button("Đăng xuất", action: onSignOut)
                .font(AppTypography.row)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(minHeight: 44)
        }
        .padding(AppSpacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.paper)
    }
}

#Preview {
    LedgerView(username: "minh.tran", onSignOut: {})
}
