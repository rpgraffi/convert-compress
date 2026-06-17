import Foundation

enum RenameDateFormatPreset: String, CaseIterable, Codable, Hashable, Identifiable {
    case dayMonthYearDots = "dd_mm_yyyy"
    case yearMonthDayDashes = "yyyy_mm_dd"
    case localizedShort = "localized_short"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dayMonthYearDots:
            "dd.mm.yyyy"
        case .yearMonthDayDashes:
            "yyyy-mm-dd"
        case .localizedShort:
            String(localized: "Localized")
        }
    }

    func string(from date: Date, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent) -> String {
        switch self {
        case .dayMonthYearDots:
            return formatted(date, pattern: "dd.MM.yyyy", locale: locale, calendar: calendar)
        case .yearMonthDayDashes:
            return formatted(date, pattern: "yyyy-MM-dd", locale: locale, calendar: calendar)
        case .localizedShort:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    private func formatted(_ date: Date, pattern: String, locale: Locale, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

