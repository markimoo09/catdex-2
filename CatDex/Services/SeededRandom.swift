import Foundation
import UIKit

/// SplitMix64 — tiny, fast, deterministic. Same seed, same cat.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[Int(next() % UInt64(items.count))]
    }
}

/// FNV-1a over a 16×16 downsample — stable for identical photos.
enum ImageFingerprint {
    static func seed(for image: UIImage) -> UInt64 {
        let side = 16
        guard let cg = image.cgImage else { return 0xCBF2_9CE4_8422_2325 }
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0xCBF2_9CE4_8422_2325 }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in pixels {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01B3
        }
        return hash
    }
}
