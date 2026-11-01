//
//  RecurringView.swift
//  Apolledge
//

import SwiftUI

/// The "Định kỳ" tab.
struct RecurringView: View {
    let revision: Int
    let onChanged: () -> Void

    @Environment(\.ledgerService) private var service
    @State private var viewModel = RecurringViewModel()
    @State private var showsForm = false
    @State private var actionItem: RecurringItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Định kỳ")
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(AppColors.ink)
                    .accessibilityAddTraits(.isHeader)
                    .frame(height: AppSpacing.headerHeight)
                if let errorMessage = viewModel.errorMessage {
                    InlineError(message: errorMessage)
                }
                if let overview = viewModel.overview {
                    Group {
                        if overview.items.isEmpty {
                            EmptyState(
                                title: "Trang trắng",
                                detail: "Chưa có khoản định kỳ nào",
                                actionTitle: "Thêm khoản định kỳ",
                                action: { showsForm = true }
                            )
                        } else {
                            summary(overview)
                            upcoming(overview)
                            DashedAddButton(title: "Thêm khoản định kỳ") { showsForm = true }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.paper)
        .task(id: revision) {
            await viewModel.load(service: service)
        }
        .refreshable {
            await viewModel.load(service: service)
        }
        .sheet(isPresented: $showsForm) {
            RecurringFormSheet(accounts: viewModel.accounts, onSaved: onChanged)
                .presentationCornerRadius(AppRadius.sheet)
        }
        .confirmationDialog(
            actionItem?.order.name ?? "",
            isPresented: Binding(get: { actionItem != nil }, set: { if !$0 { actionItem = nil } }),
            titleVisibility: .visible,
            presenting: actionItem
        ) { item in
            if item.isDue {
                Button("Ghi ngay") { change { try await service.postStandingOrder(id: item.id) } }
            }
            if item.order.isPaused {
                Button("Tiếp tục") { change { try await service.setStandingOrderPaused(id: item.id, paused: false) } }
            } else {
                Button("Tạm dừng") { change { try await service.setStandingOrderPaused(id: item.id, paused: true) } }
            }
        }
    }

    private func change(_ operation: @escaping () async throws -> Void) {
        Task {
            if await viewModel.perform(operation) { onChanged() }
        }
    }

    private func summary(_ overview: RecurringOverview) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel("Cố định mỗi tháng")
            HeroAmount(amount: overview.monthlyExpenseVnd, font: AppTypography.heroSecondary)
            if !overview.detailText.isEmpty {
                Text(overview.detailText)
                    .font(.custom("Geist-Regular", size: 12.5))
                    .foregroundStyle(AppColors.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, AppSpacing.md)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
    }

    private func upcoming(_ overview: RecurringOverview) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel("Sắp tới").padding(.bottom, 6)
            ForEach(overview.items) { item in
                Button { actionItem = item } label: {
                    row(item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ item: RecurringItem) -> some View {
        HStack(spacing: 13) {
            VStack(spacing: 1) {
                Text(item.nextRun.map { String($0.day) } ?? "–")
                    .font(.custom("GeistMono-Medium", size: 15))
                    .monospacedDigit()
                    .foregroundStyle(item.isDueSoon ? AppColors.ink : AppColors.inkTertiary)
                Text(item.nextRun.map { "TH\($0.month)" } ?? "")
                    .font(.custom("GeistMono-Regular", size: 9))
                    .tracking(0.9)
                    .foregroundStyle(AppColors.inkTertiary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.order.name)
                    .font(AppTypography.row)
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                Text(item.meta)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppColors.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppSpacing.xs)

            Text(item.flow.map { Money.signed(item.order.amountVnd, flow: $0) } ?? Money.grouped(item.order.amountVnd))
                .font(AppTypography.amount)
                .monospacedDigit()
                .foregroundStyle(item.flow.amountColor)
        }
        .padding(.vertical, 13)
        .opacity(item.order.isPaused ? 0.55 : 1)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { Hairline() }
        .accessibilityElement(children: .combine)
    }
}

private struct RecurringFormSheet: View {
    let accounts: [Account]
    let onSaved: () -> Void

    @Environment(\.ledgerService) private var service
    @Environment(\.dismiss) private var dismiss
    @State private var flow = MoneyFlow.expense
    @State private var name = ""
    @State private var amountText = ""
    @State private var categoryID: String?
    @State private var walletID: String?
    @State private var dayOfMonth = 1
    @State private var autoPost = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var categories: [Account] {
        accounts.filter { $0.isActive && $0.type == (flow == .expense ? .expense : .income) }
    }

    private var wallets: [Account] {
        accounts.filter { $0.isActive && $0.type == .asset }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var amountVnd: Int64? {
        Money.parse(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var canSubmit: Bool {
        !trimmedName.isEmpty && amountVnd != nil && categoryID != nil && walletID != nil && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Thêm khoản định kỳ")
                    .font(AppTypography.sheetTitle)
                    .foregroundStyle(AppColors.ink)

                SegmentedSwitch(
                    options: [(MoneyFlow.expense, "Tiền ra"), (MoneyFlow.income, "Tiền vào")],
                    selection: $flow
                )

                FlowLayout {
                    ForEach(categories) { account in
                        CategoryChip(account: account, isSelected: account.id == categoryID) {
                            categoryID = account.id
                        }
                    }
                }

                VStack(spacing: 0) {
                    DetailRow(label: "Tên") {
                        TextField("Tiền thuê nhà", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    DetailRow(label: "Số tiền") {
                        TextField("0", text: $amountText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .onChange(of: amountText) {
                                let formatted = Money.formattedInput(amountText)
                                if formatted != amountText { amountText = formatted }
                            }
                    }
                    DetailRow(label: "Ví") {
                        Menu(wallets.first { $0.id == walletID }?.name ?? "Chọn ví") {
                            ForEach(wallets) { wallet in
                                Button(wallet.name) { walletID = wallet.id }
                            }
                        }
                        .tint(AppColors.ink)
                    }
                    DetailRow(label: "Ngày trong tháng") {
                        Stepper(String(dayOfMonth), value: $dayOfMonth, in: 1...31)
                            .fixedSize()
                    }
                    DetailRow(label: "Tự động ghi") {
                        Toggle("Tự động ghi", isOn: $autoPost)
                            .labelsHidden()
                            .tint(AppColors.ink)
                    }
                    Hairline()
                }

                if let errorMessage {
                    InlineError(message: errorMessage)
                }

                Button("Lưu") { Task { await save() } }
                    .buttonStyle(.primary)
                    .disabled(!canSubmit)
            }
            .padding(AppSpacing.screenHorizontal)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.paper)
        .onAppear {
            categoryID = categories.first?.id
            walletID = wallets.first?.id
        }
        .onChange(of: flow) { categoryID = categories.first?.id }
    }

    private func save() async {
        guard let amountVnd, let categoryID, let walletID else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await service.createStandingOrder(StandingOrderDraft(
                name: trimmedName,
                flow: flow,
                amountVnd: amountVnd,
                categoryID: categoryID,
                walletID: walletID,
                dayOfMonth: dayOfMonth,
                autoPost: autoPost
            ))
            dismiss()
            onSaved()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.userMessage
        }
    }
}

#Preview {
    RecurringView(revision: 0, onChanged: {})
}
