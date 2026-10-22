import SwiftUI

// MARK: - Hallmark

/// A tiny assay stamp: a metal lozenge with the marque's letter.
struct Hallmark: View {
    let marque: Marque
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(marque.metal)
            RoundedRectangle(cornerRadius: size * 0.15, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: max(0.5, size * 0.04))
                .padding(size * 0.1)
            Text(marque.stamp)
                .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                .foregroundStyle(marque == .noir ? Theme.roseLight : marque.toneInk)
                .rotationEffect(.degrees(-45))
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(45))
        .shadow(color: Color(hex: 0x5A3A30, alpha: 0.25), radius: 2, y: 1)
        .accessibilityLabel("\(marque.displayName) marque")
    }
}

/// The marque as a coloured pill.
struct MarquePill: View {
    let marque: Marque
    var body: some View {
        Pill(text: marque.displayName, fill: marque.tone, ink: marque.toneInk)
    }
}

// MARK: - Arch (cameo window)

struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width / 2
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Cutout

/// A lot's art: the lifted subject with a soft contact shadow, or the photo
/// framed in an arched cameo when it couldn't be lifted.
struct CutoutArt: View {
    let image: UIImage
    let isCameo: Bool
    var marque: Marque = .ivory
    var shadow: Bool = true

    var body: some View {
        if isCameo {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipShape(ArchShape())
                .overlay(ArchShape().stroke(Color.white, lineWidth: 3))
                .overlay(ArchShape().stroke(marque.metal, lineWidth: 1.5).padding(-4))
                .aspectRatio(3 / 4, contentMode: .fit)
                .padding(8)
                .shadow(color: Color(hex: 0x5A3A30, alpha: shadow ? 0.25 : 0), radius: 14, y: 8)
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .shadow(color: Color(hex: 0x5A3A30, alpha: shadow ? 0.28 : 0), radius: 12, y: 10)
        }
    }
}

// MARK: - Spotlight

/// An elliptical pool of light from above that always fades out before the edges.
struct Spotlight: View {
    var color: Color = .white
    var intensity: Double = 0.6

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            RadialGradient(
                colors: [color.opacity(intensity), color.opacity(intensity * 0.35), .clear],
                center: .top, startRadius: 0, endRadius: w / 2
            )
            .frame(width: w, height: w / 2)
            .scaleEffect(x: 1, y: max(1, h / (w / 2)), anchor: .top)
            .frame(width: w, height: h, alignment: .top)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Palette backdrop

/// A slowly breathing mesh gradient: the cat's own coat, washed toward pearl.
struct PaletteBackdrop: View {
    let palette: [Swatch]
    var marque: Marque = .ivory
    var animated: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if animated && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                mesh(t: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            mesh(t: 0)
        }
    }

    private func mesh(t: Double) -> some View {
        let c = Self.colors(for: palette, marque: marque)
        let wobble = Float(sin(t * 0.35)) * 0.08
        let wobble2 = Float(cos(t * 0.27)) * 0.07
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5 + wobble, 0], [1, 0],
                [0, 0.5 + wobble2], [0.5 - wobble, 0.45 + wobble2], [1, 0.5 - wobble2],
                [0, 1], [0.5 + wobble2, 1], [1, 1],
            ],
            colors: [c[3], c[1], c[3], c[2], c[0], c[2], c[4], c[2], c[4]]
        )
    }

    /// Centre, mid, edge, corner, far corner. Noir lots keep a deep plum
    /// ground — the rarest cards are the dark ones.
    static func colors(for palette: [Swatch], marque: Marque = .ivory) -> [Color] {
        let swatches = palette.isEmpty ? Swatch.houseDefault : palette
        let primary = swatches[0]
        let accent = swatches.count > 1 ? swatches[1] : primary
        let third = swatches.count > 2 ? swatches[2] : accent

        func mix(_ s: Swatch, with base: SIMD3<Double>, _ amount: Double) -> Color {
            let m = SIMD3(s.red, s.green, s.blue) * (1 - amount) + base * amount
            return Color(.sRGB, red: m.x, green: m.y, blue: m.z)
        }

        if marque == .noir {
            let plum = SIMD3<Double>(0.16, 0.13, 0.19)
            return [mix(primary, with: plum, 0.55), mix(accent, with: plum, 0.7), mix(third, with: plum, 0.8),
                    mix(primary, with: plum, 0.88), Color(hex: 0x1C171F)]
        }
        let pearl = SIMD3<Double>(0.99, 0.96, 0.94)
        let blush = SIMD3<Double>(0.97, 0.88, 0.85)
        let lilac = SIMD3<Double>(0.92, 0.9, 0.97)
        return [mix(accent, with: pearl, 0.62), mix(primary, with: blush, 0.55), mix(third, with: pearl, 0.7),
                mix(primary, with: lilac, 0.6), mix(accent, with: blush, 0.72)]
    }
}

// MARK: - Foil

/// Tilt-tracking foil sheen over art. Overlay-blended on light cards, additive on Noir.
struct FoilSheen: View {
    var strength: Double
    var hueShift: Double = 0
    var marque: Marque = .gold
    @Environment(Motion.self) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tilt = reduceMotion ? CGSize(width: 0.2, height: 0) : motion.tilt
        let iridescence = marque.foilIridescence
        let warmth = marque.foilWarmth
        Rectangle()
            .fill(.white)
            .visualEffect { content, proxy in
                content.colorEffect(ShaderLibrary.foilSheen(
                    .float2(proxy.size),
                    .float2(Float(tilt.width), Float(tilt.height)),
                    .float(Float(strength)),
                    .float(Float(hueShift)),
                    .float(Float(iridescence)),
                    .float(Float(warmth))
                ))
            }
            .blendMode(marque == .noir ? .plusLighter : .overlay)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Moves content slightly against the tilt for depth.
struct TiltParallax: ViewModifier {
    var depth: CGFloat
    @Environment(Motion.self) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let t = reduceMotion ? .zero : motion.tilt
        content.offset(x: t.width * depth, y: t.height * depth * 0.6)
    }
}

extension View {
    func tiltParallax(_ depth: CGFloat) -> some View { modifier(TiltParallax(depth: depth)) }

    /// Centres a decorative layer at a fixed size without letting it widen
    /// the layout around it (it may overflow the screen, clipped).
    func centered(size: CGFloat) -> some View {
        GeometryReader { proxy in
            self.frame(width: size, height: size)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

// MARK: - Glyph reveal

/// Reveals text glyph by glyph: each one sharpens from a blur and settles.
struct GlyphReveal: TextRenderer, Animatable {
    var progress: Double
    var spread: Double = 0.5

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let slices = layout.flatMap { $0 }.flatMap { $0 }
        let count = Double(max(slices.count, 1))
        for (i, slice) in slices.enumerated() {
            let start = Double(i) / count * (1 - spread)
            let local = min(1, max(0, (progress - start) / spread))
            let eased = 1 - pow(1 - local, 3)
            var copy = context
            copy.opacity = eased
            if eased < 1 { copy.addFilter(.blur(radius: (1 - eased) * 5)) }
            copy.translateBy(x: 0, y: (1 - eased) * 8)
            copy.draw(slice)
        }
    }
}

// MARK: - Number ticker

struct Ticker: View {
    let value: Int
    var font: Font = Theme.number(26)
    var suffix: String = " gns"

    var body: some View {
        Text("\(value.formatted())\(suffix)")
            .font(font)
            .contentTransition(.numericText(value: Double(value)))
    }
}
