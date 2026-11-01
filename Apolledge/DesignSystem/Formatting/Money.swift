//
//  Money.swift
//  Apolledge
//

import Foundation

/// Design system: `185.000 ₫`, dot thousands separator, real minus sign (U+2212), no decimals.
enum Money {
    static let minus = "\u{2212}"
    private static let maximumDigits = 15

    static func grouped(_ amount: Int64) -> String {
        let digits = String(amount.magnitude)
        var grouped = ""
        for (offset, digit) in digits.enumerated() {
            if offset > 0, (digits.count - offset) % 3 == 0 {
                grouped.append(".")
            }
            grouped.append(digit)
        }
        return amount < 0 ? minus + grouped : grouped
    }

    static func vnd(_ amount: Int64) -> String {
        "\(grouped(amount)) ₫"
    }

    /// `−185.000` for money out, `+22.000.000` for money in.
    static func signed(_ amount: Int64, flow: MoneyFlow) -> String {
        (flow == .income ? "+" : minus) + grouped(amount)
    }

    /// `+1.055.000` or `−403.000`, for a net total that can go either way.
    static func net(_ amount: Int64) -> String {
        amount > 0 ? "+" + grouped(amount) : grouped(amount)
    }

    /// Millions with one decimal comma, for chart labels: `8,8`.
    static func millions(_ amount: Int64) -> String {
        let tenths = (amount + 50_000) / 100_000
        return "\(tenths / 10),\(tenths % 10)"
    }

    /// Regroups an amount field as it is typed. Digits past the postable limit are dropped instead of clearing the field.
    static func formattedInput(_ text: String) -> String {
        let digits = text.filter(\.isASCII).filter(\.isNumber).prefix(maximumDigits)
        return parse(String(digits)).map(grouped) ?? ""
    }

    /// Parses what the user typed: every non-digit is ignored. Nil for no digits or a value too large to post.
    static func parse(_ text: String) -> Int64? {
        let digits = text.filter(\.isASCII).filter(\.isNumber)
        guard !digits.isEmpty, digits.count <= maximumDigits else { return nil }
        return Int64(digits)
    }
}
