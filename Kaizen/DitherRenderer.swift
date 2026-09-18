import AppKit

@MainActor
enum DitherRenderer {
    private static let bayer8: [[UInt8]] = [
        [0, 32, 8, 40, 2, 34, 10, 42],
        [48, 16, 56, 24, 50, 18, 58, 26],
        [12, 44, 4, 36, 14, 46, 6, 38],
        [60, 28, 52, 20, 62, 30, 54, 22],
        [3, 35, 11, 43, 1, 33, 9, 41],
        [51, 19, 59, 27, 49, 17, 57, 25],
        [15, 47, 7, 39, 13, 45, 5, 37],
        [63, 31, 55, 23, 61, 29, 53, 21]
    ]

    enum Corner: Int {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private static var cache: [String: NSImage] = [:]

    static func cornerImage(corner: Corner, pointSize: CGFloat, scale: CGFloat) -> NSImage {
        let pixel = max(64, Int((pointSize * scale).rounded()))
        let key = "black-36-\(corner.rawValue)-\(pixel)"
        if let cached = cache[key] { return cached }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixel,
            pixelsHigh: pixel,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ), let bytes = rep.bitmapData else {
            return NSImage(size: NSSize(width: pointSize, height: pointSize))
        }

        let bytesPerRow = rep.bytesPerRow
        let peak = 0.36
        let radius = Double(pixel) * 1.12
        let last = Double(pixel - 1)

        for y in 0..<pixel {
            for x in 0..<pixel {
                let originX: Double
                let originY: Double
                switch corner {
                case .topLeft:
                    originX = 0
                    originY = 0
                case .topRight:
                    originX = last
                    originY = 0
                case .bottomLeft:
                    originX = 0
                    originY = last
                case .bottomRight:
                    originX = last
                    originY = last
                }
                let dist = hypot(Double(x) - originX, Double(y) - originY)
                let falloff = max(0, 1 - dist / radius)
                let vignette = pow(falloff, 1.35) * peak
                let threshold = (Double(bayer8[y & 7][x & 7]) + 0.5) / 64.0
                let alpha = min(1, max(0, vignette + (threshold - 0.5) * 0.06))
                let i = y * bytesPerRow + x * 4
                bytes[i] = 0
                bytes[i + 1] = 0
                bytes[i + 2] = 0
                bytes[i + 3] = UInt8((alpha * 255).rounded())
            }
        }

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.addRepresentation(rep)
        cache[key] = image
        return image
    }
}
