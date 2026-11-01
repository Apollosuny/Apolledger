//
//  LedgerViewModel.swift
//  Apolledge
//

import Foundation
import Observation

@Observable
final class LedgerViewModel {
    var searchText = ""
    private(set) var summary = MonthSummary.empty
    private(set) var budgetLimitVnd: Int64 = 0
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    /// Days narrowed to the search, matching note, category and wallet without regard to case or diacritics.
    var visibleDays: [LedgerDay] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return summary.days }

        return summary.days.compactMap { day in
            let items = day.items.filter {
                $0.title.localizedStandardContains(query) || $0.meta.localizedStandardContains(query)
            }
            return items.isEmpty ? nil : LedgerDay(id: day.id, label: day.label, netVnd: day.netVnd, items: items)
        }
    }

    func load(month: LedgerMonth, service: any LedgerService, now: Date = .now) async {
        do {
            let accounts = try await service.accounts()
            let transactions = try await service.transactions(in: month)
            let budgets = try await service.budgets(in: month)

            let accountsByID = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            summary = MonthSummary(items: transactions.map { LedgerItem($0, accounts: accountsByID) }, now: now)
            budgetLimitVnd = budgets.reduce(0) { $0 + ($1.limitVnd ?? 0) }
            errorMessage = nil
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.userMessage
            hasLoaded = true
        }
    }
}
