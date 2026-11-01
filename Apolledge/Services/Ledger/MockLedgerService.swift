//
//  MockLedgerService.swift
//  Apolledge
//

import Foundation

/// In-memory data for SwiftUI previews. The live app always uses `RemoteLedgerService`.
struct MockLedgerService: LedgerService {
    private static let wallet = Account(id: "wallet", type: .asset, name: "Tiền mặt", icon: "payments")
    private static let food = Account(id: "food", type: .expense, name: "Ăn uống", icon: "restaurant")
    private static let travel = Account(id: "travel", type: .expense, name: "Đi lại", icon: "directions_car")
    private static let salary = Account(id: "salary", type: .income, name: "Lương", icon: "payments")

    func accounts() async throws -> [Account] {
        [Self.wallet, Self.food, Self.travel, Self.salary]
    }

    func transactions(in month: LedgerMonth) async throws -> [LedgerTransaction] {
        [
            Self.transaction(id: "1", note: "Cà phê sáng", debit: "food", credit: "wallet", amount: 45_000),
            Self.transaction(id: "2", note: "Grab về nhà", debit: "travel", credit: "wallet", amount: 78_000),
            Self.transaction(id: "3", note: nil, debit: "wallet", credit: "salary", amount: 22_000_000),
        ]
    }

    func createTransaction(_ draft: TransactionDraft) async throws {}
    func replaceTransaction(id: String, with draft: TransactionDraft) async throws {}
    func reverseTransaction(id: String) async throws {}

    func budgets(in month: LedgerMonth) async throws -> [BudgetSummary] {
        [
            BudgetSummary(accountId: "food", name: "Ăn uống", icon: "restaurant", spentVnd: 2_640_000, limitVnd: 3_880_000, remainingVnd: 1_240_000),
            BudgetSummary(accountId: "travel", name: "Đi lại", icon: "directions_car", spentVnd: 1_180_000, limitVnd: 1_000_000, remainingVnd: -180_000),
        ]
    }

    func setBudget(accountID: String, month: LedgerMonth, limitVnd: Int64) async throws {}
    func deleteBudget(accountID: String, month: LedgerMonth) async throws {}

    func standingOrders() async throws -> [StandingOrder] {
        [
            StandingOrder(
                id: "rent", name: "Tiền thuê nhà", amountVnd: 4_000_000, debitAccountId: "food", creditAccountId: "wallet",
                dayOfMonth: 15, nextRunOn: "2026-11-15", autoPost: true, pausedAt: nil
            ),
        ]
    }

    func createStandingOrder(_ draft: StandingOrderDraft) async throws {}
    func setStandingOrderPaused(id: String, paused: Bool) async throws {}
    func postStandingOrder(id: String) async throws {}

    private static func transaction(id: String, note: String?, debit: String, credit: String, amount: Int64) -> LedgerTransaction {
        LedgerTransaction(
            id: id,
            occurredAt: .now,
            note: note,
            source: "MANUAL",
            entries: [
                LedgerEntry(accountId: debit, direction: .debit, amountVnd: amount),
                LedgerEntry(accountId: credit, direction: .credit, amountVnd: amount),
            ]
        )
    }
}
