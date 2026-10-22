import SwiftUI

/// The lot arrives sealed in an envelope. Tap the wax three times to break it;
/// the flap lifts and the card rises.
struct UnsealView: View {
    let lot: LotPresentation
    var onAdd: () -> Void
    var onRelease: () -> Void

    enum Phase: Int, Comparable {
        case sealed, broken, open, rising, presented, departing
        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    @State private var phase: Phase = .sealed
    @State private var taps = 0
    @State private var flapAngle = 0.0
    @State private var flapInside = false
    @State private var sealPulse = false
    @State private var leaf = 0
    @State private var nameReveal = 0.0
    @State private var shownValue = 0
    @State private var hapticTick = 0

    var body: some View {
        GeometryReader { proxy in
            let W = min(proxy.size.width - 56, 330)
            let H = W * 0.66
            let cardW = min(proxy.size.width - 72, 300)
            let cardH = cardW * 4 / 3
            let insideScale = min(W * 0.78 / cardW, H * 0.86 / cardH)
            let envY = proxy.size.height * 0.08

            ZStack {
                background

                // Envelope, card and seal share one coordinate space (centre-origin offsets).
                ZStack {
                    envelopeBack(W: W, H: H)
                        .offset(y: envelopeOffset(envY, proxy))
                        .zIndex(0)

                    if flapInside {
                        flap(W: W, H: H).offset(y: envelopeOffset(envY, proxy) - H / 2).zIndex(1)
                    }

                    LotCard(lot: lot)
                        .frame(width: cardW)
                        .scaleEffect(cardScale(insideScale))
                        .offset(y: cardOffset(envY: envY, H: H, cardH: cardH, insideScale: insideScale, proxy: proxy))
                        .opacity(phase == .departing ? 0 : 1)
                        .zIndex(phase >= .presented ? 6 : 2)

                    pocket(W: W, H: H)
                        .offset(y: envelopeOffset(envY, proxy))
                        .zIndex(3)

                    if !flapInside {
                        flap(W: W, H: H).offset(y: envelopeOffset(envY, proxy) - H / 2).zIndex(4)
                    }

                    seal(W: W)
                        .offset(y: envelopeOffset(envY, proxy) - H / 2 + H * 0.58)
                        .zIndex(5)
                }

                GoldLeafBurst(trigger: leaf, count: lot.marque == .noir ? 120 : 70, tint: lot.marque)
                    .ignoresSafeArea()
                    .zIndex(7)

                overlayText(proxy: proxy, cardH: cardH)
                    .zIndex(8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .sensoryFeedback(trigger: hapticTick) { _, new in
            switch new {
            case 1: .impact(weight: .light)
            case 2: .impact(weight: .medium)
            case 3: .impact(weight: .heavy)
            default: .success
            }
        }
        .task {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { sealPulse = true }
            if DebugHooks.autoUnseal {
                for _ in 0..<3 {
                    try? await Task.sleep(for: .milliseconds(650))
                    tapSeal()
                }
            }
        }
    }

    // MARK: Layout helpers

    private func envelopeOffset(_ envY: CGFloat, _ proxy: GeometryProxy) -> CGFloat {
        phase >= .presented ? proxy.size.height : envY
    }

    private func cardScale(_ inside: CGFloat) -> CGFloat {
        switch phase {
        case .sealed, .broken, .open: inside
        case .rising: inside * 1.05
        case .presented: 1
        case .departing: 0.3
        }
    }

    private func cardOffset(envY: CGFloat, H: CGFloat, cardH: CGFloat, insideScale: CGFloat, proxy: GeometryProxy) -> CGFloat {
        switch phase {
        case .sealed, .broken, .open: envY + H * 0.04
        case .rising: envY - H * 0.5 - cardH * insideScale * 0.28
        case .presented: -proxy.size.height * 0.04
        case .departing: proxy.size.height * 0.6
        }
    }

    // MARK: Pieces

    private var background: some View {
        ZStack {
            Theme.ink
            Spotlight(color: lot.marque == .noir ? Theme.goldLight : lot.marque.accent,
                      intensity: phase >= .presented ? 0.24 : 0.12)
            if phase >= .presented {
                PaletteBackdrop(palette: lot.palette)
                    .opacity(0.3)
                    .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 60, endRadius: 460))
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1), value: phase)
    }

    private var paper: LinearGradient {
        lot.marque == .noir
            ? LinearGradient(colors: [Color(hex: 0x1E1D1B), Color(hex: 0x0E0E0E)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(hex: 0xF2EBDD), Color(hex: 0xDDD2BE)], startPoint: .top, endPoint: .bottom)
    }

    private var liner: Color {
        switch lot.marque {
        case .ivory: Color(hex: 0x3B342A)
        case .silver: Color(hex: 0x2B3037)
        case .gold: Color(hex: 0x3A2C12)
        case .platinum: Color(hex: 0x2E2F38)
        case .noir: Color(hex: 0x2A2213)
        }
    }

    private var edge: Color { lot.marque == .noir ? Theme.gold.opacity(0.7) : Color(hex: 0xBFB29A) }

    private func envelopeBack(W: CGFloat, H: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(liner)
            .overlay(
                Guilloche(color: lot.marque.accent.opacity(0.12), lineWidth: 0.4, petals: 12, bands: 2, strands: 18)
                    .frame(width: W * 0.9, height: W * 0.9)
                    .clipped()
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(width: W, height: H)
            .shadow(color: .black.opacity(0.6), radius: 26, y: 18)
    }

    private func pocket(W: CGFloat, H: CGFloat) -> some View {
        ZStack {
            EnvelopePocket()
                .fill(paper)
            EnvelopePocket()
                .stroke(edge.opacity(0.6), lineWidth: 0.6)
            Text("MAISON CATDEX")
                .font(Theme.label(7, weight: .semibold))
                .tracking(3)
                .foregroundStyle(lot.marque == .noir ? Theme.gold.opacity(0.6) : Color(hex: 0x8C7E66))
                .offset(y: H * 0.36)
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }

    private func flap(W: CGFloat, H: CGFloat) -> some View {
        ZStack {
            EnvelopeFlap().fill(flapInside ? AnyShapeStyle(liner) : AnyShapeStyle(paper))
            EnvelopeFlap().stroke(edge.opacity(0.7), lineWidth: 0.6)
        }
        .frame(width: W, height: H * 0.6)
        .rotation3DEffect(.degrees(flapAngle), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.45)
        .offset(y: H * 0.3)
        .shadow(color: .black.opacity(flapInside ? 0 : 0.25), radius: 3, y: 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func seal(W: CGFloat) -> some View {
        let size = W * 0.24
        ZStack {
            if phase == .sealed {
                Circle()
                    .stroke(lot.marque.accent.opacity(sealPulse ? 0 : 0.5), lineWidth: 1)
                    .frame(width: size * (sealPulse ? 1.7 : 1.05), height: size * (sealPulse ? 1.7 : 1.05))
                WaxSeal(marque: lot.marque, cracks: taps, seed: Double(lot.lotNumber) * 0.21)
                    .frame(width: size, height: size)
                    .scaleEffect(taps > 0 ? 1 - CGFloat(taps) * 0.02 : 1)
            } else {
                // Two halves fall away.
                ForEach([-1.0, 1.0], id: \.self) { side in
                    WaxSeal(marque: lot.marque, cracks: 3, seed: Double(lot.lotNumber) * 0.21)
                        .frame(width: size, height: size)
                        .mask(HStack(spacing: 0) {
                            Rectangle().opacity(side < 0 ? 1 : 0)
                            Rectangle().opacity(side > 0 ? 1 : 0)
                        })
                        .rotationEffect(.degrees(phase >= .open ? side * 40 : 0))
                        .offset(x: phase >= .open ? side * 70 : side * 4, y: phase >= .open ? 260 : 0)
                        .opacity(phase >= .open ? 0 : 1)
                }
            }
        }
        .contentShape(Circle().inset(by: -20))
        .onTapGesture(perform: tapSeal)
        .accessibilityElement()
        .accessibilityLabel("Wax seal")
        .accessibilityHint("Tap to break the seal")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { tapSeal(); tapSeal(); tapSeal() }
    }

    // MARK: Presented text & actions

    private func overlayText(proxy: GeometryProxy, cardH: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                if phase < .presented {
                    VStack(spacing: 10) {
                        SmallCaps("Sealed for you", size: 10, color: Theme.champagne, tracking: 4)
                        Text(Format.lot(lot.lotNumber))
                            .font(Theme.displayItalic(26))
                            .foregroundStyle(Theme.ivory)
                    }
                    .transition(.opacity)
                } else {
                    VStack(spacing: 6) {
                        SmallCaps(Format.lot(lot.lotNumber), size: 10, color: Theme.parchment, tracking: 3)
                        Text(lot.marque.displayName.uppercased())
                            .font(Theme.display(38))
                            .tracking(10)
                            .foregroundStyle(lot.marque == .noir ? Theme.goldGradient : lot.marque.metal)
                            .textRenderer(GlyphReveal(progress: nameReveal, spread: 0.6))
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 90)
            .padding(.top, 12)

            Spacer()

            if phase == .presented {
                VStack(spacing: 16) {
                    VStack(spacing: 2) {
                        SmallCaps("Estimate", size: 8.5, color: Theme.mute)
                        Ticker(value: shownValue, font: Theme.numerals(26))
                            .foregroundStyle(Theme.ivory)
                    }
                    HStack(spacing: 12) {
                        Button("Release", action: onRelease)
                            .buttonStyle(HairlineButtonStyle(color: Theme.parchment))
                        Button("Add to Collection", action: add)
                            .buttonStyle(GoldButtonStyle())
                    }
                }
                .padding(.bottom, 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.6), value: phase)
    }

    // MARK: Choreography

    private func tapSeal() {
        guard phase == .sealed else { return }
        taps += 1
        hapticTick = taps
        if taps >= 3 { Task { await unseal() } }
    }

    @MainActor
    private func unseal() async {
        withAnimation(.easeOut(duration: 0.15)) { phase = .broken }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeIn(duration: 0.7)) { phase = .open }
        withAnimation(.easeIn(duration: 0.28)) { flapAngle = 90 }
        try? await Task.sleep(for: .milliseconds(280))
        flapInside = true
        withAnimation(.easeOut(duration: 0.34)) { flapAngle = 180 }
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.spring(duration: 0.8, bounce: 0.15)) { phase = .rising }
        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(.spring(duration: 0.9, bounce: 0.22)) { phase = .presented }
        hapticTick = 4
        if lot.marque.celebratesWithGoldLeaf { leaf += 1 }
        withAnimation(.easeOut(duration: 1.4).delay(0.2)) { nameReveal = 1 }
        await countUp()
        if DebugHooks.autoAdd {
            try? await Task.sleep(for: .milliseconds(900))
            add()
        }
    }

    @MainActor
    private func countUp() async {
        let steps = 24
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let eased = 1 - pow(1 - t, 3)
            withAnimation(.snappy(duration: 0.12)) {
                shownValue = Int((Double(lot.valuation) * eased / 50).rounded()) * 50
            }
            try? await Task.sleep(for: .milliseconds(45))
        }
        shownValue = lot.valuation
    }

    private func add() {
        guard phase == .presented else { return }
        hapticTick = 5
        withAnimation(.easeIn(duration: 0.45)) { phase = .departing }
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            onAdd()
        }
    }
}

// MARK: - Envelope shapes

/// Left, right and bottom flaps of an envelope's back, as one pocket.
struct EnvelopePocket: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX - r.width * 0.06, y: r.minY + r.height * 0.56))
        p.addQuadCurve(to: CGPoint(x: r.midX + r.width * 0.06, y: r.minY + r.height * 0.56),
                       control: CGPoint(x: r.midX, y: r.minY + r.height * 0.6))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        // Fold lines from the corners.
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.5))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

/// The top flap: a softly pointed triangle hinged on the top edge.
struct EnvelopeFlap: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.07, y: r.maxY - r.height * 0.05))
        p.addQuadCurve(to: CGPoint(x: r.midX - r.width * 0.07, y: r.maxY - r.height * 0.05),
                       control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.04))
        p.closeSubpath()
        return p
    }
}
