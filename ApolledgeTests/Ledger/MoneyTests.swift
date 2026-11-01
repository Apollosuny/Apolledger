//
//  MoneyTests.swift
//  ApolledgeTests
//

import Testing
@testable import Apolledge

@MainActor
struct MoneyTests {
    @Test func groupsWithDotsAndRealMinus() {
        #expect(Money.vnd(185_000) == "185.000 ₫")
        #expect(Money.grouped(-403_000) == "\u{2212}403.000")
        #expect(Money.grouped(0) == "0")
    }

    @Test func signsFollowTheFlow() {
        #expect(Money.signed(185_000, flow: .expense) == "\u{2212}185.000")
        #expect(Money.signed(22_000_000, flow: .income) == "+22.000.000")
    }

    @Test func parseIgnoresGroupingAndRejectsOversizedInput() {
        #expect(Money.parse("185.000") == 185_000)
        #expect(Money.parse("") == nil)
        #expect(Money.parse(String(repeating: "9", count: 16)) == nil)
    }

    @Test func oversizedTypingKeepsTheFieldInsteadOfClearingIt() {
        #expect(Money.formattedInput(String(repeating: "1", count: 16)) == "111.111.111.111.111")
        #expect(Money.formattedInput("abc") == "")
    }

    @Test func millionsRoundToOneDecimal() {
        #expect(Money.millions(8_840_000) == "8,8")
        #expect(Money.millions(0) == "0,0")
    }
}
