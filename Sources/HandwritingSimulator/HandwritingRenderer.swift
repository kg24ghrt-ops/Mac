import AppKit

final class HandwritingRenderer {
    func drawStrokes(_ strokes: [Stroke], progress: CGFloat, paper: PaperType, inkColor: NSColor, size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        // Paper background
        if let bg = PaperBackgrounds.image(for: paper, size: size) {
            bg.draw(in: CGRect(origin: .zero, size: size))
        } else {
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()
        }
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return image }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        
        let globalLength = strokes.last?.cumulativeStart ?? 0
        let drawnLength = globalLength * progress
        
        for stroke in strokes {
            if drawnLength <= stroke.cumulativeStart { continue }  // not started
            
            let remaining = drawnLength - stroke.cumulativeStart
            let fraction = min(remaining / stroke.length, 1.0)    // how much of this stroke is drawn
            
            let pathToDraw: CGPath
            if fraction >= 1.0 {
                pathToDraw = stroke.path
            } else {
                pathToDraw = trimmedPath(stroke.path, fraction: fraction) ?? stroke.path
            }
            drawInkPath(ctx: ctx, path: pathToDraw, color: inkColor)
        }
        
        return image
    }
    
    private func trimmedPath(_ path: CGPath, fraction: CGFloat) -> CGPath? {
        // Sample path into many points, then rebuild path up to desired length
        let total = computeExactLength(path)
        let target = total * fraction
        var length: CGFloat = 0
        var prevPoint: CGPoint?
        let newPath = CGMutablePath()
        var started = false
        
        path.applyWithBlock { element in
            if length >= target { return }
            let pts = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                prevPoint = pts[0]
                if !started { newPath.move(to: pts[0]); started = true }
            case .addLineToPoint:
                guard let prev = prevPoint else { break }
                let segLen = hypot(pts[0].x - prev.x, pts[0].y - prev.y)
                if length + segLen > target {
                    let remaining = target - length
                    let t = remaining / segLen
                    let x = prev.x + (pts[0].x - prev.x) * t
                    let y = prev.y + (pts[0].y - prev.y) * t
                    newPath.addLine(to: CGPoint(x: x, y: y))
                    length = target
                } else {
                    newPath.addLine(to: pts[0])
                    length += segLen
                }
                prevPoint = pts[0]
            // Add curves similarly (simplified here – we skip exact curve cutting for brevity,
            // simply draw the whole curve if length < target, otherwise cut by chord)
            case .addCurveToPoint:
                guard let prev = prevPoint else { break }
                let segLen = hypot(pts[2].x - prev.x, pts[2].y - prev.y)
                if length + segLen <= target {
                    newPath.addCurve(to: pts[2], control1: pts[0], control2: pts[1])
                    length += segLen
                } else {
                    let remaining = target - length
                    let t = remaining / segLen
                    let end = CGPoint(x: prev.x + (pts[2].x - prev.x) * t,
                                      y: prev.y + (pts[2].y - prev.y) * t)
                    newPath.addLine(to: end)  // fallback
                    length = target
                }
                prevPoint = pts[2]
            default:
                break
            }
        }
        return newPath
    }
    
    private func computeExactLength(_ path: CGPath) -> CGFloat {
        var length: CGFloat = 0
        var prev: CGPoint?
        path.applyWithBlock { element in
            let pts = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint: prev = pts[0]
            case .addLineToPoint:
                if let p = prev { length += hypot(pts[0].x - p.x, pts[0].y - p.y) }
                prev = pts[0]
            case .addCurveToPoint:
                if let p = prev { length += hypot(pts[2].x - p.x, pts[2].y - p.y) }
                prev = pts[2]
            default: break
            }
        }
        return length
    }
    
    private func drawInkPath(ctx: CGContext, path: CGPath, color: NSColor) {
        // Realistic ink: draw many small overlapping circles with variable radius and offset
        ctx.saveGState()
        let baseColor = color.cgColor
        let step: CGFloat = 1.5   // distance between points
        let points = samplePath(path, step: step)
        guard points.count > 2 else { return }
        
        for i in 0..<points.count {
            let pt = points[i]
            // Simulate pressure: slower parts thicker, use sine variation
            let pressure = 0.8 + 0.4 * sin(CGFloat(i) * 0.5)
            let radius: CGFloat = (1.5 * pressure) + CGFloat.random(in: -0.15...0.15)
            let offset = CGPoint(x: CGFloat.random(in: -0.5...0.5), y: CGFloat.random(in: -0.5...0.5))
            let center = CGPoint(x: pt.x + offset.x, y: pt.y + offset.y)
            
            // Radial gradient for ink bleeding
            let colors = [baseColor, baseColor.copy(alpha: 0.0)!] as CFArray
            let locations: [CGFloat] = [0.0, 1.0]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                ctx.drawRadialGradient(gradient,
                                       startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: radius * 1.5,
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        }
        ctx.restoreGState()
    }
    
    private func samplePath(_ path: CGPath, step: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        var prevPoint: CGPoint?
        path.applyWithBlock { element in
            let pts = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                points.append(pts[0])
                prevPoint = pts[0]
            case .addLineToPoint:
                if let prev = prevPoint {
                    points.append(contentsOf: interpolate(from: prev, to: pts[0], step: step))
                }
                prevPoint = pts[0]
            case .addCurveToPoint:
                if let prev = prevPoint {
                    // Sample cubic bezier
                    let bezier = CubicBezier(p0: prev, p1: pts[0], p2: pts[1], p3: pts[2])
                    points.append(contentsOf: bezier.sample(step: step))
                }
                prevPoint = pts[2]
            default: break
            }
        }
        return points
    }
    
    private func interpolate(from: CGPoint, to: CGPoint, step: CGFloat) -> [CGPoint] {
        let dist = hypot(to.x - from.x, to.y - from.y)
        let count = max(Int(dist / step), 1)
        var pts: [CGPoint] = []
        for i in 1...count {
            let t = CGFloat(i) / CGFloat(count)
            pts.append(CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
        }
        return pts
    }
}

// Helper for cubic bezier sampling
struct CubicBezier {
    let p0, p1, p2, p3: CGPoint
    func point(at t: CGFloat) -> CGPoint {
        let t1 = 1 - t
        let a = t1 * t1 * t1
        let b = 3 * t1 * t1 * t
        let c = 3 * t1 * t * t
        let d = t * t * t
        return CGPoint(x: a*p0.x + b*p1.x + c*p2.x + d*p3.x,
                       y: a*p0.y + b*p1.y + c*p2.y + d*p3.y)
    }
    func sample(step: CGFloat) -> [CGPoint] {
        let length = hypot(p3.x - p0.x, p3.y - p0.y)
        let count = max(Int(length / step), 4)
        return (1...count).map { point(at: CGFloat($0)/CGFloat(count)) }
    }
}