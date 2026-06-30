import Foundation

enum DateFormatting {
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static let absolute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func relativeDisplay(for date: Date, relativeTo now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        if abs(interval) < 45 {
            return "Just now"
        }

        return relative.localizedString(for: date, relativeTo: now)
    }
}
