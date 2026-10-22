import SwiftUI

/// A hand-poured wax seal in the marque's colour, embossed with the house "C".
/// `cracks` (0...3) draws fracture lines as the seal is tapped.
struct WaxSeal: View {
    let marque: Marque
    var cracks: Int = 0
    var seed: Double = 0.37

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let wax = marque.wax

            // Irregular poured edge.
            var blob = Path()
            let steps = 72
            for i in 0...steps {
                let a = Double(i) / Double(steps) * .pi * 2
                let wobble = 1 + 0.045 * sin(5 * a + seed * 9) + 0.025 * sin(11 * a + seed * 3) + 0.015 * sin(23 * a)
                let p = CGPoint(x: center.x + cos(a) * r * 0.96 * wobble, y: center.y + sin(a) * r * 0.96 * wobble)
                i == 0 ? blob.move(to: p) : blob.addLine(to: p)
            }
            blob.closeSubpath()

            var shadowed = context
            shadowed.addFilter(.shadow(color: .black.opacity(0.45), radius: r * 0.12, x: 0, y: r * 0.08))
            shadowed.fill(blob, with: .color(wax.base))
            context.fill(blob, with: .radialGradient(
                Gradient(colors: [wax.light, wax.base, wax.deep]),
                center: CGPoint(x: center.x - r * 0.3, y: center.y - r * 0.35),
                startRadius: 0, endRadius: r * 1.4
            ))

            // Pressed inner disc.
            let inner = Path(ellipseIn: CGRect(x: center.x - r * 0.68, y: center.y - r * 0.68, width: r * 1.36, height: r * 1.36))
            context.fill(inner, with: .radialGradient(
                Gradient(colors: [wax.base, wax.deep.opacity(0.9)]),
                center: CGPoint(x: center.x + r * 0.2, y: center.y + r * 0.25),
                startRadius: 0, endRadius: r * 0.9
            ))
            context.stroke(inner.offsetBy(dx: 0, dy: r * 0.02), with: .color(wax.light.opacity(0.55)), lineWidth: r * 0.035)
            context.stroke(inner, with: .color(wax.deep), lineWidth: r * 0.03)

            // Ring of beads.
            for i in 0..<28 {
                let a = Double(i) / 28 * .pi * 2
                let p = CGPoint(x: center.x + cos(a) * r * 0.58, y: center.y + sin(a) * r * 0.58)
                let dot = Path(ellipseIn: CGRect(x: p.x - r * 0.022, y: p.y - r * 0.022, width: r * 0.044, height: r * 0.044))
                context.fill(dot, with: .color(wax.light.opacity(0.5)))
            }

            // Embossed monogram: light lip above, shadowed letter below.
            let monogram = Text("C").font(.custom("Didot-Bold", size: r * 0.95))
            let lip = context.resolve(monogram.foregroundStyle(wax.light.opacity(0.7)))
            let letter = context.resolve(monogram.foregroundStyle(wax.deep))
            context.draw(lip, at: CGPoint(x: center.x - r * 0.02, y: center.y - r * 0.03))
            context.draw(letter, at: center)

            // Specular.
            let spec = Path(ellipseIn: CGRect(x: center.x - r * 0.62, y: center.y - r * 0.74, width: r * 0.5, height: r * 0.24))
            var soft = context
            soft.addFilter(.blur(radius: r * 0.08))
            soft.fill(spec.applying(CGAffineTransform(rotationAngle: -0.4).translatedBy(x: 0, y: 0)), with: .color(.white.opacity(0.35)))

