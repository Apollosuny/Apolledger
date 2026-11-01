//
//  BudgetView.swift
//  Apolledge
//

import SwiftUI

/// What the limit sheet is editing: an existing budget line, or a choice among categories without one.
private enum BudgetEditor: Identifiable {
    case add([Account])
    case edit(BudgetSummary)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let line): line.id
        }
    }
}

/// The "Ngân sách" tab, always on the current month.
struct BudgetView: View {
    let revision: Int
    let onChanged: () -> Void

    @Environment(\.ledgerService) private var service
    @State private var viewModel = BudgetViewModel()
    @State private var editor: BudgetEditor?

    private let month = LedgerMonth(containing: .now)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let errorMessage = viewModel.errorMessage {
                    InlineError(message: errorMessage)
                }
                if let overview = viewModel.overview {
                    Group {
                        if overview.lines.isEmpty {
                            EmptyState(
                                title: "Trang trắng",
                                detail: "Chưa đặt ngân sách cho tháng này",
                                actionTitle: "Thêm danh mục",
                                action: { editor = .add(viewModel.availableCategories) }
                            )
                        } else {
                            summary(overview)
                            lines(overview)
                            DashedAddButton(title: "Thêm danh mục") {
                                editor = .add(viewModel.availableCategories)
                            }
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
            await viewModel.load(month: month, service: service)
        }
        .refreshable {
            await viewModel.load(month: month, service: service)
        }
        .sheet(item: $editor) { editor in
            BudgetLimitSheet(editor: editor, month: month, onSaved: onChanged)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(AppRadius.sheet)
        }
    }

    private var header: some View {
        HStack {
            Text("Ngân sách")
                .font(AppTypography.screenTitle)
                .foregroundStyle(AppColors.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let overview = viewModel.overview {
                SectionLabel("T\(month.month) · còn \(overview.daysLeft) ngày")
            }
        }
        .frame(height: AppSpacing.headerHeight)
    }

    private func summary(_ overview: BudgetOverview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HeroAmount(amount: overview.spentVnd, font: AppTypography.heroSecondary)
                Spacer()
                Text("/ \(Money.grouped(overview.limitVnd))")
                    .font(.custom("GeistMono-Regular", size: 12))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.inkSecondary)
            }
            ProgressLine(fraction: overview.usedFraction)
            if overview.limitVnd > 0 {
                Text(overview.paceText)
                    .font(.custom("Geist-Regular", size: 12.5))
                    .foregroundStyle(AppColors.inkSecondary)
            }
        }
        .padding(.bottom, AppSpacing.md)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
    }

    private func lines(_ overview: BudgetOverview) -> some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(overview.lines) { line in
                Button { editor = .edit(line) } label: {
                    row(line)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Design system: over budget reads as bold, underlined text in the expense color, never a filled background.
    private func row(_ line: BudgetSummary) -> some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: LedgerIcon.symbol(for: line.icon))
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(width: 26)
                    .accessibilityHidden(true)
                Text(line.name)
                    .font(line.isOverBudget ? AppTypography.captionStrong : AppTypography.row)
                    .underline(line.isOverBudget)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Text(line.remainingText)
                    .font(AppTypography.figureMedium)
                    .monospacedDigit()
                    .foregroundStyle(line.isOverBudget ? AppColors.expense : AppColors.inkSecondary)
            }
            ProgressLine(fraction: line.usedFraction, color: line.isOverBudget ? AppColors.expense : AppColors.ink)
                .padding(.leading, 38)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct BudgetLimitSheet: View {
    let editor: BudgetEditor
    let month: LedgerMonth
    let onSaved: () -> Void

    @Environment(\.ledgerService) private var service
    @Environment(\.dismiss) private var dismiss
    @State private var categoryID: String?
    @State private var limitText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var editedLine: BudgetSummary? {
        if case .edit(let line) = editor { line } else { nil }
    }

    private var limitVnd: Int64? {
        Money.parse(limitText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var selectedID: String? { editedLine?.accountId ?? categoryID }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(editedLine?.name ?? "Thêm danh mục")
                    .font(AppTypography.sheetTitle)
                    .foregroundStyle(AppColors.ink)

                if case .add(let categories) = editor {
                    if categories.isEmpty {
                        Text("Mọi danh mục đều đã có ngân sách.")
                            .font(AppTypography.subtitle)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
                    FlowLayout {
                        ForEach(categories) { account in
                            CategoryChip(account: account, isSelected: account.id == categoryID) {
                                categoryID = account.id
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel("Mức tháng \(month.month)")
                    TextField("0", text: $limitText)
                        .font(AppTypography.figureEntry)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.ink)
                        .keyboardType(.numberPad)
                        .onChange(of: limitText) {
                            let formatted = Money.formattedInput(limitText)
                            if formatted != limitText { limitText = formatted }
                        }
                }

                if let errorMessage {
                    InlineError(message: errorMessage)
                }

                Button("Lưu") { Task { await save() } }
                    .buttonStyle(.primary)
                    .disabled(limitVnd == nil || selectedID == nil || isSubmitting)

                if let editedLine {
                    Button("Bỏ ngân sách") { Task { await remove(editedLine) } }
                        .font(AppTypography.row)
                        .foregroundStyle(AppColors.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(isSubmitting)
                }
            }
            .padding(AppSpacing.screenHorizontal)
        }
        .background(AppColors.paper)
        .onAppear {
            if let limit = editedLine?.limitVnd { limitText = Money.grouped(limit) }
        }
    }

    private func save() async {
        guard let selectedID, let limitVnd else { return }
        await perform { try await service.setBudget(accountID: selectedID, month: month, limitVnd: limitVnd) }
    }

    private func remove(_ line: BudgetSummary) async {
        await perform { try await service.deleteBudget(accountID: line.accountId, month: month) }
    }

    private func perform(_ operation: () async throws -> Void) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await operation()
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
    BudgetView(revision: 0, onChanged: {})
}
