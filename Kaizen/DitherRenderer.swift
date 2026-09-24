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

    enum Edge: Int {
        case top, bottom, left, right
    }

    enum Corner: Int {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    enum Piece: Hashable {
        case edge(Edge)
        case corner(Corner)
    }

    private static var cache: [String: NSImage] = [:]
    /// Straight alpha at the outer edge.
    private static let peak = 0.3

    static func image(
        piece: Piece,
        pixelSize: (width: Int, height: Int),
        pointSize: CGSize,
        pixelOrigin: (x: Int, y: Int)
    ) -> NSImage {
        let width = max(8, pixelSize.width)
        let height = max(8, pixelSize.height)
        let key = "v8-\(pieceKey(piece))-\(width)x\(height)-\(pixelOrigin.x),\(pixelOrigin.y)"
        if let cached = cache[key] { return cached }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ), let bytes = rep.bitmapData else {
            return NSImage(size: pointSize)
        }

        let bytesPerRow = rep.bytesPerRow
        let lastX = Double(width - 1)
        let lastY = Double(height - 1)

        for y in 0..<height {
            for x in 0..<width {
                let dist = distance(piece: piece, x: Double(x), y: Double(y), lastX: lastX, lastY: lastY)
                let reach = edgeReach(piece: piece, lastX: lastX, lastY: lastY)
                // 1 at the screen edge, 0 at the inner rim. The inner slice stays
                // clear so the strip does not end on a hard line.
                let t = max(0, 1 - dist / reach)
                let u = min(1, t / 0.8)
                let smooth = u * u * (3 - 2 * u)
                let vignette = smooth * peak
                let gx = pixelOrigin.x + x
                let gy = pixelOrigin.y + y
                let threshold = (Double(bayer8[gy & 7][gx & 7]) + 0.5) / 64.0
                let grain = (threshold - 0.5) * 0.04 * smooth
                let alpha = min(1, max(0, vignette + grain))
                let i = y * bytesPerRow + x * 4
                bytes[i] = 0
                bytes[i + 1] = 0
                bytes[i + 2] = 0
                bytes[i + 3] = UInt8((alpha * 255).rounded())
            }
        }

        let image = NSImage(size: pointSize)
        image.addRepresentation(rep)
        cache[key] = image
        return image
    }

    private static func pieceKey(_ piece: Piece) -> String {
        switch piece {
        case .edge(let edge): "e\(edge.rawValue)"
        case .corner(let corner): "c\(corner.rawValue)"
        }
    }

    private static func edgeReach(piece: Piece, lastX: Double, lastY: Double) -> Double {
        switch piece {
        case .edge(.top), .edge(.bottom), .corner:
            return max(1, lastY)
        case .edge(.left), .edge(.right):
            return max(1, lastX)
        }
    }

    /// Distance from the outer screen edge. Corners use min(dx, dy) so they match the strips.
    private static func distance(
        piece: Piece,
        x: Double,
        y: Double,
        lastX: Double,
        lastY: Double
    ) -> Double {
        switch piece {
        case .edge(.top):
            return y
        case .edge(.bottom):
            return lastY - y
        case .edge(.left):
            return x
        case .edge(.right):
            return lastX - x
        case .corner(.topLeft):
            return min(x, y)
        case .corner(.topRight):
            return min(lastX - x, y)
        case .corner(.bottomLeft):
            return min(x, lastY - y)
        case .corner(.bottomRight):
            return min(lastX - x, lastY - y)
        }
    }
}