            // Fractures.
            if cracks > 0 {
                var crack = Path()
                let rays: [(Double, [Double])] = [
                    (-0.6, [0.15, 0.45, 0.8, 1.0]),
                    (2.4, [0.1, 0.5, 0.75, 1.0]),
                    (1.1, [0.2, 0.55, 0.95]),
                ]
                for (index, ray) in rays.prefix(cracks).enumerated() {
                    var p = center
                    crack.move(to: p)
                    for (j, reach) in ray.1.enumerated() {
                        let jitter = (j % 2 == 0 ? 0.22 : -0.18) * (index % 2 == 0 ? 1 : -1)
                        let a = ray.0 + jitter
                        p = CGPoint(x: center.x + cos(a) * r * reach, y: center.y + sin(a) * r * reach)
                        crack.addLine(to: p)
                    }
                }
                context.stroke(crack, with: .color(wax.light.opacity(0.6)), style: StrokeStyle(lineWidth: r * 0.035, lineCap: .round, lineJoin: .round))
                context.stroke(crack.offsetBy(dx: r * 0.015, dy: r * 0.02), with: .color(.black.opacity(0.65)), style: StrokeStyle(lineWidth: r * 0.03, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Guilloche

/// Banknote-style engraved rosette, drawn procedurally.
struct Guilloche: View {
    var color: Color
    var lineWidth: CGFloat = 0.5
    var petals: Int = 12
    var bands: Int = 3
    var strands: Int = 24
    var amplitude: CGFloat = 0.07

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2
            for band in 0..<bands {
                let base = maxR * (0.55 + 0.4 * CGFloat(band) / CGFloat(max(bands - 1, 1))) * (1 - amplitude)
                // Strands phase-shifted across a full cycle weave into the lattice band.
                for s in 0..<strands {
                    let phase = Double(s) / Double(strands) * .pi * 2
                    var path = Path()
                    let steps = 360
                    for i in 0...steps {
                        let t = Double(i) / Double(steps) * .pi * 2
                        let rr = base * (1 + amplitude * sin(Double(petals) * t + phase))
                        let p = CGPoint(x: center.x + rr * cos(t), y: center.y + rr * sin(t))
                        i == 0 ? path.move(to: p) : path.addLine(to: p)
                    }
                    context.stroke(path, with: .color(color), lineWidth: lineWidth)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A guilloche border band along a rectangle — certificate frame.
struct GuillocheBorder: View {
    var color: Color
    var inset: CGFloat = 14
    var waves: Int = 60

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let perimeter = 2 * (rect.width + rect.height)
            for strand in 0..<6 {
                var path = Path()
                let phase = Double(strand) / 6 * .pi
                let steps = 900
                for i in 0...steps {
                    let d = Double(i) / Double(steps) * perimeter
                    let (point, normal) = Self.walk(rect, distance: d)
                    let offset = sin(d / perimeter * Double(waves) * .pi * 2 + phase) * 4.5
                    let p = CGPoint(x: point.x + normal.dx * offset, y: point.y + normal.dy * offset)
                    i == 0 ? path.move(to: p) : path.addLine(to: p)
                }
                context.stroke(path, with: .color(color), lineWidth: 0.45)
            }
            context.stroke(Path(rect.insetBy(dx: -7, dy: -7)), with: .color(color), lineWidth: 0.8)
            context.stroke(Path(rect.insetBy(dx: 7, dy: 7)), with: .color(color), lineWidth: 0.8)
        }
        .accessibilityHidden(true)
    }

    private static func walk(_ r: CGRect, distance d: Double) -> (CGPoint, CGVector) {
        let w = r.width, h = r.height
        if d < w { return (CGPoint(x: r.minX + d, y: r.minY), CGVector(dx: 0, dy: -1)) }
        if d < w + h { return (CGPoint(x: r.maxX, y: r.minY + (d - w)), CGVector(dx: 1, dy: 0)) }
        if d < 2 * w + h { return (CGPoint(x: r.maxX - (d - w - h), y: r.maxY), CGVector(dx: 0, dy: 1)) }
        return (CGPoint(x: r.minX, y: r.maxY - (d - 2 * w - h)), CGVector(dx: -1, dy: 0))
    }
}

// MARK: - Gold leaf

/// A burst of fluttering gold leaf. Changing `trigger` launches a new burst.
struct GoldLeafBurst: View {
    var trigger: Int
    var count: Int = 70
    var tint: Marque = .gold

    @State private var launchedAt: Date?
    @State private var flakes: [Flake] = []

    struct Flake {
        var x: Double, y: Double, vx: Double, vy: Double
        var size: Double, spin: Double, phase: Double, shade: Double
    }

    var body: some View {
        TimelineView(.animation(paused: launchedAt == nil)) { timeline in
            Canvas { context, size in
                guard let launchedAt else { return }
                let t = timeline.date.timeIntervalSince(launchedAt)
                guard t < 4.5 else { return }
                for f in flakes {
                    let x = size.width * f.x + f.vx * t + sin(t * 3 + f.phase) * 14 * t
                    let y = size.height * f.y + f.vy * t + 260 * t * t
                    let flip = cos(t * f.spin + f.phase)
                    let alpha = max(0, 1 - t / 4.5)
                    var c = context
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(t * f.spin * 0.6 + f.phase))
                    c.scaleBy(x: max(0.08, abs(flip)), y: 1)
                    c.opacity = alpha
                    let rect = CGRect(x: -f.size / 2, y: -f.size * 0.35, width: f.size, height: f.size * 0.7)
                    let colors: [Color] = switch tint {
                    case .platinum: [Color(hex: 0xFFFFFF), Color(hex: 0xC9C6EC), Color(hex: 0xF0DDEB)]
                    case .noir: [Theme.roseLight, Theme.rose, Theme.roseDeep]
                    default: [Color(hex: 0xF8E5B4), Color(hex: 0xE2B65C), Color(hex: 0xB7882C)]
                    }
                    c.fill(Path(roundedRect: rect, cornerRadius: 1.5),
                           with: .color(colors[Int(f.shade * 2.99)]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in launch() }
    }

    private func launch() {
        var rng = SystemRandomNumberGenerator()
        flakes = (0..<count).map { _ in
            let angle = Double.random(in: -.pi * 0.9 ... -.pi * 0.1, using: &rng)
            let speed = Double.random(in: 260...620, using: &rng)
            return Flake(
                x: 0.5 + Double.random(in: -0.06...0.06, using: &rng),
                y: 0.45 + Double.random(in: -0.04...0.04, using: &rng),
                vx: cos(angle) * speed, vy: sin(angle) * speed,
                size: Double.random(in: 5...12, using: &rng),
                spin: Double.random(in: 4...11, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng),
                shade: Double.random(in: 0..<1, using: &rng)
            )
        }
        launchedAt = .now
    }
}
