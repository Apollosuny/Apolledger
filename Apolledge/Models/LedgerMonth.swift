//
//  LedgerMonth.swift
//  Apolledge
//

import Foundation

/// Calendar shared by every month and day boundary in the app. It is fixed to the backend's `app.timezone`,
/// so the month totals computed here always agree with the budgets computed there, wherever the phone is.
enum LedgerCalendar {
    static let timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "vi_VN")
        return calendar
    }()
}

struct LedgerMonth: Hashable, Identifiable {
    let year: Int
    let month: Int

    var id: String { apiValue }

    private static let names = [
        "Tháng Một", "Tháng Hai", "Tháng Ba", "Tháng Tư", "Tháng Năm", "Tháng Sáu",
        "Tháng Bảy", "Tháng Tám", "Tháng Chín", "Tháng Mười", "Tháng Mười Một", "Tháng Mười Hai",
    ]

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(containing date: Date) {
        let components = LedgerCalendar.calendar.dateComponents([.year, .month], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1)
    }

    /// `yyyy-MM`, the format of the budget endpoints.
    var apiValue: String { String(format: "%04d-%02d", year, month) }

    var name: String { Self.names[month - 1] }

    var start: Date {
        LedgerCalendar.calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    var dayCount: Int {
        LedgerCalendar.calendar.range(of: .day, in: .month, for: start)?.count ?? 30
    }

    func adding(months: Int) -> LedgerMonth {
        let total = year * 12 + (month - 1) + months
        return LedgerMonth(year: total / 12, month: total % 12 + 1)
    }

    /// The months ending at this one, oldest first.
    func trailing(_ count: Int) -> [LedgerMonth] {
        (0..<count).map { adding(months: $0 - count + 1) }
    }
}
