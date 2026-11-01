//
//  AppTabBar.swift
//  Apolledge
//

import SwiftUI

enum AppTab: CaseIterable, Hashable {
    case ledger
    case budget
    case reports
    case recurring

    var title: String {
        switch self {
        case .ledger: "Sổ"
        case .budget: "Ngân sách"
        case .reports: "Báo cáo"
        case .recurring: "Định kỳ"
        }
    }

    var systemImage: String {
        switch self {
        case .ledger: "book"
        case .budget: "wallet.bifold"
        case .reports: "chart.bar"
        case .recurring: "calendar.badge.clock"
        }
    }
}

/// Design system: the selected tab turns dark ink, never green (green is reserved for money in).
/// The center button rises 24pt and is square-ish to stand apart from the round iOS default.
struct AppTabBar: View {
    @Binding var selection: AppTab
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            item(.ledger)
            item(.budget)
            addButton
            item(.reports)
            item(.recurring)
        }
        .padding(.top, 13)
        .padding(.horizontal, 10)
        .frame(height: AppSpacing.tabBarHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        // In the background so the line passes behind the raised button.
        .background {
            AppColors.paperSecondary
                .overlay(alignment: .top) { Hairline(strong: true) }
        }
    }

    private func item(_ tab: AppTab) -> some View {
        let color = tab == selection ? AppColors.ink : AppColors.inkTertiary
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18))
                    .frame(height: 21)
                Text(tab.title)
                    .font(AppTypography.tab)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == selection ? .isSelected : [])
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(AppColors.paper)
                .frame(width: 48, height: 48)
                .background(AppColors.ink, in: RoundedRectangle(cornerRadius: AppRadius.floatingButton))
                .shadow(color: AppColors.ink.opacity(0.35), radius: 11, y: 8)
        }
        .buttonStyle(.plain)
        .frame(width: 54)
        .offset(y: -24)
        .accessibilityLabel("Ghi một khoản")
    }
}
