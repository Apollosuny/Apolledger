//
//  LedgerItem.swift
//  Apolledge
//

import Foundation

/// A transaction as the user thinks of it, derived from its double-entry lines.
struct LedgerItem: Identifiable, Hashable {
    let transaction: LedgerTransaction
    /// Nil for a transfer between wallets, which is neither income nor spending.
    let flow: MoneyFlow?
    let amountVnd: Int64
    let category: Account?
    let wallet: Account?

    var id: String { transaction.id }
    var note: String? { transaction.note?.isEmpty == false ? transaction.note : nil }
    var title: String { note ?? category?.name ?? "Chuyển tiền" }
    var meta: String { [category?.name, wallet?.name].compactMap(\.self).joined(separator: " · ") }
    var iconName: String { LedgerIcon.symbol(for: category?.icon) }

    init(_ transaction: LedgerTransaction, accounts: [String: Account]) {
        let lines = transaction.entries.map { (entry: $0, account: accounts[$0.accountId]) }
        let categoryLines = lines.filter { $0.account?.type == .expense || $0.account?.type == .income }

        self.transaction = transaction
        self.category = categoryLines.first?.account
        self.wallet = lines.first { $0.account?.type == .asset || $0.account?.type == .liability }?.account

        switch category?.type {
        case .expense: flow = .expense
        case .income: flow = .income
        default: flow = nil
        }

        // A transaction can split across categories, so its size is what they add up to.
        let measured = categoryLines.isEmpty
            ? lines.filter { $0.entry.direction == .debit }
            : categoryLines
        let net = measured.reduce(Int64(0)) { total, line in
            total + (line.entry.direction == .debit ? line.entry.amountVnd : -line.entry.amountVnd)
        }
        self.amountVnd = net.magnitude > Int64.max ? Int64.max : Int64(net.magnitude)
    }
}

struct LedgerDay: Identifiable, Equatable {
    let id: Date
    let label: String
    let netVnd: Int64
    let items: [LedgerItem]
}

/// Totals and day sections of one month in the ledger.
struct MonthSummary: Equatable {
    let incomeVnd: Int64
    let expenseVnd: Int64
    let days: [LedgerDay]

    static let empty = MonthSummary(items: [], now: .now)

    /// `items` keep their given order within a day; days run newest first.
    init(items: [LedgerItem], now: Date) {
        let calendar = LedgerCalendar.calendar
        let byDay = Dictionary(grouping: items) { calendar.startOfDay(for: $0.transaction.occurredAt) }

        incomeVnd = items.filter { $0.flow == .income }.reduce(0) { $0 + $1.amountVnd }
        expenseVnd = items.filter { $0.flow == .expense }.reduce(0) { $0 + $1.amountVnd }
        days = byDay.keys.sorted(by: >).map { day in
            let dayItems = byDay[day] ?? []
            let net = dayItems.reduce(Int64(0)) { total, item in
                switch item.flow {
                case .income: total + item.amountVnd
                case .expense: total - item.amountVnd
                case nil: total
                }
            }
            return LedgerDay(id: day, label: LedgerDateFormat.sectionLabel(day, now: now), netVnd: net, items: dayItems)
        }
    }

    /// Hero figure of the ledger: what is left of the month's budget or, with no budget set, income minus spending.
    func remaining(budgetLimitVnd: Int64) -> (label: String, amountVnd: Int64) {
        budgetLimitVnd > 0
            ? ("Còn lại", budgetLimitVnd - expenseVnd)
            : ("Chênh lệch", incomeVnd - expenseVnd)
    }
}
