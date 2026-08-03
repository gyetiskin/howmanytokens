import Foundation

/// Prints what was read, without opening the interface (HMT_DUMP=1).
enum Diagnostics {
    static func dump() {
        let now = Date()
        let gemini = GeminiSource()
        let sources: [UsageSource] = [ClaudeSource(), gemini]

        // The Gemini limit can be supplied from the environment to exercise the
        // percentage path as well.
        let geminiLimit = ProcessInfo.processInfo.environment["HMT_GEMINI_LIMIT"]
            .flatMap(Int.init) ?? 0

        let usages = sources.map {
            $0.load(manualLimit: $0.provider == .gemini ? geminiLimit : 0)
        }

        for usage in usages {
            print("=== \(usage.provider.displayName) ===")

            if let measured = usage.measuredAt {
                print("  measured: \(Format.age(of: measured, now: now)) ago"
                      + (usage.isStale(now: now) ? "  [STALE]" : ""))
            }

            if let reason = usage.unavailableReason {
                print("  no data: \(reason)\n")
                continue
            }

            for window in usage.windows {
                var line = "  \(window.label): "
                if let percent = window.displayPercent(now: now) {
                    line += "\(Int((percent * 100).rounded()))%"
                } else if window.isExpired(now: now) {
                    line += "window has reset"
                } else {
                    line += "percentage unknown"
                }
                if let tokens = window.tokens { line += "  (\(Format.tokens(tokens)) tokens)" }
                if let resetsAt = window.resetsAt {
                    line += "  resets \(Format.clock(resetsAt))"
                }
                print(line)
            }

            if usage.provider == .gemini {
                for entry in gemini.activeBlockByModel().prefix(4) {
                    print("      \(Format.model(entry.model)): \(Format.tokens(entry.tokens))")
                }
            }
            print("")
        }

        print("=== Menu bar ===")
        print("  with labels:    \(UsageCalculator.menuBarText(usages: usages, showGemini: true, showLabels: true, now: now))")
        print("  without labels: \(UsageCalculator.menuBarText(usages: usages, showGemini: true, showLabels: false, now: now))")
        print("  Claude only:    \(UsageCalculator.menuBarText(usages: usages, showGemini: false, showLabels: true, now: now))")
    }
}
