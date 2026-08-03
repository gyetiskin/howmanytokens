import SwiftUI

@main
struct HowManyTokensApp: App {
    @StateObject private var preferences: Preferences
    @StateObject private var store: UsageStore

    init() {
        // HMT_DUMP=1 prints what was read to the terminal without opening the UI.
        if ProcessInfo.processInfo.environment["HMT_DUMP"] == "1" {
            Diagnostics.dump()
            exit(0)
        }
        if let path = ProcessInfo.processInfo.environment["HMT_ICON_PREVIEW"] {
            IconPreview.render(to: path)
            exit(0)
        }

        let preferences = Preferences()
        _preferences = StateObject(wrappedValue: preferences)
        _store = StateObject(wrappedValue: UsageStore(preferences: preferences))
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store, preferences: preferences)
                .onAppear { store.start() }
        } label: {
            let now = Date()
            HStack(spacing: 3) {
                Image(nsImage: IconRenderer.image(style: preferences.iconStyle,
                                                  percent: peakPercent(now: now),
                                                  stale: anyStale(now: now)))
                Text(store.menuBarText(now: now))
            }
        }
        .menuBarExtraStyle(.window)
    }

    /// The icon reflects the highest known percentage. When none is known it
    /// returns nil and the icon is drawn as an empty outline.
    private func peakPercent(now: Date) -> Double? {
        store.usages
            .compactMap { $0.primaryWindow?.displayPercent(now: now) }
            .max()
    }

    private func anyStale(now: Date) -> Bool {
        store.usages.contains { $0.hasData && $0.isStale(now: now) }
    }
}
