import Foundation
import Combine

/// User settings, persisted to UserDefaults.
///
/// Note: `@AppStorage` cannot be used here. That property wrapper only works
/// inside a View; within an ObservableObject it never publishes
/// `objectWillChange`, so changing a setting would not redraw the panel. Hence
/// `@Published` plus an explicit write in `didSet`.
@MainActor
final class Preferences: ObservableObject {
    private let defaults: UserDefaults

    /// There is no limit setting for Claude — the real percentage comes from the
    /// provider. Gemini reports no percentage, so a user who knows their limit
    /// can enter it; left at 0, no percentage is shown, only the token count.
    @Published var geminiLimit: Int { didSet { defaults.set(geminiLimit, forKey: Key.geminiLimit) } }
    @Published var showGemini: Bool { didSet { defaults.set(showGemini, forKey: Key.showGemini) } }
    @Published var showLabels: Bool { didSet { defaults.set(showLabels, forKey: Key.showLabels) } }
    @Published var refreshSeconds: Int { didSet { defaults.set(refreshSeconds, forKey: Key.refreshSeconds) } }
    @Published var iconStyle: IconStyle { didSet { defaults.set(iconStyle.rawValue, forKey: Key.iconStyle) } }

    private enum Key {
        static let geminiLimit = "geminiLimit"
        static let showGemini = "showGemini"
        static let showLabels = "showLabels"
        static let refreshSeconds = "refreshSeconds"
        static let iconStyle = "iconStyle"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.showGemini: true,
            Key.showLabels: true,
            Key.refreshSeconds: 20,
            Key.iconStyle: IconStyle.bar.rawValue
        ])
        geminiLimit = defaults.integer(forKey: Key.geminiLimit)
        showGemini = defaults.bool(forKey: Key.showGemini)
        showLabels = defaults.bool(forKey: Key.showLabels)
        refreshSeconds = defaults.integer(forKey: Key.refreshSeconds)
        iconStyle = defaults.string(forKey: Key.iconStyle)
            .flatMap(IconStyle.init(rawValue:)) ?? .bar
    }

    func limit(for provider: Provider) -> Int {
        switch provider {
        case .claude: return 0      // unused
        case .gemini: return geminiLimit
        }
    }
}
