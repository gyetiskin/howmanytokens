import Foundation

/// Produces the usage state for one provider.
///
/// `manualLimit` applies only to sources where the provider does not report a
/// real percentage (Gemini). If the user has not entered a limit, the source
/// produces no percentage at all — it reports the token count and leaves the
/// percentage blank.
protocol UsageSource: AnyObject, Sendable {
    var provider: Provider { get }
    func load(manualLimit: Int) -> ProviderUsage
}

/// Avoids re-parsing files that have not changed, comparing size and
/// modification date. Access is confined to a single parsing queue, so no lock
/// is required.
final class FileCache: @unchecked Sendable {
    private struct Entry {
        let size: Int
        let modified: Date
        let events: [UsageEvent]
    }

    private var entries: [String: Entry] = [:]

    func events(for url: URL, parse: (URL) -> [UsageEvent]) -> [UsageEvent] {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.intValue ?? -1
        let modified = (attrs?[.modificationDate] as? Date) ?? .distantPast

        if let cached = entries[url.path], cached.size == size, cached.modified == modified {
            return cached.events
        }

        let parsed = parse(url)
        entries[url.path] = Entry(size: size, modified: modified, events: parsed)
        return parsed
    }
}

enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return withFraction.date(from: string) ?? plain.date(from: string)
    }
}
