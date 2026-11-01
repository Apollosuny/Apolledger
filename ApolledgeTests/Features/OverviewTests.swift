//
//  OverviewTests.swift
//  ApolledgeTests
//

import Foundation
import Testing
@testable import Apolledge

@MainActor
struct OverviewTests {
    private let august = LedgerMonth(year: 2026, month: 8)
    /// 12 Aug 2026, 10:00 in Vietnam.
    private let now = Date(timeIntervalSince1970: 1786503600)

    private func budget(_ id: String, spent: Int64, limit: Int64?) -> BudgetSummary {
        BudgetSummary(
            accountId: id, name: id, icon: nil, spentVnd: spent, limitVnd: limit,
            remainingVnd: limit.map { $0 - spent }
        )
    }

    @Test func budgetPaceComparesSpendingWithTheCalendar() {
        // 31-day month, a third spent by day 12: about 10 days' worth of spending.
        let slow = BudgetOverview(budgets: [budget("a", spent: 3_100_000, limit: 9_300_000)], month: august, now: now)
        let fast = BudgetOverview(budgets: [budget("a", spent: 6_200_000, limit: 9_300_000)], month: august, now: now)

        #expect(slow.daysLeft == 19)
        #expect(slow.paceText == "Bạn đang đi chậm hơn nhịp tháng 2 ngày.")
        #expect(fast.paceText == "Bạn đang đi nhanh hơn nhịp tháng 9 ngày.")
    }

    @Test func budgetLinesSkipCategoriesWithoutALimitButCountTheirSpending() {
        let overview = BudgetOverview(
            budgets: [budget("low", spent: 10, limit: 100), budget("over", spent: 150, limit: 100), budget("none", spent: 40, limit: nil)],
            month: august,
            now: now
        )

        #expect(overview.spentVnd == 200)
        #expect(overview.lines.map(\.accountId) == ["over", "low"])
        #expect(overview.lines[0].isOverBudget)
        #expect(overview.lines[0].remainingText == "vượt 50")
    }

    @Test func reportAveragesOnlyMonthsWithSpendingAndBreaksDownTheLatest() {
        let months = august.trailing(3)
        let report = SpendingReport(budgetsByMonth: [
            (months[0], []),
            (months[1], [budget("a", spent: 100, limit: nil)]),
            (months[2], [budget("a", spent: 75, limit: nil), budget("b", spent: 225, limit: 100), budget("c", spent: 0, limit: 50)]),
        ])

        #expect(report.averageVnd == 200)
        #expect(report.peakVnd == 300)
        #expect(report.categories.map(\.id) == ["b", "a"])
        #expect(report.categories.first?.share == 0.75)
    }

    private func order(_ id: String, debit: String, credit: String, amount: Int64, next: String, paused: Bool = false) -> StandingOrder {
        StandingOrder(
            id: id, name: id, amountVnd: amount, debitAccountId: debit, creditAccountId: credit,
            dayOfMonth: 1, nextRunOn: next, autoPost: true, pausedAt: paused ? now : nil
        )
    }

    @Test func recurringOverviewSharesIncomeAndIgnoresPausedOrders() {
        let accounts = [
            Account(id: "cash", type: .asset, name: "Tiền mặt", icon: nil),
            Account(id: "rent", type: .expense, name: "Nhà cửa", icon: nil),
            Account(id: "salary", type: .income, name: "Lương", icon: nil),
        ]
        let overview = RecurringOverview(
            orders: [
                order("later", debit: "rent", credit: "cash", amount: 3_000_000, next: "2026-08-30"),
                order("soon", debit: "rent", credit: "cash", amount: 2_000_000, next: "2026-08-15"),
                order("paused", debit: "rent", credit: "cash", amount: 9_000_000, next: "2026-08-13", paused: true),
                order("pay", debit: "cash", credit: "salary", amount: 20_000_000, next: "2026-08-25"),
            ],
            accounts: accounts,
            now: now
        )

        #expect(overview.monthlyExpenseVnd == 5_000_000)
        #expect(overview.items.map(\.id) == ["soon", "pay", "later", "paused"])
        #expect(overview.detailText == "Chiếm 25% thu nhập. 1 khoản sắp trừ trong 7 ngày.")
        #expect(overview.items[0].isDueSoon)
        #expect(overview.items[0].isDue == false)
    }
}
