import AppKit

/// Draws the menu bar icon.
///
/// A custom drawing rather than an SF Symbol, so the fill level is visible in
/// the icon itself. Drawn in colour rather than as a template image, because
/// here colour carries information: green, amber and red mean fill level.
enum IconStyle: String, CaseIterable {
    case ring        // arc fills clockwise
    case segments    // twelve ticks, filled proportionally
    case bar         // vertical capsule, fills from the bottom
}

enum IconRenderer {
    static let size: CGFloat = 17

    /// The icon for a given fill level. When `percent` is nil the level is
    /// unknown, and only the empty outline is drawn — never an invented fill.
    static func image(style: IconStyle, percent: Double?, stale: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let fill = percent.map { min(max($0, 0), 1) }
            let color = fill.map(tint(for:)) ?? NSColor.tertiaryLabelColor
            let track = NSColor.tertiaryLabelColor.withAlphaComponent(0.35)

            switch style {
            case .ring:     drawRing(in: rect, fill: fill, color: color, track: track)
            case .segments: drawSegments(in: rect, fill: fill, color: color, track: track)
            case .bar:      drawBar(in: rect, fill: fill, color: color, track: track)
            }

            // Stale data: a small dot in the top right corner.
            if stale {
                let d: CGFloat = 4.5
                let dot = NSBezierPath(ovalIn: NSRect(x: rect.maxX - d, y: rect.maxY - d,
                                                      width: d, height: d))
                NSColor.systemOrange.setFill()
                dot.fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func tint(for fill: Double) -> NSColor {
        switch fill {
        case ..<0.6:  return .systemGreen
        case ..<0.85: return .systemYellow
        default:      return .systemRed
        }
    }

    // MARK: - Drawing

    private static func drawRing(in rect: NSRect, fill: Double?, color: NSColor, track: NSColor) {
        let width: CGFloat = 2.4
        let radius = (min(rect.width, rect.height) - width) / 2 - 0.5
        let center = NSPoint(x: rect.midX, y: rect.midY)

        let base = NSBezierPath()
        base.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        base.lineWidth = width
        track.setStroke()
        base.stroke()

        guard let fill, fill > 0 else { return }
        // Start at the top and sweep clockwise.
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: radius,
                      startAngle: 90, endAngle: 90 - 360 * fill, clockwise: true)
        arc.lineWidth = width
        arc.lineCapStyle = .round
        color.setStroke()
        arc.stroke()
    }

    private static func drawSegments(in rect: NSRect, fill: Double?, color: NSColor, track: NSColor) {
        let count = 12
        let outer = min(rect.width, rect.height) / 2 - 0.5
        let inner = outer - 3.2
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let lit = Int((fill ?? 0) * Double(count) + 0.5)

        for i in 0..<count {
            // Start at the top, going clockwise.
            let angle = (90 - Double(i) * 360 / Double(count)) * .pi / 180
            let path = NSBezierPath()
            path.move(to: NSPoint(x: center.x + inner * cos(angle),
                                  y: center.y + inner * sin(angle)))
            path.line(to: NSPoint(x: center.x + outer * cos(angle),
                                  y: center.y + outer * sin(angle)))
            path.lineWidth = 2
            path.lineCapStyle = .round
            (i < lit ? color : track).setStroke()
            path.stroke()
        }
    }

    private static func drawBar(in rect: NSRect, fill: Double?, color: NSColor, track: NSColor) {
        let w: CGFloat = 10, h: CGFloat = 15
        let body = NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        let radius: CGFloat = 3

        let outline = NSBezierPath(roundedRect: body.insetBy(dx: 0.75, dy: 0.75),
                                   xRadius: radius, yRadius: radius)
        outline.lineWidth = 1.5
        track.setStroke()
        outline.stroke()

        guard let fill, fill > 0 else { return }
        let inset = body.insetBy(dx: 2.5, dy: 2.5)
        let filled = NSRect(x: inset.minX, y: inset.minY,
                            width: inset.width, height: inset.height * fill)
        let clip = NSBezierPath(roundedRect: inset, xRadius: radius - 1.5, yRadius: radius - 1.5)
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        color.setFill()
        NSBezierPath(rect: filled).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
