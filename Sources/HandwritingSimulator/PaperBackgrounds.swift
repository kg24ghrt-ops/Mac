import AppKit

enum PaperType: String, CaseIterable {
    case lined, graph, blank
}

enum PaperBackgrounds {
    private static var cachedImages: [PaperType: NSImage] = [:]

    static func image(for type: PaperType, size: CGSize) -> NSImage? {
        // Use a reasonable default size to generate the texture once, then tile
        let defaultSize = CGSize(width: 800, height: 600)
        if let cached = cachedImages[type], cached.size == size {
            return cached
        }

        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        // Draw a realistic paper base
        drawRealisticPaperBase(in: CGRect(origin: .zero, size: size))

        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }

        switch type {
        case .lined:
            drawLined(ctx: ctx, size: size)
        case .graph:
            drawGraph(ctx: ctx, size: size)
        case .blank:
            // Already drawn by base texture
            break
        }
        cachedImages[type] = image
        return image
    }

    private static func drawRealisticPaperBase(in rect: CGRect) {
        // Soft beige/cream background
        let baseColor = NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.92, alpha: 1.0)
        baseColor.setFill()
        rect.fill()

        // Add subtle fiber noise (grains)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = Int(rect.width)
        let h = Int(rect.height)
        // Low-res grain bitmap
        let grainSize = 4
        let cols = w / grainSize
        let rows = h / grainSize
        for y in 0..<rows {
            for x in 0..<cols {
                let brightness = CGFloat.random(in: 0.93...0.99)
                let color = NSColor(white: brightness, alpha: 0.3)
                color.setFill()
                let grainRect = CGRect(x: x * grainSize, y: y * grainSize, width: grainSize, height: grainSize)
                grainRect.fill()
            }
        }

        // Add very faint spots (stains)
        for _ in 0..<8 {
            let spotX = CGFloat.random(in: 0...rect.width)
            let spotY = CGFloat.random(in: 0...rect.height)
            let spotRadius = CGFloat.random(in: 20...80)
            let spotAlpha = CGFloat.random(in: 0.02...0.06)
            let spotColor = NSColor(calibratedRed: 0.8, green: 0.75, blue: 0.65, alpha: spotAlpha)
            spotColor.setFill()
            ctx.fillEllipse(in: CGRect(x: spotX - spotRadius, y: spotY - spotRadius, width: spotRadius*2, height: spotRadius*2))
        }
    }

    private static func drawLined(ctx: CGContext, size: CGSize) {
        // Light blue horizontal lines
        ctx.setStrokeColor(NSColor(calibratedRed: 0.6, green: 0.7, blue: 0.9, alpha: 0.7).cgColor)
        ctx.setLineWidth(0.7)
        let spacing: CGFloat = 28
        var y: CGFloat = spacing
        while y < size.height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: size.width, y: y))
            ctx.strokePath()
            y += spacing
        }
        // Red margin line
        ctx.setStrokeColor(NSColor.red.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(1.0)
        ctx.move(to: CGPoint(x: 40, y: 0))
        ctx.addLine(to: CGPoint(x: 40, y: size.height))
        ctx.strokePath()

        // Hole punches
        let holeRadius: CGFloat = 6
        ctx.setFillColor(NSColor(white: 0.88, alpha: 1.0).cgColor)
        for sign in [-1, 1] {
            let center = CGPoint(x: 20, y: size.height * 0.5 + CGFloat(sign) * 120)
            ctx.addArc(center: center, radius: holeRadius, startAngle: 0, endAngle: .pi*2, clockwise: false)
            ctx.fillPath()
        }
    }

    private static func drawGraph(ctx: CGContext, size: CGSize) {
        ctx.setStrokeColor(NSColor(calibratedRed: 0.7, green: 0.8, blue: 0.95, alpha: 0.6).cgColor)
        ctx.setLineWidth(0.5)
        let gridSize: CGFloat = 20
        var x: CGFloat = gridSize
        while x < size.width {
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: size.height))
            ctx.strokePath()
            x += gridSize
        }
        var y: CGFloat = gridSize
        while y < size.height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: size.width, y: y))
            ctx.strokePath()
            y += gridSize
        }
    }
}