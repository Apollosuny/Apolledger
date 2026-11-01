//
//  BudgetViewModel.swift
//  Apolledge
//

import Foundation
import Observation

@Observable
final class BudgetViewModel {
    private(set) var overview: BudgetOverview?
    /// Expense categories that have no budget this month yet.
    private(set) var availableCategories: [Account] = []
    private(set) var errorMessage: String?

    func load(month: LedgerMonth, service: any LedgerService, now: Date = .now) async {
        do {
            let accounts = try await service.accounts()
            let budgets = try await service.budgets(in: month)
            let budgeted = Set(budgets.filter { $0.limitVnd != nil }.map(\.accountId))

            overview = BudgetOverview(budgets: budgets, month: month, now: now)
            availableCategories = accounts.filter { $0.isActive && $0.type == .expense && !budgeted.contains($0.id) }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.userMessage
        }
    }
}
