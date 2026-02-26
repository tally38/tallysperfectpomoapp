import Foundation

enum Formatters {
    /// Formats seconds into "MM:SS" countdown string (e.g., 1421 → "23:41")
    static func formatCountdown(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formats a date into a relative day label ("Today", "Yesterday", "Feb 17, 2025")
    static func formatRelativeDay(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    /// Formats a date into time string (e.g., "2:30 PM")
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    /// Formats a date as "MMM d, yyyy" (e.g., "Feb 17, 2026")
    static func formatMediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Formats duration in seconds to a human-readable string (e.g., 1500 → "25 min")
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes == 0 {
            return "\(Int(seconds)) sec"
        }
        return "\(minutes) min"
    }

    /// Formats duration in seconds to "Xh Ym" for longer durations (e.g., 9000 → "2h 30m")
    static func formatLongDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
}
