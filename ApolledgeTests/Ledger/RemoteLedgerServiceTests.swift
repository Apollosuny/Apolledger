//
//  RemoteLedgerServiceTests.swift
//  ApolledgeTests
//

import Foundation
import Testing
@testable import Apolledge

/// Runs through the real client so request shape and the backend's date formats are covered together.
@MainActor
struct RemoteLedgerServiceTests {
    private func makeService(_ transport: StubTransport) -> RemoteLedgerService {
        let tokenManager = AuthTokenManager(
            store: InMemorySessionStore(session: .fixture(accessToken: "a1", refreshToken: "r1")),
            authService: StubAuthService()
        )
        let client = URLSessionAPIClient(
            baseURL: URL(string: "https://example.test/v1")!,
            transport: transport,
            tokenProvider: tokenManager
        )
        return RemoteLedgerService(client: client)
    }

    private func query(of request: URLRequest?) throws -> [String: String] {
        let url = try #require(request?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    private let august = LedgerMonth(year: 2026, month: 8)

    private func page(last: Bool, ids: [String]) -> String {
        let items = ids.map {
            #"{"id":"\#($0)","occurredAt":"2026-08-12T01:24:00.123456Z","note":null,"reversesId":null,"source":"manual","entries":[]}"#
        }
        return #"{"content":[\#(items.joined(separator: ","))],"last":\#(last)}"#
    }

    @Test func transactionsUseVietnamMonthBoundsAndFollowPages() async throws {
        let transport = StubTransport { request in
            let isFirst = request.url?.query?.contains("page=0") == true
            return (200, page(last: !isFirst, ids: isFirst ? ["a"] : ["b"]))
        }

        let transactions = try await makeService(transport).transactions(in: august)

        #expect(transactions.map(\.id) == ["a", "b"])
        let parameters = try query(of: transport.requests.first)
        #expect(parameters["from"] == "2026-07-31T17:00:00Z")
        #expect(parameters["to"] == "2026-08-31T17:00:00Z")
        #expect(parameters["activeOnly"] == "true")
    }

    @Test func expenseDebitsTheCategoryAndCreditsTheWallet() async throws {
        let transport = StubTransport { _ in (201, "{}") }
        let draft = TransactionDraft(
            flow: .expense, amountVnd: 185_000, categoryID: "food", walletID: "cash",
            note: "  ", occurredAt: Date(timeIntervalSince1970: 0), idempotencyKey: "k1"
        )

        try await makeService(transport).createTransaction(draft)

        let body = try #require(transport.requests.first?.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let entries = try #require(json["entries"] as? [[String: Any]])
        #expect(json["idempotencyKey"] as? String == "k1")
        #expect(json["note"] == nil || json["note"] is NSNull)
        #expect(entries[0]["accountId"] as? String == "food")
        #expect(entries[0]["direction"] as? String == "DEBIT")
        #expect(entries[1]["accountId"] as? String == "cash")
        #expect(entries[1]["direction"] as? String == "CREDIT")
    }

    @Test func balanceReadsTheAccountsLedgerSum() async throws {
        let transport = StubTransport { _ in (200, #"{"accountId":"cash","balanceVnd":-85000,"asOf":null}"#) }

        let balance = try await makeService(transport).balance(accountID: "cash")

        #expect(balance == -85_000)
        #expect(transport.requests.first?.url?.path.hasSuffix("/accounts/cash/balance") == true)
    }

    @Test func createAccountSendsTheBackendTypeName() async throws {
        let transport = StubTransport { _ in
            (200, #"{"id":"e1","type":"EQUITY","name":"Số dư đầu kỳ","icon":null}"#)
        }

        let account = try await makeService(transport).createAccount(type: .equity, name: "Số dư đầu kỳ", icon: nil)

        let body = try #require(transport.requests.first?.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["type"] as? String == "EQUITY")
        #expect(account.id == "e1")
    }

    @Test func budgetPathsCarryTheMonth() async throws {
        let transport = StubTransport { _ in (204, "") }

        try await makeService(transport).deleteBudget(accountID: "food", month: august)

        #expect(transport.requests.first?.httpMethod == "DELETE")
        #expect(transport.requests.first?.url?.path.hasSuffix("/budgets/food/2026-08") == true)
    }
}
