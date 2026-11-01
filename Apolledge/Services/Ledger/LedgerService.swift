//
//  LedgerService.swift
//  Apolledge
//

import SwiftUI

protocol LedgerService {
    /// Includes archived accounts, because old transactions still need their names.
    func accounts() async throws -> [Account]

    /// Everything still on the books for the month: reversed transactions and their reversals are excluded.
    func transactions(in month: LedgerMonth) async throws -> [LedgerTransaction]
    func createTransaction(_ draft: TransactionDraft) async throws
    /// Edits by reversing the original and posting the draft, atomically on the server.
    func replaceTransaction(id: String, with draft: TransactionDraft) async throws
    /// "Delete" on an append-only ledger.
    func reverseTransaction(id: String) async throws

    func budgets(in month: LedgerMonth) async throws -> [BudgetSummary]
    func setBudget(accountID: String, month: LedgerMonth, limitVnd: Int64) async throws
    func deleteBudget(accountID: String, month: LedgerMonth) async throws

    func standingOrders() async throws -> [StandingOrder]
    func createStandingOrder(_ draft: StandingOrderDraft) async throws
    func setStandingOrderPaused(id: String, paused: Bool) async throws
    /// Posts an occurrence that is due. Fails while the order is paused or not due yet.
    func postStandingOrder(id: String) async throws
}

extension EnvironmentValues {
    @Entry var ledgerService: any LedgerService = MockLedgerService()
}
