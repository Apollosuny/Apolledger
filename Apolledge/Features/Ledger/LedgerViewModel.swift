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
    /// Only for the current month: the figure looks forward, which means nothing for a past month.
    private(set) var spendable: SpendableToday?
    private(set) var wallets: [WalletBalance] = []
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
            let items = transactions.map { LedgerItem($0, accounts: accountsByID) }
            let isCurrentMonth = month == LedgerMonth(containing: now)
            let orders = isCurrentMonth ? try await service.standingOrders() : []
            var wallets: [WalletBalance] = []
            if isCurrentMonth {
                for wallet in accounts where wallet.isActive && wallet.type == .asset {
                    wallets.append(WalletBalance(account: wallet, balanceVnd: try await service.balance(accountID: wallet.id)))
                }
            }

            summary = MonthSummary(items: items, now: now)
            budgetLimitVnd = budgets.reduce(0) { $0 + ($1.limitVnd ?? 0) }
            self.wallets = wallets
            spendable = isCurrentMonth
                ? SpendableToday(
                    walletBalanceVnd: wallets.reduce(0) { $0 + $1.balanceVnd },
                    todaySpentVnd: SpendableToday.spentToday(items, now: now),
                    orders: RecurringOverview(orders: orders, accounts: accounts, now: now).items,
                    now: now
                )
                : nil
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
