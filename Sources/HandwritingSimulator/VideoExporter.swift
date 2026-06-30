import AVFoundation
import AppKit

final class VideoExporter {
    func export(strokes: [Stroke],
                paperType: PaperType,
                inkColor: NSColor,
                size: CGSize,
                duration: Double,
                completion: @escaping (URL) -> Void) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        guard let writer = try? AVAssetWriter(url: outputURL, fileType: .mov) else {
            print("Cannot create writer"); return
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ])
        
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        let fps = 30
        let totalFrames = Int(duration * Double(fps))
        let renderer = HandwritingRenderer()
        let queue = DispatchQueue(label: "videoExport")
        
        input.requestMediaDataWhenReady(on: queue) { [weak self] in
            guard let self = self else { return }
            for frameIdx in 0..<totalFrames {
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
                let progress = CGFloat(frameIdx) / CGFloat(totalFrames)
                autoreleasepool {
                    let image = renderer.drawStrokes(strokes, progress: progress,
                                                     paper: paperType,
                                                     inkColor: inkColor,
                                                     size: size)
                    if let buffer = self.pixelBuffer(from: image, size: size) {
                        let time = CMTime(value: CMTimeValue(frameIdx), timescale: CMTimeScale(fps))
                        adaptor.append(buffer, withPresentationTime: time)
                    }
                }
            }
            input.markAsFinished()
            writer.finishWriting {
                completion(outputURL)
            }
        }
    }
    
    private func pixelBuffer(from image: NSImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                            kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        else { return nil }
        
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        image.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        return buffer
    }
}