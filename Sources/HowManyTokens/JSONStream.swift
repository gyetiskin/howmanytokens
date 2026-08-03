import Foundation

/// Gemini's telemetry outfile is a run of pretty-printed JSON objects appended
/// back to back — not one object per line. Splitting it means tracking brace
/// depth.
enum JSONStream {
    /// Splits text into top-level JSON objects, skipping braces that appear
    /// inside strings and honouring escape sequences.
    static func splitObjects(_ text: String) -> [Data] {
        var results: [Data] = []
        let bytes = Array(text.utf8)
        var depth = 0
        var start: Int?
        var inString = false
        var escaped = false

        for (index, byte) in bytes.enumerated() {
            if inString {
                if escaped {
                    escaped = false
                } else if byte == 0x5C { // backslash
                    escaped = true
                } else if byte == 0x22 { // "
                    inString = false
                }
                continue
            }

            switch byte {
            case 0x22: // "
                inString = true
            case 0x7B: // {
                if depth == 0 { start = index }
                depth += 1
            case 0x7D: // }
                depth -= 1
                if depth == 0, let s = start {
                    results.append(Data(bytes[s...index]))
                    start = nil
                } else if depth < 0 {
                    // Recover if the file was caught mid-write.
                    depth = 0
                    start = nil
                }
            default:
                break
            }
        }
        return results
    }
}

/// A light helper for walking a JSON tree. The OTLP output shape changes between
/// versions, so we navigate the tree instead of binding tightly to a schema.
enum JSONValue {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    static func parse(_ data: Data) -> JSONValue? {
        guard let raw = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        return convert(raw)
    }

    private static func convert(_ raw: Any) -> JSONValue {
        switch raw {
        case let dict as [String: Any]:
            return .object(dict.mapValues(convert))
        case let arr as [Any]:
            return .array(arr.map(convert))
        case let str as String:
            return .string(str)
        case let num as NSNumber:
            if CFGetTypeID(num) == CFBooleanGetTypeID() { return .bool(num.boolValue) }
            return .number(num.doubleValue)
        default:
            return .null
        }
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let dict) = self else { return nil }
        return dict[key]
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return String(n)
        default: return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .number(let n): return Int(n)
        case .string(let s): return Int(s)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    var arrayValue: [JSONValue]? {
        guard case .array(let a) = self else { return nil }
        return a
    }

    var objectValue: [String: JSONValue]? {
        guard case .object(let o) = self else { return nil }
        return o
    }
}
