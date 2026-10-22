import UIKit

/// Reads a coat's palette: k-means over the subject's opaque pixels, each
/// cluster named from the couture colour library.
enum PaletteExtractor {

    static func palette(of image: UIImage, isCameo: Bool, maxSwatches: Int = 4) -> [Swatch] {
        let samples = sample(image, isCameo: isCameo)
        guard samples.count >= 12 else { return Swatch.houseDefault }
        let clusters = kMeans(samples, k: 6, iterations: 12)
        return finalize(clusters, total: samples.count, maxSwatches: maxSwatches)
    }

    typealias RGB = SIMD3<Double>

    struct Cluster {
        var center: RGB
        var count: Int
    }

    // MARK: Sampling

    static func sample(_ image: UIImage, isCameo: Bool, side: Int = 56) -> [RGB] {
        guard let cg = image.cgImage else { return [] }
        let aspect = Double(cg.width) / Double(max(cg.height, 1))
        let w = aspect >= 1 ? side : max(8, Int(Double(side) * aspect))
        let h = aspect >= 1 ? max(8, Int(Double(side) / aspect)) : side
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var out: [RGB] = []
        out.reserveCapacity(w * h)
        for y in 0..<h {
            for x in 0..<w {
                if isCameo {
                    // Centre-weighted ellipse: the subject is usually in the middle.
                    let nx = (Double(x) + 0.5) / Double(w) - 0.5
                    let ny = (Double(y) + 0.5) / Double(h) - 0.5
                    if nx * nx / 0.12 + ny * ny / 0.16 > 1 { continue }
                }
                let i = (y * w + x) * 4
                let a = Double(pixels[i + 3])
                guard a > 200 else { continue }
                out.append(RGB(Double(pixels[i]) / a, Double(pixels[i + 1]) / a, Double(pixels[i + 2]) / a))
            }
        }
        return out
    }

    // MARK: Clustering

    /// Deterministic k-means++ style seeding (farthest-point) + Lloyd iterations.
    static func kMeans(_ points: [RGB], k: Int, iterations: Int) -> [Cluster] {
        guard !points.isEmpty else { return [] }
        let mean = points.reduce(RGB.zero, +) / Double(points.count)
        var centers: [RGB] = [points.min { distance($0, mean) < distance($1, mean) }!]
        while centers.count < min(k, points.count) {
            let next = points.max { a, b in
                centers.map { distance(a, $0) }.min()! < centers.map { distance(b, $0) }.min()!
            }!
            centers.append(next)
        }

        var assignments = [Int](repeating: 0, count: points.count)
        for _ in 0..<iterations {
            for (i, p) in points.enumerated() {
                var best = 0, bestD = Double.infinity
                for (c, center) in centers.enumerated() {
                    let d = distance(p, center)
                    if d < bestD { bestD = d; best = c }
                }
                assignments[i] = best
            }
            var sums = [RGB](repeating: .zero, count: centers.count)
            var counts = [Int](repeating: 0, count: centers.count)
            for (i, p) in points.enumerated() {
                sums[assignments[i]] += p
                counts[assignments[i]] += 1
            }
            for c in centers.indices where counts[c] > 0 {
                centers[c] = sums[c] / Double(counts[c])
            }
        }
        var counts = [Int](repeating: 0, count: centers.count)
        for a in assignments { counts[a] += 1 }
        return zip(centers, counts).map { Cluster(center: $0, count: $1) }.filter { $0.count > 0 }
    }

    static func finalize(_ clusters: [Cluster], total: Int, maxSwatches: Int) -> [Swatch] {
        var sorted = clusters.sorted { $0.count > $1.count }
        // Merge near-duplicates so the palette reads as distinct colours.
        var merged: [Cluster] = []
        for c in sorted {
            if let i = merged.firstIndex(where: { distance($0.center, c.center) < 0.012 }) {
                let n = Double(merged[i].count + c.count)
                merged[i].center = (merged[i].center * Double(merged[i].count) + c.center * Double(c.count)) / n
                merged[i].count += c.count
            } else {
                merged.append(c)
            }
        }
        sorted = merged.sorted { $0.count > $1.count }
        var usedNames = Set<String>()
        var swatches: [Swatch] = []
        for c in sorted where swatches.count < maxSwatches {
            let share = Double(c.count) / Double(max(total, 1))
            guard share >= 0.03 || swatches.count < 2 else { continue }
            let name = CoutureColors.name(for: c.center, excluding: usedNames)
            usedNames.insert(name)
            swatches.append(Swatch(name: name, red: c.center.x, green: c.center.y, blue: c.center.z, share: share))
        }
        return swatches
    }

