import Foundation

/// A single request and the tokens it consumed.
/// Only used by sources that count tokens themselves (Gemini). On the Claude
/// side the provider reports a ready-made percentage, so no counting is needed.
struct UsageEvent: Sendable {
    let timestamp: Date
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

/// A five-hour window reconstructed by counting tokens (Gemini only).
struct UsageBlock: Sendable {
    let start: Date
    let end: Date
    var events: [UsageEvent]

    var totalTokens: Int { events.reduce(0) { $0 + $1.totalTokens } }
    var lastActivity: Date? { events.last?.timestamp }

    func isActive(now: Date) -> Bool { now < end }

    /// Token breakdown per model, highest first.
    var byModel: [(model: String, tokens: Int)] {
        var acc: [String: Int] = [:]
        for e in events { acc[e.model, default: 0] += e.totalTokens }
        return acc.sorted { $0.value > $1.value }.map { (model: $0.key, tokens: $0.value) }
    }
}

/// The state of a single quota window.
///
/// `percent` is populated only when it is genuinely known. When unknown it stays
/// nil and the interface shows no percentage at all — a blank space rather than
/// an invented number.
struct UsageWindow: Sendable, Identifiable {
    let label: String
    let percent: Double?
    /// Measured tokens (Gemini). Claude reports a percentage, not token counts.
    let tokens: Int?
    let resetsAt: Date?

    var id: String { label }

    /// Once the window has rolled over, the percentage we hold is no longer valid.
    func isExpired(now: Date) -> Bool {
        guard let resetsAt else { return false }
        return now >= resetsAt
    }

    /// Displayable percentage: an expired window shows no number.
    func displayPercent(now: Date) -> Double? {
        isExpired(now: now) ? nil : percent
    }
}

enum Provider: String, CaseIterable, Identifiable, Sendable {
    case claude
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        }
    }

    /// Short label used in the menu bar.
    var shortLabel: String {
        switch self {
        case .claude: return "C"
        case .gemini: return "G"
        }
    }
}

/// The computed state of one provider.
struct ProviderUsage: Sendable {
    var provider: Provider
    var windows: [UsageWindow]
    /// When the data was captured from the provider. This goes stale while
    /// Claude Code is not running; the interface says so explicitly.
    var measuredAt: Date?
    /// Populated when the source is missing or unconfigured.
    var unavailableReason: String?

    var hasData: Bool { unavailableReason == nil && !windows.isEmpty }

    /// The window shown in the menu bar (the five-hour one for Claude).
    var primaryWindow: UsageWindow? { windows.first }

    /// Data older than this is considered stale.
    static let stalenessThreshold: TimeInterval = 10 * 60

    func isStale(now: Date) -> Bool {
        guard let measuredAt else { return false }
        return now.timeIntervalSince(measuredAt) > Self.stalenessThreshold
    }
}

// MARK: - Reconstructing windows from token counts (Gemini)

enum BlockBuilder {
    static let windowLength: TimeInterval = 5 * 60 * 60

    /// Splits events into five-hour blocks. A new block starts when the current
    /// one has run its five hours, or when two requests are more than five hours
    /// apart.
    static func build(from events: [UsageEvent]) -> [UsageBlock] {
        let sorted = events.filter { $0.totalTokens > 0 }.sorted { $0.timestamp < $1.timestamp }
        var blocks: [UsageBlock] = []
        var current: UsageBlock?

        for event in sorted {
            if var block = current {
                let gap = event.timestamp.timeIntervalSince(block.lastActivity ?? block.start)
                if event.timestamp >= block.end || gap >= windowLength {
                    blocks.append(block)
                    current = newBlock(startingAt: event)
                } else {
                    block.events.append(event)
                    current = block
                }
            } else {
                current = newBlock(startingAt: event)
            }
        }
        if let block = current { blocks.append(block) }
        return blocks
    }

    private static func newBlock(startingAt event: UsageEvent) -> UsageBlock {
        let start = floorToHour(event.timestamp)
        return UsageBlock(start: start, end: start.addingTimeInterval(windowLength), events: [event])
    }

    private static func floorToHour(_ date: Date) -> Date {
        let cal = Calendar.current
        let parts = cal.dateComponents([.year, .month, .day, .hour], from: date)
        return cal.date(from: parts) ?? date
    }
}
