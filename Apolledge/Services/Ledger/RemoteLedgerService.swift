//
//  RemoteLedgerService.swift
//  Apolledge
//

import Foundation

/// `client` must carry the token provider: every ledger endpoint is authenticated.
struct RemoteLedgerService: LedgerService {
    let client: APIClient

    /// Large enough that a month is normally one request. The cap only guards against a server that never reports `last`.
    private static let pageSize = 200
    private static let maximumPages = 50

    func accounts() async throws -> [Account] {
        try await client.send(Endpoint(
            method: .get,
            path: "accounts",
            query: [URLQueryItem(name: "includeArchived", value: "true")]
        ))
    }

    func transactions(in month: LedgerMonth) async throws -> [LedgerTransaction] {
        var transactions: [LedgerTransaction] = []

        for page in 0..<Self.maximumPages {
            let response: PageResponse<LedgerTransaction> = try await client.send(Endpoint(
                method: .get,
                path: "transactions",
                query: [
                    URLQueryItem(name: "from", value: month.start.ISO8601Format()),
                    URLQueryItem(name: "to", value: month.adding(months: 1).start.ISO8601Format()),
                    URLQueryItem(name: "activeOnly", value: "true"),
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(Self.pageSize)),
                    URLQueryItem(name: "sort", value: "occurredAt,desc"),
                ]
            ))
            transactions += response.content
            if response.last { break }
        }
        return transactions
    }

    func createTransaction(_ draft: TransactionDraft) async throws {
        let _: EmptyBody = try await client.send(Endpoint(
            method: .post,
            path: "transactions",
            body: TransactionRequest(draft)
        ))
    }

    func replaceTransaction(id: String, with draft: TransactionDraft) async throws {
        let _: EmptyBody = try await client.send(Endpoint(
            method: .post,
            path: "transactions/\(id)/replace",
            body: TransactionRequest(draft)
        ))
    }

    func reverseTransaction(id: String) async throws {
        let _: EmptyBody = try await client.send(Endpoint(method: .post, path: "transactions/\(id)/reverse"))
    }

    func budgets(in month: LedgerMonth) async throws -> [BudgetSummary] {
        try await client.send(Endpoint(
            method: .get,
            path: "budgets",
            query: [URLQueryItem(name: "month", value: month.apiValue)]
        ))
    }

    func setBudget(accountID: String, month: LedgerMonth, limitVnd: Int64) async throws {
        let _: EmptyBody = try await client.send(Endpoint(
            method: .put,
            path: "budgets/\(accountID)/\(month.apiValue)",
            body: BudgetRequest(limitVnd: limitVnd)
        ))
    }

    func deleteBudget(accountID: String, month: LedgerMonth) async throws {
        let _: EmptyResponse = try await client.send(Endpoint(
            method: .delete,
            path: "budgets/\(accountID)/\(month.apiValue)"
        ))
    }

    func standingOrders() async throws -> [StandingOrder] {
        try await client.send(Endpoint(method: .get, path: "standing-orders"))
    }

    func createStandingOrder(_ draft: StandingOrderDraft) async throws {
        let accounts = doubleEntryAccounts(flow: draft.flow, categoryID: draft.categoryID, walletID: draft.walletID)
        let _: EmptyBody = try await client.send(Endpoint(
            method: .post,
            path: "standing-orders",
            body: StandingOrderRequest(
                name: draft.name,
                amountVnd: draft.amountVnd,
                debitAccountId: accounts.debit,
                creditAccountId: accounts.credit,
                dayOfMonth: draft.dayOfMonth,
                autoPost: draft.autoPost
            )
        ))
    }

    func setStandingOrderPaused(id: String, paused: Bool) async throws {
        let _: EmptyBody = try await client.send(Endpoint(
            method: .post,
            path: "standing-orders/\(id)/\(paused ? "pause" : "resume")"
        ))
    }

    func postStandingOrder(id: String) async throws {
        let _: EmptyBody = try await client.send(Endpoint(method: .post, path: "standing-orders/\(id)/post"))
    }
}

/// For responses whose body the app ignores: it reloads the screen after a mutation instead.
private struct EmptyBody: Decodable {}

private struct TransactionRequest: Encodable {
    struct Entry: Encodable {
        let accountId: String
        let direction: EntryDirection
        let amountVnd: Int64
    }

    let occurredAt: Date
    let note: String?
    let idempotencyKey: String
    let entries: [Entry]

    init(_ draft: TransactionDraft) {
        let accounts = doubleEntryAccounts(flow: draft.flow, categoryID: draft.categoryID, walletID: draft.walletID)
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)

        self.occurredAt = draft.occurredAt
        self.note = note.isEmpty ? nil : note
        self.idempotencyKey = draft.idempotencyKey
        self.entries = [
            Entry(accountId: accounts.debit, direction: .debit, amountVnd: draft.amountVnd),
            Entry(accountId: accounts.credit, direction: .credit, amountVnd: draft.amountVnd),
        ]
    }
}

private struct BudgetRequest: Encodable {
    let limitVnd: Int64
}

private struct StandingOrderRequest: Encodable {
    let name: String
    let amountVnd: Int64
    let debitAccountId: String
    let creditAccountId: String
    let dayOfMonth: Int
    let autoPost: Bool
}
