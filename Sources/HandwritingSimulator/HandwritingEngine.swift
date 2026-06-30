import CoreText
import AppKit

struct Stroke {
    let path: CGPath
    let length: CGFloat
    let cumulativeStart: CGFloat
}

final class HandwritingEngine {
    func generateStrokes(text: String, font: NSFont, paperSize: CGSize) -> [Stroke] {
        let attrStr = NSAttributedString(string: text, attributes: [.font: font])
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let path = CGPath(rect: CGRect(origin: .zero, size: paperSize), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)

        guard let lines = CTFrameGetLines(frame) as? [CTLine] else { return [] }

        var allPaths: [(path: CGPath, length: CGFloat)] = []
        var y: CGFloat = paperSize.height - font.ascender - 10   // top margin

        for line in lines {
            var lineOrigin = CGPoint.zero
            CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &lineOrigin)
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            let xOffset: CGFloat = 40

            for run in runs {
                let runAttr = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
                let runFont = runAttr[.font] as! NSFont
                let unitsPerEm = CGFloat(CTFontGetUnitsPerEm(runFont))
                let pointSize = runFont.pointSize
                let scale = pointSize / unitsPerEm

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

                    // 1. Scale to point size
                    // 2. Translate to final position (values are in points, NOT divided by scale)
                    var transform = CGAffineTransform(scaleX: scale, y: scale)
                        .translatedBy(x: pos.x, y: pos.y)

                    guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyph, &transform) else {
                        continue
                    }

                    // Decompose the fully transformed path into drawing strokes
                    let subpaths = decompose(path: glyphPath)
                    for sub in subpaths {
                        let len = pathLength(sub)
                        allPaths.append((sub, len))
                    }
                }
            }
            y -= (font.ascender + abs(font.descender) + font.leading + 4)
        }

        // Build strokes with cumulative lengths
        var cumulative: CGFloat = 0
        var strokes: [Stroke] = []
        for (path, len) in allPaths {
            strokes.append(Stroke(path: path, length: len, cumulativeStart: cumulative))
            cumulative += len
        }
        return strokes
    }

    private func decompose(path: CGPath) -> [CGPath] {
        var subpaths: [CGMutablePath] = []
        var current: CGMutablePath?
        path.applyWithBlock { element in
            let pts = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                if let c = current { subpaths.append(c) }
                current = CGMutablePath()
                current?.move(to: pts[0])
            case .addLineToPoint:
                current?.addLine(to: pts[0])
            case .addQuadCurveToPoint:
                current?.addQuadCurve(to: pts[1], control: pts[0])
            case .addCurveToPoint:
                current?.addCurve(to: pts[2], control1: pts[0], control2: pts[1])
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