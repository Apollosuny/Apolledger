//
//  ReportsViewModel.swift
//  Apolledge
//

import Foundation
import Observation

enum ReportRange: Hashable {
    case sixMonths
    case oneYear

    var monthCount: Int { self == .sixMonths ? 6 : 12 }
}

/// Spending per month and the latest month by category.
struct SpendingReport: Equatable {
    struct Month: Identifiable, Equatable {
        let month: LedgerMonth
        let spentVnd: Int64
        var id: LedgerMonth { month }
    }

    struct Category: Identifiable, Equatable {
        let id: String
        let name: String
        let icon: String?
        let spentVnd: Int64
        let share: Double
    }

    let months: [Month]
    let categories: [Category]

    /// `budgetsByMonth` runs oldest to newest; the last month supplies the category breakdown.
    init(budgetsByMonth: [(month: LedgerMonth, budgets: [BudgetSummary])]) {
        months = budgetsByMonth.map { entry in
            Month(month: entry.month, spentVnd: entry.budgets.reduce(0) { $0 + $1.spentVnd })
        }

        let latestBudgets: [BudgetSummary] = budgetsByMonth.last.map(\.budgets) ?? []
        let latest = latestBudgets.filter { $0.spentVnd > 0 }
        let total = latest.reduce(Int64(0)) { $0 + $1.spentVnd }
        categories = latest
            .sorted { $0.spentVnd > $1.spentVnd }
            .map { line in
                Category(
                    id: line.accountId,
                    name: line.name,
                    icon: line.icon,
                    spentVnd: line.spentVnd,
                    share: total > 0 ? Double(line.spentVnd) / Double(total) : 0
                )
            }
    }

    var currentMonth: Month? { months.last }

    /// Averages only months with spending, so a new user's empty history does not dilute the figure.
    var averageVnd: Int64 {
        let active = months.filter { $0.spentVnd > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + $1.spentVnd } / Int64(active.count)
    }

    var peakVnd: Int64 { months.map(\.spentVnd).max() ?? 0 }
}

@Observable
final class ReportsViewModel {
    private(set) var report: SpendingReport?
    private(set) var errorMessage: String?

    func load(range: ReportRange, service: any LedgerService, now: Date = .now) async {
        let months = LedgerMonth(containing: now).trailing(range.monthCount)
        // The budget summary already nets spending per category for a month, so reports need no endpoint of their own.
        let requests = months.map { month in
            Task { try await service.budgets(in: month) }
        }

        do {
            var results: [(month: LedgerMonth, budgets: [BudgetSummary])] = []
            for (month, request) in zip(months, requests) {
                results.append((month, try await request.value))
            }
            report = SpendingReport(budgetsByMonth: results)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.userMessage
        }
    }
}
