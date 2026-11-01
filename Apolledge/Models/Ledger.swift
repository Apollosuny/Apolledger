//
//  Ledger.swift
//  Apolledge
//
//  Wire types for the ledger API. The backend owns the double-entry rules; these stay plain data.
//

import Foundation

enum AccountType: String, Codable {
    case asset = "ASSET"
    case liability = "LIABILITY"
    case income = "INCOME"
    case expense = "EXPENSE"
    case equity = "EQUITY"
}

/// A wallet (`asset`), a category (`expense`, `income`), or the offset of balance corrections (`equity`).
struct Account: Decodable, Identifiable, Hashable {
    let id: String
    let type: AccountType
    let name: String
    let icon: String?
    var archivedAt: Date? = nil

    /// Archived accounts still label old transactions but cannot receive new ones.
    var isActive: Bool { archivedAt == nil }
}

enum EntryDirection: String, Codable {
    case debit = "DEBIT"
    case credit = "CREDIT"
}

struct LedgerEntry: Decodable, Hashable {
    let accountId: String
    let direction: EntryDirection
    let amountVnd: Int64
}

struct LedgerTransaction: Decodable, Identifiable, Hashable {
    let id: String
    let occurredAt: Date
    let note: String?
    let source: String
    let entries: [LedgerEntry]

    var isFromStandingOrder: Bool { source == "STANDING_ORDER" }
}

struct BudgetSummary: Decodable, Identifiable, Hashable {
    let accountId: String
    let name: String
    let icon: String?
    let spentVnd: Int64
    let limitVnd: Int64?
    let remainingVnd: Int64?

    var id: String { accountId }
}

struct StandingOrder: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let amountVnd: Int64
    let debitAccountId: String
    let creditAccountId: String
    let dayOfMonth: Int
    /// `yyyy-MM-dd` in the ledger's calendar.
    let nextRunOn: String
    let autoPost: Bool
    let pausedAt: Date?

    var isPaused: Bool { pausedAt != nil }
}

/// The subset of Spring's `Page` the client needs.
struct PageResponse<Item: Decodable>: Decodable {
    let content: [Item]
    let last: Bool
}

enum MoneyFlow: Hashable {
    case expense
    case income
}

struct TransactionDraft: Equatable {
    var flow: MoneyFlow
    var amountVnd: Int64
    var categoryID: String
    var walletID: String
    var note: String
    var occurredAt: Date
    /// Stays the same across retries of one submission so a lost response cannot post it twice.
    var idempotencyKey: String
}

struct StandingOrderDraft: Equatable {
    var name: String
    var flow: MoneyFlow
    var amountVnd: Int64
    var categoryID: String
    var walletID: String
    var dayOfMonth: Int
    var autoPost: Bool
}

/// Money leaves a wallet into an expense category, or enters a wallet from an income category.
func doubleEntryAccounts(flow: MoneyFlow, categoryID: String, walletID: String) -> (debit: String, credit: String) {
    switch flow {
    case .expense: (debit: categoryID, credit: walletID)
    case .income: (debit: walletID, credit: categoryID)
    }
}
