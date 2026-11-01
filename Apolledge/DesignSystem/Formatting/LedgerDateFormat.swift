//
//  LedgerDateFormat.swift
//  Apolledge
//

import Foundation

/// Design system: dates read naturally: `Hôm nay`, `Hôm qua`, `12 tháng 8`.
enum LedgerDateFormat {
    static func dayMonth(_ date: Date) -> String {
        let parts = LedgerCalendar.calendar.dateComponents([.day, .month], from: date)
        return "\(parts.day ?? 1) tháng \(parts.month ?? 1)"
    }

    /// Nil when the date is neither today nor yesterday.
    static func relativeDay(_ date: Date, now: Date) -> String? {
        let calendar = LedgerCalendar.calendar
        if calendar.isDate(date, inSameDayAs: now) { return "Hôm nay" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Hôm qua"
        }
        return nil
    }

    /// Section label: `Hôm nay · 12 tháng 8`, or just `10 tháng 8` for older days.
    static func sectionLabel(_ date: Date, now: Date) -> String {
        guard let relative = relativeDay(date, now: now) else { return dayMonth(date) }
        return "\(relative) · \(dayMonth(date))"
    }

    /// `12 tháng 8 · 08:24`
    static func dateTime(_ date: Date) -> String {
        let parts = LedgerCalendar.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%@ · %02d:%02d", dayMonth(date), parts.hour ?? 0, parts.minute ?? 0)
    }
}
