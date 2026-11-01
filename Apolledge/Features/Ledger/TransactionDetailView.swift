//
//  TransactionDetailView.swift
//  Apolledge
//

import SwiftUI

struct TransactionDetailView: View {
    let item: LedgerItem
    let onEdit: () -> Void
    let onChanged: () -> Void

    @Environment(\.ledgerService) private var service
    @State private var confirmsDelete = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                summary
                details
                if let errorMessage {
                    InlineError(message: errorMessage)
                }
                Button("Xoá giao dịch") { confirmsDelete = true }
                    .font(AppTypography.row)
                    .foregroundStyle(AppColors.expense)
                    .frame(minHeight: 44)
                    .disabled(isDeleting)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.paper)
        .toolbar {
            // Transfers have no category, so the entry form cannot represent them.
            if item.flow != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sửa", action: onEdit)
                        .font(AppTypography.row)
                }
            }
        }
        .confirmationDialog("Xoá giao dịch này?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Xoá", role: .destructive) {
                Task { await delete() }
            }
        } message: {
            Text("Số dư và ngân sách sẽ được tính lại.")
        }
    }

    private var summary: some View {
        VStack(spacing: 10) {
            Image(systemName: item.iconName)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.inkSecondary)
                .frame(width: 44, height: 44)
                .overlay { Circle().strokeBorder(AppColors.hairlineStrong, lineWidth: 1) }
                .accessibilityHidden(true)

            signedAmount

            Text(item.title)
                .font(AppTypography.row)
                .foregroundStyle(AppColors.ink)

            Text(LedgerDateFormat.dateTime(item.transaction.occurredAt))
                .font(AppTypography.figureSmall)
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(AppColors.inkTertiary)
        }
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
    }

    private var signedAmount: some View {
        let amount = item.flow.map { Money.signed(item.amountVnd, flow: $0) } ?? Money.grouped(item.amountVnd)
        return Text("\(Text(amount).foregroundStyle(item.flow.amountColor))\(Text(" ₫").font(AppTypography.heroCurrency).foregroundStyle(AppColors.inkTertiary))")
            .font(AppTypography.hero)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var details: some View {
        VStack(spacing: 0) {
            if let category = item.category {
                DetailRow(label: "Danh mục") { Text(category.name) }
            }
            if let wallet = item.wallet {
                DetailRow(label: "Ví") { Text(wallet.name) }
            }
            if let note = item.note {
                DetailRow(label: "Ghi chú") {
                    Text(note).multilineTextAlignment(.trailing)
                }
            }
            DetailRow(label: "Lặp lại") {
                Text(item.transaction.isFromStandingOrder ? "Định kỳ" : "Không")
            }
        }
    }

    private func delete() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await service.reverseTransaction(id: item.id)
            onChanged()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.userMessage
        }
    }
}
