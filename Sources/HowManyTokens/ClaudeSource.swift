import Foundation

/// Reads Claude's real quota usage.
///
/// Claude Code passes a JSON payload on stdin to the configured status line
/// command, and that payload carries the real subscription usage percentages
/// under `rate_limits.five_hour` and `rate_limits.seven_day`. The bridge script
/// writes them to a file; this type reads that file.
///
/// Nothing here is estimated — the numbers come from the provider. The cost is
/// that they only refresh while Claude Code is running.
final class ClaudeSource: UsageSource, @unchecked Sendable {
    let provider: Provider = .claude

    static var defaultFile: URL {
        if let override = ProcessInfo.processInfo.environment["HMT_CLAUDE_FILE"] {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/howmanytokens-usage.json")
    }

    private let file: URL

    init(file: URL = ClaudeSource.defaultFile) {
        self.file = file
    }

    /// `manualLimit` is unused here — Claude reports the real percentage itself.
    func load(manualLimit: Int) -> ProviderUsage {
        guard FileManager.default.fileExists(atPath: file.path) else {
            return unavailable("""
                Bridge file missing. Check the statusLine entry in \
                ~/.claude/settings.json, then run Claude Code once.
                """)
        }

        guard let data = try? Data(contentsOf: file),
              let root = JSONValue.parse(data) else {
            return unavailable("Bridge file could not be read.")
        }

        let capturedAt = root["captured_at"]?.doubleValue.map { Date(timeIntervalSince1970: $0) }

        guard let limits = root["rate_limits"], limits.objectValue != nil else {
            // rate_limits came back null: no subscription limits were reported.
            // Per the documentation this field is present only for Claude.ai
            // subscribers, and only after the first API response.
            return ProviderUsage(provider: provider, windows: [], measuredAt: capturedAt,
                                 unavailableReason: """
                                 Claude reported no limits. This field is populated only for \
                                 Claude.ai subscriptions, after the first API response.
                                 """)
        }

        let windows = [
            window(from: limits["five_hour"], label: "5 hours"),
            window(from: limits["seven_day"], label: "7 days")
        ].compactMap { $0 }

        guard !windows.isEmpty else {
            return ProviderUsage(provider: provider, windows: [], measuredAt: capturedAt,
                                 unavailableReason: "No limit window was reported.")
        }

        return ProviderUsage(provider: provider, windows: windows,
                             measuredAt: capturedAt, unavailableReason: nil)
    }

    private func window(from node: JSONValue?, label: String) -> UsageWindow? {
        guard let node, let percent = node["used_percentage"]?.doubleValue else { return nil }
        let resetsAt = node["resets_at"]?.doubleValue.map { Date(timeIntervalSince1970: $0) }
        return UsageWindow(label: label, percent: percent / 100, tokens: nil, resetsAt: resetsAt)
    }

    private func unavailable(_ reason: String) -> ProviderUsage {
        ProviderUsage(provider: provider, windows: [], measuredAt: nil, unavailableReason: reason)
    }
}
