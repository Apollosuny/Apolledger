//
//  RecurringViewModel.swift
//  Apolledge
//

import Foundation
import Observation

/// A standing order with what the screen shows about it.
struct RecurringItem: Identifiable, Equatable {
    let order: StandingOrder
    let flow: MoneyFlow?
    let meta: String
    /// Calendar day and month of the next run. Nil if the backend sent an unreadable date.
    let nextRun: (day: Int, month: Int)?
    let isDueSoon: Bool
    let isDue: Bool

    var id: String { order.id }

    static func == (lhs: RecurringItem, rhs: RecurringItem) -> Bool {
        lhs.order == rhs.order && lhs.meta == rhs.meta && lhs.isDueSoon == rhs.isDueSoon && lhs.isDue == rhs.isDue
    }

    init(_ order: StandingOrder, accounts: [String: Account], now: Date) {
        let debit = accounts[order.debitAccountId]
        let credit = accounts[order.creditAccountId]
        let category = [debit, credit].compactMap(\.self).first { $0.type == .expense || $0.type == .income }
        let wallet = [debit, credit].compactMap(\.self).first { $0.type == .asset || $0.type == .liability }
        let calendar = LedgerCalendar.calendar
        let parts = order.nextRunOn.split(separator: "-").compactMap { Int($0) }

        self.order = order
        switch category?.type {
        case .expense: flow = .expense
        case .income: flow = .income
        default: flow = nil
        }
        var labels = [category?.name, wallet?.name].compactMap(\.self)
        if order.isPaused {
            labels.append("tạm dừng")
        } else if order.autoPost {
            labels.append("tự động")
        }
        meta = labels.joined(separator: " · ")

        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            nextRun = nil
            isDueSoon = false
            isDue = false
            return
        }

        let daysAway = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day ?? 0
        nextRun = (parts[2], parts[1])
        isDueSoon = !order.isPaused && daysAway <= 7
        isDue = !order.isPaused && daysAway <= 0
    }
}

struct RecurringOverview: Equatable {
    let items: [RecurringItem]
    let monthlyExpenseVnd: Int64
    /// Share of recurring income taken by recurring spending; nil with no recurring income.
    let incomeShare: Int?
    let dueSoonExpenseCount: Int

    init(orders: [StandingOrder], accounts: [Account], now: Date) {
        let accountsByID = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        items = orders
            .map { RecurringItem($0, accounts: accountsByID, now: now) }
            .sorted { ($0.order.isPaused ? 1 : 0, $0.order.nextRunOn) < ($1.order.isPaused ? 1 : 0, $1.order.nextRunOn) }

        let active = items.filter { !$0.order.isPaused }
        let expense = active.filter { $0.flow == .expense }.reduce(Int64(0)) { $0 + $1.order.amountVnd }
        let income = active.filter { $0.flow == .income }.reduce(Int64(0)) { $0 + $1.order.amountVnd }

        monthlyExpenseVnd = expense
        incomeShare = income > 0 ? Int((Double(expense) / Double(income) * 100).rounded()) : nil
        dueSoonExpenseCount = active.filter { $0.flow == .expense && $0.isDueSoon }.count
    }

    var detailText: String {
        var parts: [String] = []
        if let incomeShare { parts.append("Chiếm \(incomeShare)% thu nhập.") }
        if dueSoonExpenseCount > 0 { parts.append("\(dueSoonExpenseCount) khoản sắp trừ trong 7 ngày.") }
        return parts.joined(separator: " ")
    }
}

@Observable
final class RecurringViewModel {
    private(set) var overview: RecurringOverview?
    private(set) var accounts: [Account] = []
    private(set) var errorMessage: String?

    func load(service: any LedgerService, now: Date = .now) async {
        do {
            let accounts = try await service.accounts()
            let orders = try await service.standingOrders()
            self.accounts = accounts
            overview = RecurringOverview(orders: orders, accounts: accounts, now: now)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.userMessage
        }
    }

    /// Returns true when the change went through and the data should be reloaded.
    func perform(_ operation: () async throws -> Void) async -> Bool {
        do {
            try await operation()
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.userMessage
            return false
        }
    }
}
