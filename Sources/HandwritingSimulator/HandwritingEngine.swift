import CoreText
import AppKit

struct Stroke {
    let path: CGPath
    let length: CGFloat
    let cumulativeStart: CGFloat   // where this stroke begins in the global timeline
}

final class HandwritingEngine {
    func generateStrokes(text: String, font: NSFont, paperSize: CGSize) -> [Stroke] {
        let attrStr = NSAttributedString(string: text, attributes: [.font: font])
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let rectPath = CGPath(rect: CGRect(origin: .zero, size: paperSize), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), rectPath, nil)
        guard let lines = CTFrameGetLines(frame) as? [CTLine] else { return [] }
        
        var allSubpaths: [(path: CGPath, length: CGFloat)] = []
        var y: CGFloat = paperSize.height - font.ascender - 10  // top margin 10
        
        for line in lines {
            var lineOrigin = CGPoint.zero
            CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &lineOrigin)
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            let xOffset: CGFloat = 40  // left margin
            
            for run in runs {
                let runAttributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
                let runFont = runAttributes[.font] as! NSFont
                let glyphCount = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                var positions = [CGPoint](repeating: .zero, count: glyphCount)
                CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
                CTRunGetPositions(run, CFRangeMake(0, 0), &positions)
                
                for i in 0..<glyphCount {
                    let glyph = glyphs[i]
                    var pos = positions[i]
                    pos.x += xOffset
                    pos.y += y
                    if let path = CTFontCreatePathForGlyph(runFont, glyph, nil) {
                        let decomposed = decompose(path: path)
                        for sub in decomposed {
                            var t = CGAffineTransform(translationX: pos.x, y: pos.y)
                            guard let transformed = sub.copy(using: &t) else { continue }
                            let len = pathLength(transformed)
                            allSubpaths.append((transformed, len))
                        }
                    }
                }
            }
            y -= (font.ascender + abs(font.descender) + font.leading + 4)  // line spacing
        }
        
        // Build strokes with cumulative lengths
        var cumulative: CGFloat = 0
        var strokes: [Stroke] = []
        for (path, len) in allSubpaths {
            strokes.append(Stroke(path: path, length: len, cumulativeStart: cumulative))
            cumulative += len
        }
        return strokes
    }
    
    private func decompose(path: CGPath) -> [CGPath] {
        var subpaths: [CGMutablePath] = []
        var current: CGMutablePath?
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                if let c = current { subpaths.append(c) }
                current = CGMutablePath()
                current?.move(to: points[0])
            case .addLineToPoint:
                current?.addLine(to: points[0])
            case .addQuadCurveToPoint:
                current?.addQuadCurve(to: points[1], control: points[0])
            case .addCurveToPoint:
                current?.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closeSubpath:
                current?.closeSubpath()
                if let c = current { subpaths.append(c) }
                current = nil
            @unknown default: break
            }
        }
        if let c = current { subpaths.append(c) }
        return subpaths
    }
    
    private func pathLength(_ path: CGPath) -> CGFloat {
        var length: CGFloat = 0
        var prev: CGPoint?
        path.applyWithBlock { element in
            let pts = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                prev = pts[0]
            case .addLineToPoint:
                if let p = prev { length += hypot(pts[0].x - p.x, pts[0].y - p.y) }
                prev = pts[0]
            case .addQuadCurveToPoint:
                if let p = prev { length += hypot(pts[1].x - p.x, pts[1].y - p.y) }
                prev = pts[1]
            case .addCurveToPoint:
                if let p = prev { length += hypot(pts[2].x - p.x, pts[2].y - p.y) }
                prev = pts[2]
            case .closeSubpath:
                break
            @unknown default: break
            }
        }
        return length
    }
}