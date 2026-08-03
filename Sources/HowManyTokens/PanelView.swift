import SwiftUI

/// The panel that opens when the menu bar icon is clicked.
struct PanelView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var preferences: Preferences
    @State private var showingSettings = false
    @State private var now = Date()

    /// Keeps countdowns and staleness ticking over.
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleBar

            ForEach(visibleUsages, id: \.provider.id) { usage in
                ProviderCard(usage: usage, now: now)
            }

            if showingSettings {
                Divider()
                SettingsView(preferences: preferences, store: store)
            }

            Divider()
            footer
        }
        .padding(12)
        .frame(width: 320)
        .onReceive(tick) { now = $0 }
    }

    private var visibleUsages: [ProviderUsage] {
        store.usages.filter { $0.provider != .gemini || preferences.showGemini }
    }

    private var titleBar: some View {
        HStack {
            Text("Token Usage")
                .font(.headline)
            Spacer()
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")

            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: showingSettings ? "gearshape.fill" : "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
    }

    private var footer: some View {
        HStack {
            if let last = store.lastRefresh {
                Text("Updated \(Format.clock(last))")
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// Limit and appearance settings.
struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings").font(.subheadline.bold())

            limitField(
                title: "Gemini 5h limit",
                value: Binding(get: { preferences.geminiLimit },
                               set: { preferences.geminiLimit = max(0, $0); store.refresh() })
            )

            Text("""
                 Claude reports its real percentage, so it needs no limit setting. \
                 Gemini does not: enter your limit to get a percentage, or leave it \
                 empty to see the token count alone.
                 """)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Icon")
                Spacer()
                Picker("", selection: $preferences.iconStyle) {
                    Text("Bar").tag(IconStyle.bar)
                    Text("Ring").tag(IconStyle.ring)
                    Text("Segments").tag(IconStyle.segments)
                }
                .labelsHidden()
                .frame(width: 100)
            }

            Toggle("Show Gemini", isOn: $preferences.showGemini)
            Toggle("Show labels in menu bar (C / G)", isOn: $preferences.showLabels)

            HStack {
                Text("Refresh")
                Spacer()
                Picker("", selection: Binding(
                    get: { preferences.refreshSeconds },
                    set: { preferences.refreshSeconds = $0; store.scheduleTimer() }
                )) {
                    Text("10 s").tag(10)
                    Text("20 s").tag(20)
                    Text("60 s").tag(60)
                }
                .labelsHidden()
                .frame(width: 100)
            }
        }
        .toggleStyle(.checkbox)
        .font(.caption)
    }

    private func limitField(title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("not set", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .multilineTextAlignment(.trailing)
        }
    }
}
