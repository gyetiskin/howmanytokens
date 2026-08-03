import AppKit

/// Renders the icon candidates onto a single comparison sheet.
/// Usage: HMT_ICON_PREVIEW=/path/preview.png
enum IconPreview {
    private static let samples: [(label: String, percent: Double?, stale: Bool)] = [
        ("15%", 0.15, false), ("45%", 0.45, false), ("72%", 0.72, false),
        ("92%", 0.92, false), ("unknown", nil, false), ("38% stale", 0.38, true)
    ]

    static func render(to path: String) {
        let scale: CGFloat = 3
        let rowH: CGFloat = 46
        let colW: CGFloat = 132
        let headerH: CGFloat = 34
        let labelW: CGFloat = 92
        let themes: [(String, NSAppearance.Name)] = [("Dark", .darkAqua), ("Light", .aqua)]

        let width = labelW + colW * CGFloat(samples.count) + 24
        let blockH = headerH + rowH * CGFloat(IconStyle.allCases.count) + 22
        let height = blockH * CGFloat(themes.count)

        let px = NSSize(width: width * scale, height: height * scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(px.width), pixelsHigh: Int(px.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        ctx.cgContext.scaleBy(x: scale, y: scale)

        for (index, theme) in themes.enumerated() {
            let appearance = NSAppearance(named: theme.1)!
            let top = height - blockH * CGFloat(index + 1)
            appearance.performAsCurrentDrawingAppearance {
                drawBlock(name: theme.0, origin: NSPoint(x: 0, y: top),
                          size: NSSize(width: width, height: blockH),
                          rowH: rowH, colW: colW, headerH: headerH, labelW: labelW)
            }
        }

        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        print("preview written: \(path)")
    }

    private static func drawBlock(name: String, origin: NSPoint, size: NSSize,
                                  rowH: CGFloat, colW: CGFloat, headerH: CGFloat, labelW: CGFloat) {
        // Approximate the menu bar background.
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: origin, size: size)).fill()

        let title = NSRect(x: origin.x + 12, y: origin.y + size.height - 26, width: 300, height: 20)
        draw("\(name) menu bar", in: title, size: 13, weight: .semibold, color: .labelColor)

        for (i, sample) in samples.enumerated() {
            let r = NSRect(x: origin.x + labelW + colW * CGFloat(i),
                           y: origin.y + size.height - headerH - 14, width: colW, height: 16)
            draw(sample.label, in: r, size: 10, weight: .regular, color: .secondaryLabelColor)
        }

        for (rowIndex, style) in IconStyle.allCases.enumerated() {
            let y = origin.y + size.height - headerH - 20 - rowH * CGFloat(rowIndex + 1) + rowH / 2

            draw(style.rawValue, in: NSRect(x: origin.x + 12, y: y - 7, width: labelW - 16, height: 16),
                 size: 12, weight: .medium, color: .labelColor)

            for (i, sample) in samples.enumerated() {
                let x = origin.x + labelW + colW * CGFloat(i) + 14
                let icon = IconRenderer.image(style: style, percent: sample.percent, stale: sample.stale)
                icon.draw(at: NSPoint(x: x, y: y - IconRenderer.size / 2),
                          from: .zero, operation: .sourceOver, fraction: 1)

                let text = sample.percent.map { "C \(sample.stale ? "~" : "")\(Int(($0 * 100).rounded()))%" } ?? "C —"
                draw(text, in: NSRect(x: x + IconRenderer.size + 4, y: y - 8, width: 70, height: 16),
                     size: 12, weight: .regular, color: .labelColor)
            }
        }
    }

    private static func draw(_ text: String, in rect: NSRect, size: CGFloat,
                             weight: NSFont.Weight, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        NSAttributedString(string: text, attributes: attrs).draw(in: rect)
    }
}
