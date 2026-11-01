//
//  EntryViewModel.swift
//  Apolledge
//

import Foundation
import Observation

enum EntryMode: Identifiable, Equatable {
    case create
    case edit(LedgerItem)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let item): item.id
        }
    }
}

@Observable
final class EntryViewModel {
    let mode: EntryMode

    var flow: MoneyFlow = .expense {
        didSet {
            guard flow != oldValue else { return }
            categoryID = categories.first?.id
        }
    }
    var amountText = ""
    var note = ""
    var occurredAt = Date.now
    var categoryID: String?
    var walletID: String?

    private(set) var accounts: [Account] = []
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    /// One key per sheet, so retrying after a lost response returns the posted transaction instead of duplicating it.
    private let idempotencyKey = UUID().uuidString

    init(mode: EntryMode) {
        self.mode = mode
        if case .edit(let item) = mode {
            flow = item.flow ?? .expense
            amountText = Money.grouped(item.amountVnd)
            note = item.note ?? ""
            occurredAt = item.transaction.occurredAt
            categoryID = item.category?.id
            walletID = item.wallet?.id
        }
    }

    var categories: [Account] {
        accounts.filter { $0.isActive && $0.type == (flow == .expense ? .expense : .income) }
    }

    var wallets: [Account] {
        accounts.filter { $0.isActive && $0.type == .asset }
    }

    var amountVnd: Int64? {
        Money.parse(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    var canSubmit: Bool {
        amountVnd != nil && categoryID != nil && walletID != nil
    }

    /// Keeps the field grouped while typing: `185000` becomes `185.000`.
    func amountDidChange() {
        let formatted = Money.formattedInput(amountText)
        if formatted != amountText { amountText = formatted }
    }

    func load(service: any LedgerService) async {
        do {
            accounts = try await service.accounts()
            categoryID = categoryID ?? categories.first?.id
            walletID = walletID ?? wallets.first?.id
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.userMessage
        }
    }

    /// Returns true once the transaction is saved.
    func submit(service: any LedgerService) async -> Bool {
        guard !isSubmitting, let amountVnd, let categoryID, let walletID else { return false }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let draft = TransactionDraft(
            flow: flow,
            amountVnd: amountVnd,
            categoryID: categoryID,
            walletID: walletID,
            note: note,
            occurredAt: occurredAt,
            idempotencyKey: idempotencyKey
        )

        do {
            switch mode {
            case .create: try await service.createTransaction(draft)
            case .edit(let item): try await service.replaceTransaction(id: item.id, with: draft)
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.userMessage
            return false
        }
    }
}
