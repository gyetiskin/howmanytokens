import Foundation
import SwiftUI

enum Format {
    /// 1_234_567 -> "1.2M", 45_600 -> "45.6K"
    static func tokens(_ value: Int) -> String {
        let v = Double(value)
        switch abs(v) {
        case 1_000_000_000...:
            return String(format: "%.1fB", v / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", v / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", v / 1_000)
        default:
            return String(Int(v))
        }
    }

    /// Time left, as "2h 14m".
    static func remaining(until date: Date, from now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 0 else { return "elapsed" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    /// How old the data is, as "3m" or "2h".
    static func age(of date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "\(max(seconds, 0))s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }

    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// Turns a model id into something readable: "claude-opus-5" -> "Opus 5".
    static func model(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "models/", with: "")
        return cleaned
            .split(separator: "-")
            .map { $0.count <= 2 ? String($0) : $0.capitalized }
            .joined(separator: " ")
    }

    /// Warning colour for a fill level.
    static func color(for percent: Double) -> Color {
        switch percent {
        case ..<0.6: return .green
        case ..<0.85: return .yellow
        default: return .red
        }
    }
}
