import Foundation

/// Reads Gemini CLI token usage from its local telemetry file.
///
/// With `telemetry.target = "local"` and `telemetry.outfile` set, Gemini CLI
/// appends OpenTelemetry records to a file. Each API response produces a
/// `gemini_cli.api_response` log record whose attributes carry the input,
/// output, cached, thoughts and tool token counts along with the model name.
///
/// The file is not one JSON object per line: it is a run of pretty-printed
/// objects appended back to back, so JSONStream splits them. Because the OTLP
/// record shape shifts between versions, we walk the JSON tree looking for token
/// fields rather than binding tightly to a schema.
final class GeminiSource: UsageSource, @unchecked Sendable {
    let provider: Provider = .gemini

    /// Default location; override with HMT_GEMINI_OUTFILE if settings.json
    /// points somewhere else, or for testing.
    static var defaultOutfile: URL {
        if let override = ProcessInfo.processInfo.environment["HMT_GEMINI_OUTFILE"] {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/telemetry.jsonl")
    }

    private let outfile: URL
    private let settingsFile: URL
    private let cache = FileCache()

    init(outfile: URL = GeminiSource.defaultOutfile,
         settingsFile: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/settings.json")) {
        self.outfile = outfile
        self.settingsFile = settingsFile
    }

    private func unavailableReason() -> String? {
        let fm = FileManager.default
        if !fm.fileExists(atPath: settingsFile.deletingLastPathComponent().path) {
            return "Gemini CLI is not installed (no ~/.gemini directory)."
        }
        if !fm.fileExists(atPath: outfile.path) {
            return "Telemetry file not created yet — run Gemini CLI once."
        }
        return nil
    }

    func load(manualLimit: Int) -> ProviderUsage {
        if let reason = unavailableReason() {
            return ProviderUsage(provider: provider, windows: [],
                                 measuredAt: nil, unavailableReason: reason)
        }

        let events = cache.events(for: outfile, parse: parse)
        let blocks = BlockBuilder.build(from: events)
        let now = Date()

        guard let active = blocks.last, active.isActive(now: now) else {
            return ProviderUsage(provider: provider, windows: [],
                                 measuredAt: events.last?.timestamp,
                                 unavailableReason: "No Gemini requests in the last five hours.")
        }

        // Gemini does not report a real quota percentage. Without a configured
        // limit we do not invent one: the token count is shown, the percentage
        // is left blank.
        let percent = manualLimit > 0
            ? Double(active.totalTokens) / Double(manualLimit)
            : nil

        let window = UsageWindow(label: "5 hours", percent: percent,
                                 tokens: active.totalTokens, resetsAt: active.end)

        return ProviderUsage(provider: provider, windows: [window],
                             measuredAt: active.lastActivity, unavailableReason: nil)
    }

    /// Per-model breakdown for the active window, shown in the panel.
    func activeBlockByModel() -> [(model: String, tokens: Int)] {
        let blocks = BlockBuilder.build(from: cache.events(for: outfile, parse: parse))
        guard let active = blocks.last, active.isActive(now: Date()) else { return [] }
        return active.byModel
    }

    private func parse(_ file: URL) -> [UsageEvent] {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return [] }

        var events: [UsageEvent] = []
        for chunk in JSONStream.splitObjects(content) {
            guard let root = JSONValue.parse(chunk) else { continue }
            collect(from: root, inheritedTimestamp: nil, into: &events)
        }
        return events
    }

    /// Carries the nearest timestamp down the tree; emits an event when it finds
    /// an object holding token counts.
    private func collect(from node: JSONValue, inheritedTimestamp: Date?, into events: inout [UsageEvent]) {
        switch node {
        case .array(let items):
            for item in items {
                collect(from: item, inheritedTimestamp: inheritedTimestamp, into: &events)
            }

        case .object(let dict):
            let timestamp = Self.timestamp(in: dict) ?? inheritedTimestamp

            if let event = Self.usageEvent(from: dict, timestamp: timestamp) {
                events.append(event)
                return // No need to descend into an object already consumed.
            }

            for value in dict.values {
                collect(from: value, inheritedTimestamp: timestamp, into: &events)
            }

        default:
            break
        }
    }

    private static func usageEvent(from dict: [String: JSONValue], timestamp: Date?) -> UsageEvent? {
        let input = dict["input_token_count"]?.intValue
        let output = dict["output_token_count"]?.intValue
        // With none of the token fields present this is not a usage record.
        guard input != nil || output != nil, let timestamp else { return nil }

        let cached = dict["cached_content_token_count"]?.intValue ?? 0
        let thoughts = dict["thoughts_token_count"]?.intValue ?? 0
        let tool = dict["tool_token_count"]?.intValue ?? 0

        // Gemini bills thinking and tool tokens on the output side.
        return UsageEvent(
            timestamp: timestamp,
            model: dict["model"]?.stringValue ?? "gemini",
            inputTokens: input ?? 0,
            outputTokens: (output ?? 0) + thoughts + tool,
            cacheCreationTokens: 0,
            cacheReadTokens: cached
            // A single append-only file, so no de-duplication is needed.
        )
    }

    /// OTLP records carry timestamps in several shapes: an ISO string
    /// (`event.timestamp`), nanoseconds (`timeUnixNano`), or OpenTelemetry's
    /// `hrTime` pair of [seconds, nanoseconds].
    private static func timestamp(in dict: [String: JSONValue]) -> Date? {
        if let iso = ISO8601.date(from: dict["event.timestamp"]?.stringValue) { return iso }
        if let iso = ISO8601.date(from: dict["timestamp"]?.stringValue) { return iso }

        for key in ["timeUnixNano", "observedTimeUnixNano"] {
            if let nanos = dict[key]?.stringValue, let value = Double(nanos) {
                return Date(timeIntervalSince1970: value / 1_000_000_000)
            }
        }

        for key in ["hrTime", "hrTimeObserved"] {
            if let pair = dict[key]?.arrayValue, pair.count == 2,
               case .number(let seconds) = pair[0], case .number(let nanos) = pair[1] {
                return Date(timeIntervalSince1970: seconds + nanos / 1_000_000_000)
            }
        }
        return nil
    }
}
