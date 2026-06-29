import SwiftUI
import AppKit
import AVFoundation

final class HandwritingViewModel: ObservableObject {
    @Published var inputText: String = """
    Class 11 Physics (Mago’s)
    Q1. A car accelerates from rest at 2 m/s² for 10 s.
    Find the final velocity and distance covered.
    """
    @Published var selectedPaper: PaperType = .lined
    @Published var inkColor: Color = .blue
    @Published var writingSpeed: Double = 1.0
    @Published var isAnimating = false
    @Published var renderedImage: NSImage?
    
    private var strokes: [Stroke] = []
    private var animationTimer: Timer?
    private let engine = HandwritingEngine()
    private let renderer = HandwritingRenderer()
    private let exporter = VideoExporter()
    private var animationStart: Double = 0
    private var totalDuration: Double = 10
    
    func startAnimation() {
        isAnimating = true
        let font = NSFont(name: "Apple Chancery", size: 24) ?? NSFont.systemFont(ofSize: 24)
        strokes = engine.generateStrokes(text: inputText, font: font, paperSize: CGSize(width: 700, height: 500))
        let totalLen = strokes.last?.cumulativeStart ?? 0
        totalDuration = totalLen / (200 * writingSpeed)  // base speed 200 pts/sec
        animationStart = CACurrentMediaTime()
        
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self, self.isAnimating else { return }
            let elapsed = CACurrentMediaTime() - self.animationStart
            let progress = min(elapsed / self.totalDuration, 1.0)
            self.renderedImage = self.renderer.drawStrokes(self.strokes,
                                                           progress: CGFloat(progress),
                                                           paper: self.selectedPaper,
                                                           inkColor: NSColor(self.inkColor),
                                                           size: CGSize(width: 700, height: 500))
            if progress >= 1.0 {
                self.stopAnimation()
            }
        }
    }
    
    func stopAnimation() {
        isAnimating = false
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    func exportMovie() {
        let font = NSFont(name: "Apple Chancery", size: 28) ?? NSFont.systemFont(ofSize: 28)
        let size = CGSize(width: 1920, height: 1080)
        strokes = engine.generateStrokes(text: inputText, font: font, paperSize: size)
        let totalLen = strokes.last?.cumulativeStart ?? 1
        let duration = totalLen / (200 * writingSpeed)
        
        exporter.export(strokes: strokes,
                        paperType: selectedPaper,
                        inkColor: NSColor(inkColor),
                        size: size,
                        duration: duration) { [weak self] tempURL in
            DispatchQueue.main.async {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.quickTimeMovie]
                savePanel.nameFieldStringValue = "Homework_Handwriting.mov"
                savePanel.begin { response in
                    if response == .OK, let destURL = savePanel.url {
                        try? FileManager.default.moveItem(at: tempURL, to: destURL)
                        NSWorkspace.shared.open(destURL)
                    }
                }
            }
        }
    }
}