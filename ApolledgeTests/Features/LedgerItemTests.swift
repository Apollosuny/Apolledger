//
//  LedgerItemTests.swift
//  ApolledgeTests
//

import Foundation
import Testing
@testable import Apolledge

@MainActor
struct LedgerItemTests {
    private let accounts: [String: Account] = [
        "cash": Account(id: "cash", type: .asset, name: "Tiền mặt", icon: "payments"),
        "bank": Account(id: "bank", type: .asset, name: "Ngân hàng", icon: "payments"),
        "food": Account(id: "food", type: .expense, name: "Ăn uống", icon: "restaurant"),
        "salary": Account(id: "salary", type: .income, name: "Lương", icon: "payments"),
    ]

    /// 12 Aug 2026, 10:00 in Vietnam.
    private let now = Date(timeIntervalSince1970: 1786503600)

    private func transaction(
        _ id: String,
        debit: String,
        credit: String,
        amount: Int64,
        at date: Date,
        note: String? = nil
    ) -> LedgerTransaction {
        LedgerTransaction(
            id: id,
            occurredAt: date,
            note: note,
            source: "MANUAL",
            entries: [
                LedgerEntry(accountId: debit, direction: .debit, amountVnd: amount),
                LedgerEntry(accountId: credit, direction: .credit, amountVnd: amount),
            ]
        )
    }

    @Test func classifiesFlowFromTheCategoryAccount() {
        let expense = LedgerItem(transaction("1", debit: "food", credit: "cash", amount: 50_000, at: now), accounts: accounts)
        let income = LedgerItem(transaction("2", debit: "cash", credit: "salary", amount: 90_000, at: now), accounts: accounts)

        #expect(expense.flow == .expense)
        #expect(expense.amountVnd == 50_000)
        #expect(expense.meta == "Ăn uống · Tiền mặt")
        #expect(income.flow == .income)
        #expect(income.amountVnd == 90_000)
    }

    @Test func transferIsNeitherIncomeNorSpending() {
        let transfer = LedgerItem(transaction("1", debit: "bank", credit: "cash", amount: 70_000, at: now), accounts: accounts)
        let summary = MonthSummary(items: [transfer], now: now)

        #expect(transfer.flow == nil)
        #expect(transfer.title == "Chuyển tiền")
        #expect(summary.incomeVnd == 0)
        #expect(summary.expenseVnd == 0)
    }

    @Test func titlePrefersTheNote() {
        let noted = LedgerItem(transaction("1", debit: "food", credit: "cash", amount: 1, at: now, note: "Phở"), accounts: accounts)
        let blank = LedgerItem(transaction("2", debit: "food", credit: "cash", amount: 1, at: now, note: ""), accounts: accounts)

        #expect(noted.title == "Phở")
        #expect(blank.title == "Ăn uống")
    }

    /// 00:30 in Vietnam is still the previous day in UTC; grouping must follow the Vietnamese day.
    @Test func groupsByVietnameseDayNewestFirst() {
        let afterMidnight = Date(timeIntervalSince1970: 1786469400) // 12 Aug 00:30 +07
        let beforeMidnight = Date(timeIntervalSince1970: 1786465800) // 11 Aug 23:30 +07
        let items = [
            LedgerItem(transaction("1", debit: "food", credit: "cash", amount: 30_000, at: afterMidnight), accounts: accounts),
            LedgerItem(transaction("2", debit: "cash", credit: "salary", amount: 100_000, at: beforeMidnight), accounts: accounts),
        ]

        let summary = MonthSummary(items: items, now: now)

        #expect(summary.days.map(\.label) == ["Hôm nay · 12 tháng 8", "Hôm qua · 11 tháng 8"])
        #expect(summary.days.map(\.netVnd) == [-30_000, 100_000])
    }

    @Test func heroFigureFallsBackToNetWithoutABudget() {
        let items = [
            LedgerItem(transaction("1", debit: "food", credit: "cash", amount: 30_000, at: now), accounts: accounts),
            LedgerItem(transaction("2", debit: "cash", credit: "salary", amount: 100_000, at: now), accounts: accounts),
        ]
        let summary = MonthSummary(items: items, now: now)

        #expect(summary.remaining(budgetLimitVnd: 0).label == "Chênh lệch")
        #expect(summary.remaining(budgetLimitVnd: 0).amountVnd == 70_000)
        #expect(summary.remaining(budgetLimitVnd: 50_000).label == "Còn lại")
        #expect(summary.remaining(budgetLimitVnd: 50_000).amountVnd == 20_000)
    }
}
