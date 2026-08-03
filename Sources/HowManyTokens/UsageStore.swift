import Foundation
import Combine

/// Holds the current state of every provider and refreshes it on a timer.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var usages: [ProviderUsage] = []
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isRefreshing = false

    private let sources: [UsageSource]
    private let preferences: Preferences
    private var timer: Timer?
    /// Parsing runs off the main thread so the interface never blocks on it.
    private let queue = DispatchQueue(label: "howmanytokens.parse", qos: .utility)

    init(sources: [UsageSource] = [ClaudeSource(), GeminiSource()],
         preferences: Preferences) {
        self.sources = sources
        self.preferences = preferences
    }

    func start() {
        refresh()
        scheduleTimer()
    }

    func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(max(5, preferences.refreshSeconds))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        let sources = self.sources
        let limits = Dictionary(uniqueKeysWithValues: Provider.allCases.map {
            ($0, preferences.limit(for: $0))
        })

        queue.async { [weak self] in
            let computed = sources.map { $0.load(manualLimit: limits[$0.provider] ?? 0) }
            let now = Date()
            Task { @MainActor in
                guard let self else { return }
                self.usages = computed
                self.lastRefresh = now
                self.isRefreshing = false
            }
        }
    }

    func usage(for provider: Provider) -> ProviderUsage? {
        usages.first { $0.provider == provider }
    }

    func menuBarText(now: Date) -> String {
        UsageCalculator.menuBarText(usages: usages,
                                    showGemini: preferences.showGemini,
                                    showLabels: preferences.showLabels,
                                    now: now)
    }
}
