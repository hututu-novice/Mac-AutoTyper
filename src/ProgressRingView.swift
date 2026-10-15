import AppKit

final class ProgressRingView: NSView {
    var fraction: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let side = min(bounds.width, bounds.height)
        let lineWidth: CGFloat = 13
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(0, (side - lineWidth) / 2 - 2)
        let start: CGFloat = 90
        let end = start - 360 * min(max(fraction, 0), 1)

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        NSColor(calibratedRed: 0.20, green: 0.27, blue: 0.36, alpha: 0.12).setStroke()
        track.stroke()

        if fraction > 0 {
            let value = NSBezierPath()
            value.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
            value.lineWidth = lineWidth
            value.lineCapStyle = .round
            NSColor(calibratedRed: 0.13, green: 0.47, blue: 0.80, alpha: 1).setStroke()
            value.stroke()
        }

        let percentage = "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
        let text = NSAttributedString(string: percentage, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ])
        let size = text.size()
        text.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
    }
}
