import Foundation

/// Text inside `{…}` is a `DateFormatter` format; everything else is literal.
enum FileNamePattern {
    static let defaultPattern = "Screeny {yyyy-MM-dd} at {HH.mm.ss}"

    static func fileName(pattern: String, date: Date, timeZone: TimeZone = .current) -> String {
        var result = ""
        var rest = Substring(pattern)
        while let open = rest.firstIndex(of: "{") {
            result += rest[..<open]
            let afterOpen = rest.index(after: open)
            guard let close = rest[afterOpen...].firstIndex(of: "}") else {
                result += rest[open...]
                rest = ""
                break
            }
            result += format(date, with: String(rest[afterOpen ..< close]), timeZone: timeZone)
            rest = rest[rest.index(after: close)...]
        }
        result += rest

        let sanitized = result
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
        let base = sanitized.isEmpty ? "Screenshot" : sanitized
        return base.lowercased().hasSuffix(".png") ? base : base + ".png"
    }

    private static func format(_ date: Date, with format: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
