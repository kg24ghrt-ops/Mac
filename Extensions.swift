import AppKit

extension NSImage {
    convenience init(size: CGSize) {
        self.init(size: size, flipped: false) { rect in
            return true
        }
    }
}