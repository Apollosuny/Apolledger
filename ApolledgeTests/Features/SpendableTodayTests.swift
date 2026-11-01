//
//  SpendableTodayTests.swift
//  ApolledgeTests
//

import Foundation
import Testing
@testable import Apolledge

@MainActor
struct SpendableTodayTests {
    /// 12 Aug 2026, 10:00 in Vietnam. August has 31 days, so 20 days remain, today included.
    private let now = Date(timeIntervalSince1970: 1_786_503_600)

    private let accounts: [String: Account] = [
        "cash": Account(id: "cash", type: .asset, name: "Tiền mặt", icon: nil),
        "rent": Account(id: "rent", type: .expense, name: "Nhà cửa", icon: nil),
        "salary": Account(id: "salary", type: .income, name: "Lương", icon: nil),
    ]

    private func expense(_ amount: Int64, on date: String, paused: Bool = false) -> RecurringItem {
        item(debit: "rent", credit: "cash", amount: amount, next: date, paused: paused)
    }

    private func income(_ amount: Int64, on date: String) -> RecurringItem {
        item(debit: "cash", credit: "salary", amount: amount, next: date, paused: false)
    }

    private func item(debit: String, credit: String, amount: Int64, next: String, paused: Bool) -> RecurringItem {
        RecurringItem(
            StandingOrder(
                id: UUID().uuidString, name: "x", amountVnd: amount, debitAccountId: debit, creditAccountId: credit,
                dayOfMonth: 1, nextRunOn: next, autoPost: true, pausedAt: paused ? now : nil
            ),
            accounts: accounts,
            now: now
        )
    }

    @Test func sharesTheBalanceOverTheRestOfTheMonthWithoutSalary() {
        let result = SpendableToday(walletBalanceVnd: 2_000_000, todaySpentVnd: 0, orders: [], now: now)

        #expect(result.days == 20)
        #expect(result.horizon == .monthEnd)
        #expect(result.todayVnd == 100_000)
    }

    @Test func runsUntilSalaryAndHoldsBackOrdersDueBeforeIt() {
        let result = SpendableToday(
            walletBalanceVnd: 5_000_000,
            todaySpentVnd: 0,
            orders: [
                income(22_000_000, on: "2026-08-22"),
                expense(3_000_000, on: "2026-08-20"),
                expense(1_000_000, on: "2026-08-22"),
            ],
            now: now
        )

        #expect(result.days == 10)
        #expect(result.horizon == .income)
        #expect(result.upcomingVnd == 3_000_000)
        #expect(result.todayVnd == 200_000)
    }

    @Test func pausedOrdersAndUnreceivedIncomeDoNotCount() {
        let result = SpendableToday(
            walletBalanceVnd: 2_000_000,
            todaySpentVnd: 0,
            orders: [expense(1_000_000, on: "2026-08-20", paused: true)],
            now: now
        )

        #expect(result.upcomingVnd == 0)
        #expect(result.todayVnd == 100_000)
    }

    @Test func todaysSpendingLowersTodayOneForOne() {
        // The morning held 1.940.000, or 97.000 a day over 20 days.
        let result = SpendableToday(walletBalanceVnd: 1_900_000, todaySpentVnd: 40_000, orders: [], now: now)

        #expect(result.todayVnd == 57_000)
        #expect(result.tomorrowVnd == 100_000)
    }

    @Test func overspendingShowsTheExcessAndTheLowerTomorrow() {
        let result = SpendableToday(walletBalanceVnd: 1_750_000, todaySpentVnd: 250_000, orders: [], now: now)

        #expect(result.todayVnd == -150_000)
        #expect(result.statusText == "Hôm nay đã quá 150.000 ₫.")
        #expect(result.tomorrowVnd == 92_105)
    }

    @Test func committedOrdersAboveTheBalanceAreAShortfallNotANegativeAllowance() {
        let result = SpendableToday(
            walletBalanceVnd: 1_000_000,
            todaySpentVnd: 0,
            orders: [expense(1_500_000, on: "2026-08-20")],
            now: now
        )

        #expect(result.todayVnd == 0)
        #expect(result.tomorrowVnd == 0)
        #expect(result.shortfallVnd == 500_000)
        #expect(result.statusText == "Thiếu 500.000 ₫ cho các khoản sắp trừ.")
    }

    @Test func lastDayHasNoTomorrow() {
        let lastDay = now.addingTimeInterval(19 * 86_400)

        let result = SpendableToday(walletBalanceVnd: 300_000, todaySpentVnd: 0, orders: [], now: lastDay)

        #expect(result.days == 1)
        #expect(result.todayVnd == 300_000)
        #expect(result.tomorrowVnd == nil)
        #expect(result.statusText == "Hôm nay là ngày cuối tháng.")
    }

    @Test func emptyWalletAsksForTheBalance() {
        let result = SpendableToday(walletBalanceVnd: -85_000, todaySpentVnd: 85_000, orders: [], now: now)

        #expect(result.needsWalletBalance)
    }

    @Test func correctionPostsTheDifferenceInTheRightDirection() throws {
        let raise = try #require(WalletBalanceCorrection.draft(
            currentVnd: -85_000, targetVnd: 2_000_000, walletID: "cash", offsetAccountID: "opening",
            idempotencyKey: "k", now: now
        ))
        let lower = try #require(WalletBalanceCorrection.draft(
            currentVnd: 500_000, targetVnd: 300_000, walletID: "cash", offsetAccountID: "opening",
            idempotencyKey: "k", now: now
        ))

        #expect(raise.flow == .income)
        #expect(raise.amountVnd == 2_085_000)
        #expect(lower.flow == .expense)
        #expect(lower.amountVnd == 200_000)
        #expect(WalletBalanceCorrection.draft(
            currentVnd: 1, targetVnd: 1, walletID: "cash", offsetAccountID: "opening", idempotencyKey: "k", now: now
        ) == nil)
    }

    @Test func correctionIsNeitherIncomeNorSpendingInTheLedger() {
        let opening = Account(id: "opening", type: .equity, name: "Số dư đầu kỳ", icon: nil)
        let transaction = LedgerTransaction(
            id: "1", occurredAt: now, note: "Điều chỉnh số dư", source: "MANUAL",
            entries: [
                LedgerEntry(accountId: "cash", direction: .debit, amountVnd: 2_000_000),
                LedgerEntry(accountId: "opening", direction: .credit, amountVnd: 2_000_000),
            ]
        )

        var all = accounts
        all["opening"] = opening
        let item = LedgerItem(transaction, accounts: all)
        let summary = MonthSummary(items: [item], now: now)

        #expect(item.flow == nil)
        #expect(item.title == "Điều chỉnh số dư")
        #expect(item.amountVnd == 2_000_000)
        #expect(summary.incomeVnd == 0)
        #expect(summary.expenseVnd == 0)
    }
}
