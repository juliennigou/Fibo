import Foundation

enum AppFormat {
    static func currency(_ value: Double, code: String, showSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.2f %@", abs(value), code)
        guard showSign, value != 0 else { return value < 0 ? "−\(formatted)" : formatted }
        return value > 0 ? "+\(formatted)" : "−\(formatted)"
    }

    static func percent(_ value: Double, showSign: Bool = false) -> String {
        let prefix: String
        if showSign && value > 0 { prefix = "+" }
        else if value < 0 { prefix = "−" }
        else { prefix = "" }
        return "\(prefix)\(String(format: "%.2f", abs(value)).replacingOccurrences(of: ".", with: ",")) %"
    }

    static func decimal(_ value: Double, digits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.*f", digits, value)
    }

    static func relativeDate(_ date: Date) -> String {
        if abs(date.timeIntervalSinceNow) < 60 { return "à l’instant" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "fr_FR")))
    }
}

enum MyfxbookDateParser {
    private static let formats = ["MM/dd/yyyy HH:mm", "MM/dd/yyyy", "yyyy-MM-dd'T'HH:mm:ssZ"]

    static func parse(_ value: String) -> Date? {
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}
