//
//  WalletBalanceSheet.swift
//  Apolledge
//

import SwiftUI

struct WalletBalance: Identifiable, Hashable {
    let account: Account
    let balanceVnd: Int64
    var id: String { account.id }
}

enum WalletBalanceCorrection {
    static let offsetAccountName = "Số dư đầu kỳ"

    /// Corrects a wallet against an equity account, so the difference is neither income nor spending.
    /// Nil when the balance is already right.
    static func draft(
        currentVnd: Int64,
        targetVnd: Int64,
        walletID: String,
        offsetAccountID: String,
        idempotencyKey: String,
        now: Date
    ) -> TransactionDraft? {
        guard currentVnd != targetVnd else { return nil }
        return TransactionDraft(
            flow: targetVnd > currentVnd ? .income : .expense,
            amountVnd: abs(targetVnd - currentVnd),
            categoryID: offsetAccountID,
            walletID: walletID,
            note: "Điều chỉnh số dư",
            occurredAt: now,
            idempotencyKey: idempotencyKey
        )
    }
}

struct WalletBalanceSheet: View {
    let wallets: [WalletBalance]
    let onSaved: () -> Void

    @Environment(\.ledgerService) private var service
    @Environment(\.dismiss) private var dismiss
    @State private var walletID: String?
    @State private var amountText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isAmountFocused: Bool

    /// One key per sheet, so a retry after a lost response does not correct the wallet twice.
    @State private var idempotencyKey = UUID().uuidString

    private var selected: WalletBalance? {
        wallets.first { $0.id == walletID } ?? wallets.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Số dư ví")
                    .font(AppTypography.sheetTitle)
                    .foregroundStyle(AppColors.ink)
                    .accessibilityAddTraits(.isHeader)

                Text("Nhập số tiền đang có. Phần chênh lệch không tính vào thu hay chi.")
                    .font(AppTypography.subtitle)
                    .foregroundStyle(AppColors.inkSecondary)

                if wallets.count > 1 {
                    DetailRow(label: "Ví") {
                        Menu(selected?.account.name ?? "Chọn ví") {
                            ForEach(wallets) { wallet in
                                Button(wallet.account.name) { select(wallet) }
                            }
                        }
                        .tint(AppColors.ink)
                    }
                }

                TextField("0", text: $amountText)
                    .font(AppTypography.figureEntry)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.ink)
                    .keyboardType(.numberPad)
                    .focused($isAmountFocused)
                    .onChange(of: amountText) {
                        let formatted = Money.formattedInput(amountText)
                        if formatted != amountText { amountText = formatted }
                    }
                    .accessibilityLabel("Số dư")

                if let errorMessage {
                    InlineError(message: errorMessage)
                }

                Button("Lưu") { Task { await save() } }
                    .buttonStyle(.primary)
                    .disabled(Money.parse(amountText) == nil || selected == nil || isSubmitting)
            }
            .padding(AppSpacing.screenHorizontal)
        }
        .background(AppColors.paper)
        .onAppear {
            if let selected { select(selected) }
            isAmountFocused = true
        }
    }

    private func select(_ wallet: WalletBalance) {
        walletID = wallet.id
        amountText = wallet.balanceVnd > 0 ? Money.grouped(wallet.balanceVnd) : ""
    }

    private func offsetAccountID() async throws -> String {
        let accounts = try await service.accounts()
        if let existing = accounts.first(where: {
            $0.type == .equity && $0.isActive && $0.name == WalletBalanceCorrection.offsetAccountName
        }) {
            return existing.id
        }
        return try await service.createAccount(
            type: .equity,
            name: WalletBalanceCorrection.offsetAccountName,
            icon: nil
        ).id
    }

    private func save() async {
        guard let selected, let targetVnd = Money.parse(amountText) else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            if targetVnd != selected.balanceVnd {
                let draft = WalletBalanceCorrection.draft(
                    currentVnd: selected.balanceVnd,
                    targetVnd: targetVnd,
                    walletID: selected.id,
                    offsetAccountID: try await offsetAccountID(),
                    idempotencyKey: idempotencyKey,
                    now: .now
                )
                if let draft { try await service.createTransaction(draft) }
            }
            dismiss()
            onSaved()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.userMessage
        }
    }
}
