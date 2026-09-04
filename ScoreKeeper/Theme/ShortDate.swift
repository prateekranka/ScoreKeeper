import Foundation

// MARK: - Shared short-date formatting
//
// All fixed app copy renders lowercase (copy foundation G1/G2), so dates
// follow the same style: a 3-letter lowercase month, e.g. "sep 4, 2026".
// Use this helper anywhere a short date is shown instead of composing
// `Date.formatted(...)` inline.

enum ShortDate {
    /// Short date with a lowercase 3-letter month, e.g. "sep 4, 2026".
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date).lowercased()
    }
}

extension Date {
    /// Lowercase short date string, e.g. "sep 4, 2026".
    var shortDateString: String {
        ShortDate.string(from: self)
    }
}
