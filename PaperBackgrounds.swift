import AppKit

enum PaperType: String, CaseIterable {
    case lined, graph, blank
}

enum PaperBackgrounds {
    static func image(for type: PaperType, size: CGSize) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        // Base white
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }
        
        switch type {
        case .lined:
            drawLined(ctx: ctx, size: size)
        case .graph:
            drawGraph(ctx: ctx, size: size)
        case .blank:
            drawBlankTexture(ctx: ctx, size: size)
        }
        return image
    }
    
    private static func drawLined(ctx: CGContext, size: CGSize) {
        // Horizontal lines
        ctx.setStrokeColor(NSColor(calibratedWhite: 0.8, alpha: 0.7).cgColor)
        ctx.setLineWidth(0.8)
        let spacing: CGFloat = 28
        var y: CGFloat = spacing
        while y < size.height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: size.width, y: y))
            ctx.strokePath()
            y += spacing
        }
        // Red margin
        ctx.setStrokeColor(NSColor.red.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(1.2)
        ctx.move(to: CGPoint(x: 40, y: 0))
        ctx.addLine(to: CGPoint(x: 40, y: size.height))
        ctx.strokePath()
        
        // Hole punches
        let holeRadius: CGFloat = 6
        let holeY = size.height * 0.5
        ctx.setFillColor(NSColor(white: 0.9).cgColor)
        for sign in [-1, 1] {
            let center = CGPoint(x: 20, y: holeY + CGFloat(sign) * 120)
            ctx.addArc(center: center, radius: holeRadius, startAngle: 0, endAngle: .pi*2, clockwise: false)
            ctx.fillPath()
        }
    }
    
    private static func drawGraph(ctx: CGContext, size: CGSize) {
        ctx.setStrokeColor(NSColor(calibratedWhite: 0.85, alpha: 0.6).cgColor)
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
    
    private static func drawBlankTexture(ctx: CGContext, size: CGSize) {
        // Subtle noise for paper texture
        let scale = 4
        let w = Int(size.width) / scale
        let h = Int(size.height) / scale
        guard let context = CGContext(data: nil, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        for y in 0..<h {
            for x in 0..<w {
                let brightness = UInt8.random(in: 245...255)
                context.setFillColor(gray: CGFloat(brightness)/255, alpha: 1)
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        guard let cgImage = context.makeImage() else { return }
        let rect = CGRect(origin: .zero, size: size)
        ctx.draw(cgImage, in: rect)
    }
}