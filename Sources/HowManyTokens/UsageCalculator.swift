import Foundation

enum UsageCalculator {
    /// The short text rendered in the menu bar, for example "C 42%  G 12%".
    ///
    /// Only percentages that are genuinely known are written. A provider whose
    /// percentage is unknown, or whose window has expired, does not appear at
    /// all — no invented number is displayed.
    static func menuBarText(usages: [ProviderUsage],
                            showGemini: Bool,
                            showLabels: Bool,
                            now: Date) -> String {
        let visible = usages.filter { $0.provider != .gemini || showGemini }
        let parts = visible.compactMap { usage -> String? in
            guard let window = usage.primaryWindow,
                  let percent = window.displayPercent(now: now) else { return nil }
            let value = Int((percent * 100).rounded())
            let stale = usage.isStale(now: now) ? "~" : ""
            return showLabels
                ? "\(usage.provider.shortLabel) \(stale)\(value)%"
                : "\(stale)\(value)%"
        }
        return parts.isEmpty ? "—" : parts.joined(separator: "  ")
    }
}
