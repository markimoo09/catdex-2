import SwiftUI

/// The appraisal ceremony: the subject is lifted, the coat read, provenance
/// noted, and the curator writes — live.
struct AppraisalView: View {
    let session: AppraisalSession
    var onRetake: () -> Void

    @State private var dissolve = 0.0
    @State private var rim = false

    var body: some View {
        VStack(spacing: 0) {
            header
            stage
                .frame(maxHeight: .infinity)
            details
                .frame(height: 240, alignment: .top)
            progress
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 22)
        .background(background)
        .overlay {
            if session.isDoubtful {
                DoubtView(
                    onRetake: { session.resolveDoubt(proceed: false) },
                    onProceed: { session.resolveDoubt(proceed: true) }
                )
                .transition(.opacity)
            }
        }
        .animation(.smooth, value: session.isDoubtful)
        .onChange(of: session.cutout != nil) { _, ready in
            guard ready else { return }
            withAnimation(.easeIn(duration: 1.7)) { dissolve = 1 }
            withAnimation(.easeInOut(duration: 1.2).delay(1.2)) { rim = true }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: session.stage)
        .sensoryFeedback(.success, trigger: session.stage == .sealed)
    }

    private var background: some View {
        ZStack {
            Theme.ink
            Spotlight(color: Theme.champagne, intensity: 0.1)
            if !session.palette.isEmpty {
                PaletteBackdrop(palette: session.palette)
                    .opacity(0.35)
                    .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 40, endRadius: 420))
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            SmallCaps("The Appraisal", size: 10, color: Theme.champagne, tracking: 3)
            Spacer()
            Text(Format.lot(session.lotNumber))
                .font(Theme.displayItalic(17))
                .foregroundStyle(Theme.ivory)
        }
        .padding(.top, 14)
    }

    // MARK: Stage

    private var stage: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if let cutout = session.cutout, cutout.isCameo {
                    CutoutArt(image: cutout.cutout, isCameo: true, marque: .gold)
                        .frame(maxWidth: size.width * 0.8, maxHeight: size.height * 0.92)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    ZStack {
                        Image(uiImage: session.original)
                            .resizable()
                            .scaledToFit()
                            .modifier(GildedDissolve(progress: dissolve))
                            .overlay {
                                if session.cutout == nil { ScanLine() }
                            }
                        if let mask = session.cutout?.alignedMask {
                            Image(uiImage: mask)
                                .resizable()
                                .scaledToFit()
                                .shadow(color: Theme.gold.opacity(rim ? 0.55 : 0), radius: rim ? 22 : 0)
                                .shadow(color: .black.opacity(0.5), radius: 20, y: 18)
                                .scaleEffect(rim ? 1.03 : 1)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: size.width, maxHeight: size.height * 0.94)
                    .clipShape(RoundedRectangle(cornerRadius: dissolve > 0.5 ? 0 : 6, style: .continuous))
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .padding(.vertical, 12)
    }

    // MARK: Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            if session.stage >= .readingCoat, !session.palette.isEmpty {
                HStack(spacing: 16) {
                    ForEach(Array(session.palette.enumerated()), id: \.element.id) { index, swatch in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(swatch.color)
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                                .frame(width: 30, height: 30)
                                .shadow(color: swatch.color.opacity(0.6), radius: 8)
                            Text(swatch.name)
                                .font(Theme.serifItalic(11))
                                .foregroundStyle(Theme.parchment)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity), removal: .opacity))
                        .animation(.spring(duration: 0.55, bounce: 0.35).delay(Double(index) * 0.12), value: session.palette)
                    }
                }
            }

            if session.stage >= .provenance, let setting = session.setting {
                HStack(spacing: 18) {
                    fact("Setting", setting)
                    Rectangle().fill(Theme.hairline).frame(width: 0.5, height: 26)
                    fact("Hour", session.hour)
                    Spacer()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if session.stage >= .composing {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        SmallCaps("The curator writes", size: 8.5, color: Theme.champagne)
                        if session.draft.isAppleIntelligence {
                            Image(systemName: "sparkles").font(.system(size: 9)).foregroundStyle(Theme.champagne)
                        }
                    }
                    (Text(session.draft.curatorNote ?? "")
                        + Text(session.stage == .composing ? " ▍" : "").foregroundStyle(Theme.gold))
                        .font(Theme.serifItalic(15.5))
                        .foregroundStyle(Theme.ivory.opacity(0.92))
                        .lineSpacing(3)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.5), value: session.stage)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            SmallCaps(label, size: 8, color: Theme.mute)
            Text(value)
                .font(Theme.display(19))
                .foregroundStyle(Theme.ivory)
        }
    }

    // MARK: Progress

    private var progress: some View {
        let stages = AppraisalSession.Stage.allCases.filter { $0 != .sealed }
        let current = min(session.stage.rawValue, stages.count - 1)
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(stages, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue < session.stage.rawValue ? AnyShapeStyle(Theme.goldGradient) :
                                s == session.stage ? AnyShapeStyle(Theme.champagne.opacity(0.55)) : AnyShapeStyle(Theme.hairline))
                        .frame(height: 2)
                }
            }
            HStack {
                Text(romanNumerals[current])
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.champagne)
                Text(session.stage == .sealed ? "Sealed" : session.stage.title)
                    .font(Theme.serifItalic(14))
                    .foregroundStyle(Theme.parchment)
                    .id(session.stage)
                    .transition(.push(from: .bottom))
                Spacer()
            }
        }
        .animation(.smooth, value: session.stage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stage \(current + 1) of \(stages.count): \(session.stage.title)")
    }

    private let romanNumerals = ["I", "II", "III", "IV", "V"]
}

/// Animatable wrapper so the dissolve shader's progress interpolates.
struct GildedDissolve: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.visualEffect { [progress] view, proxy in
            view.layerEffect(
                ShaderLibrary.gildedDissolve(.float2(proxy.size), .float(Float(progress))),
                maxSampleOffset: .zero,
                isEnabled: progress > 0
            )
        }
    }
}

/// A gold scan line sweeping the photograph.
struct ScanLine: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let progress = (t.truncatingRemainder(dividingBy: 1.8)) / 1.8
            Rectangle()
                .fill(.clear)
                .visualEffect { view, proxy in
                    view.colorEffect(ShaderLibrary.scanLine(.float2(proxy.size), .float(Float(progress))))
                }
                .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Doubt

struct DoubtView: View {
    var onRetake: () -> Void
    var onProceed: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.champagne)
                Text("The curator hesitates.")
                    .font(Theme.displayItalic(28))
                    .foregroundStyle(Theme.ivory)
                Text("Our appraisers could not authenticate a feline subject in this photograph.")
                    .font(Theme.serif(15))
                    .foregroundStyle(Theme.parchment)
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    Button("Proceed Regardless", action: onProceed)
                        .buttonStyle(GoldButtonStyle())
                    Button("Retake", action: onRetake)
                        .buttonStyle(HairlineButtonStyle())
                }
                .padding(.top, 6)
            }
            .padding(28)
            .maisonGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(24)
        }
    }
}
