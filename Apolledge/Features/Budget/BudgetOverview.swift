//
//  BudgetOverview.swift
//  Apolledge
//

import Foundation

/// Totals and pace of a month's budgets.
struct BudgetOverview: Equatable {
    /// Every expense of the month, including categories without a budget.
    let spentVnd: Int64
    let limitVnd: Int64
    /// Categories with a budget, largest usage first.
    let lines: [BudgetSummary]
    let daysLeft: Int
    /// Days ahead of (positive) or behind (negative) an even spend across the month.
    let paceDays: Int

    init(budgets: [BudgetSummary], month: LedgerMonth, now: Date) {
        let today = LedgerCalendar.calendar.component(.day, from: now)
        let dayCount = month.dayCount

        spentVnd = budgets.reduce(0) { $0 + $1.spentVnd }
        limitVnd = budgets.reduce(0) { $0 + ($1.limitVnd ?? 0) }
        lines = budgets
            .filter { $0.limitVnd != nil }
            .sorted { $0.usedFraction > $1.usedFraction }
        daysLeft = max(dayCount - today, 0)

        let spentDays = limitVnd > 0 ? Double(spentVnd) / Double(limitVnd) * Double(dayCount) : 0
        paceDays = Int((Double(today) - spentDays).rounded())
    }

    var usedFraction: Double {
        limitVnd > 0 ? Double(spentVnd) / Double(limitVnd) : 0
    }

    /// Design system voice: states the fact, never judges.
    var paceText: String {
        switch paceDays {
        case 0: "Bạn đang đi đúng nhịp tháng."
        case 1...: "Bạn đang đi chậm hơn nhịp tháng \(paceDays) ngày."
        default: "Bạn đang đi nhanh hơn nhịp tháng \(-paceDays) ngày."
        }
    }
}

extension BudgetSummary {
    var usedFraction: Double {
        guard let limitVnd, limitVnd > 0 else { return 0 }
        return Double(spentVnd) / Double(limitVnd)
    }

    var isOverBudget: Bool { (remainingVnd ?? 0) < 0 }

    var remainingText: String {
        let remaining = remainingVnd ?? 0
        return remaining < 0 ? "vượt \(Money.grouped(-remaining))" : "còn \(Money.grouped(remaining))"
    }
}
