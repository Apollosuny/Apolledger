//
//  EntrySheet.swift
//  Apolledge
//

import SwiftUI

/// "Ghi một khoản": creates a transaction, or edits one by replacing it.
struct EntrySheet: View {
    let onSaved: () -> Void

    @Environment(\.ledgerService) private var service
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EntryViewModel
    @FocusState private var isAmountFocused: Bool

    init(mode: EntryMode, onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
        _viewModel = State(initialValue: EntryViewModel(mode: mode))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                header
                SegmentedSwitch(
                    options: [(MoneyFlow.expense, "Tiền ra"), (MoneyFlow.income, "Tiền vào")],
                    selection: $viewModel.flow
                )
                amountField
                categories
                details
                if let errorMessage = viewModel.errorMessage {
                    InlineError(message: errorMessage)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 18)
            .padding(.bottom, AppSpacing.sm)
        }
        .scrollDismissesKeyboard(.interactively)
        // Pinned so the number pad, which opens with the sheet, never covers the button.
        .safeAreaInset(edge: .bottom) {
            saveButton
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.paper)
        }
        .background(AppColors.paper)
        .presentationCornerRadius(AppRadius.sheet)
        .presentationDragIndicator(.hidden)
        .task {
            await viewModel.load(service: service)
            if case .create = viewModel.mode { isAmountFocused = true }
        }
    }

    private var header: some View {
        HStack {
            Text(isEditing ? "Sửa khoản" : "Ghi một khoản")
                .font(AppTypography.sheetTitle)
                .foregroundStyle(AppColors.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(width: 30, height: 30)
                    .background(AppColors.paperSecondary, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Đóng")
        }
    }

    private var isEditing: Bool {
        if case .edit = viewModel.mode { true } else { false }
    }

    private var amountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            TextField("0", text: $viewModel.amountText)
                .font(AppTypography.figureEntry)
                .monospacedDigit()
                .foregroundStyle(viewModel.flow == .expense ? AppColors.expense : AppColors.income)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($isAmountFocused)
                .fixedSize()
                .onChange(of: viewModel.amountText) { viewModel.amountDidChange() }
                .accessibilityLabel("Số tiền")
            Text("₫")
                .font(.custom("Geist-Regular", size: 22))
                .foregroundStyle(AppColors.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture { isAmountFocused = true }
    }

    private var categories: some View {
        FlowLayout {
            ForEach(viewModel.categories) { account in
                CategoryChip(account: account, isSelected: account.id == viewModel.categoryID) {
                    viewModel.categoryID = account.id
                }
            }
        }
    }

    private var details: some View {
        VStack(spacing: 0) {
            DetailRow(label: "Ghi chú") {
                TextField("Không bắt buộc", text: $viewModel.note)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
            }
            DetailRow(label: "Ví") {
                Menu {
                    ForEach(viewModel.wallets) { wallet in
                        Button(wallet.name) { viewModel.walletID = wallet.id }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.wallets.first { $0.id == viewModel.walletID }?.name ?? "Chọn ví")
                            .foregroundStyle(AppColors.ink)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.inkTertiary)
                    }
                }
            }
            DetailRow(label: "Ngày") {
                DatePicker("Ngày", selection: $viewModel.occurredAt, in: ...Date.now)
                    .labelsHidden()
                    .environment(\.timeZone, LedgerCalendar.timeZone)
                    .environment(\.locale, Locale(identifier: "vi_VN"))
            }
            Hairline()
        }
    }

    private var saveButton: some View {
        Button {
            isAmountFocused = false
            Task {
                if await viewModel.submit(service: service) {
                    dismiss()
                    onSaved()
                }
            }
        } label: {
            ZStack {
                Text("Lưu").opacity(viewModel.isSubmitting ? 0 : 1)
                if viewModel.isSubmitting {
                    ProgressView().tint(AppColors.paper)
                }
            }
        }
        .buttonStyle(.primary)
        .disabled(!viewModel.canSubmit)
        .allowsHitTesting(!viewModel.isSubmitting)
        .accessibilityLabel(viewModel.isSubmitting ? "Đang lưu" : "Lưu")
    }
}

#Preview {
    EntrySheet(mode: .create, onSaved: {})
}
