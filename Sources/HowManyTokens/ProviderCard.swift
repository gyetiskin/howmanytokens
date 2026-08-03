import SwiftUI

/// The state of a single provider.
struct ProviderCard: View {
    let usage: ProviderUsage
    /// Supplied from outside so countdowns and staleness stay in step.
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let reason = usage.unavailableReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(usage.windows) { window in
                    WindowRow(window: window, now: now)
                }
                if usage.isStale(now: now) { staleNote }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack {
            Text(usage.provider.displayName).font(.headline)
            Spacer()
            if usage.provider == .claude, usage.hasData {
                Text("reported")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// The bridge file does not refresh while Claude Code is closed. Rather than
    /// hiding how old the number is, we state it.
    private var staleNote: some View {
        Label {
            Text(usage.measuredAt.map { "measured \(Format.age(of: $0, now: now)) ago — Claude Code may be closed" } ?? "")
        } icon: {
            Image(systemName: "clock.badge.exclamationmark")
        }
        .font(.caption2)
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// One quota window: label, percentage, meter and reset time.
private struct WindowRow: View {
    let window: UsageWindow
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(window.label)
                    .font(.subheadline)
                Spacer()
                if let percent = window.displayPercent(now: now) {
                    Text("\(Int((percent * 100).rounded()))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Format.color(for: percent))
                } else if let tokens = window.tokens {
                    // Percentage unknown: show what was measured instead of a guess.
                    Text(Format.tokens(tokens))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let percent = window.displayPercent(now: now) {
                meter(percent: percent)
            }

            HStack {
                if window.isExpired(now: now) {
                    Text("window has reset — run Claude Code for a current value")
                } else if let resetsAt = window.resetsAt {
                    Text("resets \(Format.clock(resetsAt)) · \(Format.remaining(until: resetsAt, from: now))")
                }
                Spacer()
                if window.percent == nil, window.tokens != nil {
                    Text("no limit set")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private func meter(percent: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(Format.color(for: percent))
                    .frame(width: max(2, geo.size.width * min(percent, 1)))
            }
        }
        .frame(height: 6)
    }
}