    static func distance(_ a: RGB, _ b: RGB) -> Double {
        let d = a - b
        // Weighted RGB ("redmean"-ish) — perceptual enough for naming swatches.
        return 2 * d.x * d.x + 4 * d.y * d.y + 3 * d.z * d.z
    }
}

/// A couture colour library, matched in CIE Lab.
enum CoutureColors {
    static let library: [(name: String, hex: UInt32)] = [
        ("Ivory Silk", 0xF2EBDD), ("Chantilly", 0xEFE6D2), ("Pearl", 0xE6E1D6), ("Bone China", 0xE9E4DA),
        ("Oyster", 0xD9D0C1), ("Silver Fox", 0xB8B6B1), ("Smoked Pearl", 0xA8A39A), ("Dove", 0x8F8B85),
        ("Flannel", 0x7D7A75), ("Pewter", 0x6E6D6A), ("Slate", 0x5B6168), ("Graphite", 0x444446),
        ("Velvet Noir", 0x1E1A1C), ("Onyx", 0x141414), ("Jet", 0x0B0B0D), ("Espresso", 0x2B1E17),
        ("Sable", 0x3F2E26), ("Truffle", 0x4A3A30), ("Mocha", 0x6A4E3D), ("Mink", 0x7C6455),
        ("Tobacco", 0x6B4A2B), ("Chestnut", 0x6E3B23), ("Cognac", 0x9A4F25), ("Toffee", 0xA0703F),
        ("Camel", 0xB8875A), ("Fawn", 0xC4A484), ("Biscuit", 0xD6B98C), ("Wheat", 0xDCC7A1),
        ("Sand", 0xCDB794), ("Champagne", 0xE3D2B0), ("Honey", 0xD9A65B), ("Butterscotch", 0xCC9255),
        ("Saffron", 0xE09A3A), ("Apricot", 0xE3A066), ("Marmalade", 0xD2752E), ("Copper", 0xB5652E),
        ("Cinnamon", 0xA2552C), ("Burnt Sienna", 0xA0522D), ("Blush", 0xE3B7B0), ("Rose Quartz", 0xD9A6A6),
        ("Dusty Rose", 0xC08A88), ("Bordeaux", 0x6A2433), ("Duck Egg", 0xA8C3BC), ("Celadon", 0xACC8A8),
        ("Sage", 0x9AAE8F), ("Olive", 0x7C7A48), ("Moss", 0x5E6B45), ("Teal", 0x3F7C7A),
        ("Prussian", 0x2A4559), ("Midnight", 0x1C2433), ("Cornflower", 0x7C95C7), ("Lavender", 0xB4A7CF),
        ("Wisteria", 0x8E7FB0), ("Aubergine", 0x3E2A3F),
    ]

    private static let labLibrary: [(name: String, lab: SIMD3<Double>)] = library.map { entry in
        let rgb = SIMD3<Double>(
            Double((entry.hex >> 16) & 0xFF) / 255,
            Double((entry.hex >> 8) & 0xFF) / 255,
            Double(entry.hex & 0xFF) / 255
        )
        return (entry.name, lab(rgb))
    }

    static func name(for rgb: SIMD3<Double>, excluding used: Set<String> = []) -> String {
        let target = lab(rgb)
        let ranked = labLibrary.sorted { delta($0.lab, target) < delta($1.lab, target) }
        return (ranked.first { !used.contains($0.name) } ?? ranked[0]).name
    }

    private static func delta(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b
        return d.x * d.x + d.y * d.y + d.z * d.z
    }

    static func lab(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let r = lin(rgb.x), g = lin(rgb.y), b = lin(rgb.z)
        let x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
        let y = (r * 0.2126 + g * 0.7152 + b * 0.0722)
        let z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116.0 }
        return SIMD3(116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))
    }
}
