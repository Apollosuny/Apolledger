//
//  SpendableToday.swift
//  Apolledge
//

import Foundation

/// How much can go out today without running short before the next money comes in.
///
/// Money not yet received never counts: the figure runs up to the next salary (or the month's end when
/// no income is scheduled), and only spending already committed by standing orders is held back.
struct SpendableToday: Equatable {
    enum Horizon: Equatable {
        case income
        case monthEnd
    }

    let walletBalanceVnd: Int64
    let upcomingVnd: Int64
    /// Days to share the money over, today included.
    let days: Int
    let horizon: Horizon
    /// Today's allowance minus what today already spent. Negative once today is over.
    let todayVnd: Int64
    /// Nil on the last day of the period.
    let tomorrowVnd: Int64?
    /// What the wallets lack to cover standing orders; zero when they can.
    let shortfallVnd: Int64

    init(walletBalanceVnd: Int64, todaySpentVnd: Int64, orders: [RecurringItem], now: Date) {
        let calendar = LedgerCalendar.calendar
        let today = calendar.startOfDay(for: now)
        let active = orders.filter { !$0.order.isPaused }

        let nextIncome = active
            .filter { $0.flow == .income }
            .compactMap(\.nextRunDate)
            .filter { $0 > today }
            .min()
        let nextMonth = LedgerMonth(containing: now).adding(months: 1).start
        let end = nextIncome.map { min($0, nextMonth) } ?? nextMonth

        let upcoming = active
            .filter { item in item.flow == .expense && item.nextRunDate.map { $0 < end } == true }
            .reduce(Int64(0)) { $0 + $1.order.amountVnd }
        let days = max(calendar.dateComponents([.day], from: today, to: end).day ?? 1, 1)

        // Today's allowance is fixed from the morning's position, so spending lowers it one for one
        // instead of being spread across the remaining days.
        let morningPool = walletBalanceVnd + todaySpentVnd - upcoming
        let tonightPool = walletBalanceVnd - upcoming

        self.walletBalanceVnd = walletBalanceVnd
        self.upcomingVnd = upcoming
        self.days = days
        self.horizon = nextIncome == end ? .income : .monthEnd
        self.todayVnd = max(morningPool, 0) / Int64(days) - todaySpentVnd
        self.tomorrowVnd = days > 1 ? max(tonightPool, 0) / Int64(days - 1) : nil
        self.shortfallVnd = max(-tonightPool, 0)
    }

    static func spentToday(_ items: [LedgerItem], now: Date) -> Int64 {
        items
            .filter { $0.flow == .expense && LedgerCalendar.calendar.isDate($0.transaction.occurredAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.amountVnd }
    }

    /// With nothing in the wallets the figure says nothing yet: most likely the opening balance was never entered.
    var needsWalletBalance: Bool { walletBalanceVnd <= 0 }

    /// Design system voice: states the fact, never judges.
    var statusText: String {
        if shortfallVnd > 0 {
            return "Thiếu \(Money.vnd(shortfallVnd)) cho các khoản sắp trừ."
        }
        if todayVnd < 0 {
            return "Hôm nay đã quá \(Money.vnd(-todayVnd))."
        }
        if let tomorrowVnd {
            return "Ngày mai còn \(Money.vnd(tomorrowVnd))."
        }
        return horizon == .income ? "Hôm nay là ngày cuối trước kỳ lương." : "Hôm nay là ngày cuối tháng."
    }

    var basisText: String {
        let period = horizon == .income ? "\(days) ngày đến kỳ lương" : "\(days) ngày đến cuối tháng"
        return upcomingVnd > 0
            ? "số dư \(Money.grouped(walletBalanceVnd)) · sắp trừ \(Money.grouped(upcomingVnd)) · \(period)"
            : "số dư \(Money.grouped(walletBalanceVnd)) · \(period)"
    }
}
