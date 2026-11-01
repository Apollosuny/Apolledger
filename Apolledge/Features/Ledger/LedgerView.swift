//
//  LedgerView.swift
//  Apolledge
//

import SwiftUI

/// The "Sổ" tab.
struct LedgerView: View {
    let username: String
    let revision: Int
    let onOpen: (LedgerItem) -> Void
    let onAdd: () -> Void
    let onChanged: () -> Void
    let onSignOut: () -> Void

    @Environment(\.ledgerService) private var service
    @State private var viewModel = LedgerViewModel()
    @State private var month = LedgerMonth(containing: .now)
    @State private var isSearching = false
    @State private var showsMonthPicker = false
    @State private var showsAccountActions = false
    @State private var showsWalletBalance = false
    @FocusState private var isSearchFocused: Bool

    private struct LoadKey: Hashable {
        let month: LedgerMonth
        let revision: Int
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                header
                if isSearching { searchField }
                overview
                if let errorMessage = viewModel.errorMessage {
                    InlineError(message: errorMessage)
                }
                days.fadesIn(when: viewModel.hasLoaded)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.paper)
        .task(id: LoadKey(month: month, revision: revision)) {
            await viewModel.load(month: month, service: service)
        }
        .refreshable {
            await viewModel.load(month: month, service: service)
        }
        .sheet(isPresented: $showsMonthPicker) {
            MonthPickerSheet(selection: $month)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsWalletBalance) {
            WalletBalanceSheet(wallets: viewModel.wallets, onSaved: onChanged)
                .presentationDetents([.medium])
                .presentationCornerRadius(AppRadius.sheet)
        }
        .confirmationDialog(username, isPresented: $showsAccountActions, titleVisibility: .visible) {
            Button("Đăng xuất", role: .destructive, action: onSignOut)
        }
    }

    private var header: some View {
        HStack {
            Text(month.name)
                .font(AppTypography.screenTitle)
                .foregroundStyle(AppColors.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: -2) {
                HeaderIconButton(systemImage: "magnifyingglass", label: "Tìm kiếm") {
                    isSearching.toggle()
                    isSearchFocused = isSearching
                    if !isSearching { viewModel.searchText = "" }
                }
                HeaderIconButton(systemImage: "calendar", label: "Chọn tháng") {
                    showsMonthPicker = true
                }
                HeaderIconButton(systemImage: "person", label: "Tài khoản") {
                    showsAccountActions = true
                }
            }
        }
        .frame(height: AppSpacing.headerHeight)
    }

    private var searchField: some View {
        TextField("Tìm theo ghi chú, danh mục, ví", text: $viewModel.searchText)
            .font(AppTypography.body)
            .foregroundStyle(AppColors.ink)
            .focused($isSearchFocused)
            .submitLabel(.search)
            .padding(.horizontal, 14)
            .frame(height: AppSpacing.controlHeight)
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control).strokeBorder(AppColors.hairlineStrong, lineWidth: 1)
            }
    }

    @ViewBuilder
    private var overview: some View {
        if let spendable = viewModel.spendable {
            spendableOverview(spendable)
        } else {
            monthOverview
        }
    }

    private func spendableOverview(_ spendable: SpendableToday) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if spendable.needsWalletBalance {
                Button { showsWalletBalance = true } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nhập số dư ví")
                            .font(AppTypography.screenTitle)
                            .foregroundStyle(AppColors.ink)
                        Text("Để biết hôm nay bạn dùng được bao nhiêu.")
                            .font(AppTypography.subtitle)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button { showsWalletBalance = true } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        SectionLabel("Dùng được hôm nay")
                        HeroAmount(
                            amount: spendable.todayVnd,
                            color: spendable.todayVnd < 0 ? AppColors.expense : AppColors.ink
                        )
                        Text(spendable.statusText)
                            .font(AppTypography.subtitle)
                            .foregroundStyle(AppColors.inkSecondary)
                        Text(spendable.basisText)
                            .font(AppTypography.figureSmall)
                            .foregroundStyle(AppColors.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Sửa số dư ví")
            }
        }
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
    }

    private var monthOverview: some View {
        let remaining = viewModel.summary.remaining(budgetLimitVnd: viewModel.budgetLimitVnd)
        return VStack(alignment: .leading, spacing: 9) {
            SectionLabel(remaining.label)
            HeroAmount(amount: remaining.amountVnd)
            HStack(spacing: AppSpacing.md) {
                Text("vào \(Money.grouped(viewModel.summary.incomeVnd))")
                Text("ra \(Money.grouped(viewModel.summary.expenseVnd))")
            }
            .font(AppTypography.figureSmall)
            .foregroundStyle(AppColors.inkSecondary)
        }
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
    }

    @ViewBuilder
    private var days: some View {
        let days = viewModel.visibleDays
        if days.isEmpty, viewModel.errorMessage == nil {
            if viewModel.searchText.isEmpty {
                EmptyState(title: "Trang trắng", detail: "Chưa ghi gì trong tháng này", actionTitle: "Ghi khoản đầu tiên", action: onAdd)
            } else {
                EmptyState(title: "Không tìm thấy khoản nào")
            }
        } else {
            LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            SectionLabel(day.label)
                            Spacer()
                            Text(Money.net(day.netVnd))
                                .font(AppTypography.figureSmall)
                                .monospacedDigit()
                                .foregroundStyle(AppColors.inkTertiary)
                        }
                        .padding(.bottom, 6)

                        ForEach(day.items) { item in
                            Button { onOpen(item) } label: {
                                TransactionRow(
                                    icon: item.iconName,
                                    title: item.title,
                                    meta: item.meta,
                                    amount: item.flow.map { Money.signed(item.amountVnd, flow: $0) } ?? Money.grouped(item.amountVnd),
                                    amountColor: item.flow.amountColor
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

extension Optional where Wrapped == MoneyFlow {
    var amountColor: Color {
        switch self {
        case .expense: AppColors.expense
        case .income: AppColors.income
        case nil: AppColors.ink
        }
    }
}

private struct MonthPickerSheet: View {
    @Binding var selection: LedgerMonth
    @Environment(\.dismiss) private var dismiss

    private let months = Array(LedgerMonth(containing: .now).trailing(24).reversed())

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(months) { month in
                    Button {
                        selection = month
                        dismiss()
                    } label: {
                        HStack {
                            Text(month.name)
                                .font(AppTypography.row)
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Text(String(month.year))
                                .font(AppTypography.figureMedium)
                                .foregroundStyle(AppColors.inkTertiary)
                            if month == selection {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.ink)
                            }
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                        .overlay(alignment: .top) { Hairline() }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.lg)
        }
        .background(AppColors.paper)
    }
}

#Preview {
    LedgerView(username: "minh.tran", revision: 0, onOpen: { _ in }, onAdd: {}, onChanged: {}, onSignOut: {})
}
