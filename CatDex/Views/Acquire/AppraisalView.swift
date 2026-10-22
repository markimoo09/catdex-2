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
                .frame(height: 230, alignment: .top)
            progress
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 16)
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
            Theme.ground
            if !session.palette.isEmpty {
                PaletteBackdrop(palette: session.palette)
                    .opacity(0.6)
                    .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 40, endRadius: 420))
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Appraisal")
                .font(Theme.display(22))
                .tracking(Theme.displayTracking)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(Format.lot(session.lotNumber))
                .font(Theme.number(13, weight: .semibold))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.top, 10)
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
                                .shadow(color: Theme.rose.opacity(rim ? 0.6 : 0), radius: rim ? 18 : 0)
                                .shadow(color: Color(hex: 0x5A3A30, alpha: 0.25), radius: 14, y: 12)
                                .scaleEffect(rim ? 1.03 : 1)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: size.width, maxHeight: size.height * 0.94)
                    .clipShape(RoundedRectangle(cornerRadius: dissolve > 0.5 ? 0 : 14, style: .continuous))
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .padding(.vertical, 10)
    }

    // MARK: Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            if session.stage >= .readingCoat, !session.palette.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(session.palette.enumerated()), id: \.element.id) { index, swatch in
                        VStack(spacing: 5) {
                            Circle()
                                .fill(swatch.color)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .frame(width: 28, height: 28)
                                .shadow(color: Color(hex: 0x5A3A30, alpha: 0.2), radius: 4, y: 2)
                            Text(swatch.name)
                                .font(Theme.caption(11, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity), removal: .opacity))
                        .animation(.spring(duration: 0.55, bounce: 0.35).delay(Double(index) * 0.12), value: session.palette)
                    }
                }
                .pearlCard(16, padding: 10)
            }

            if session.stage >= .provenance, let setting = session.setting {
                HStack(spacing: 8) {
                    fact("house", "Setting", setting)
                    fact("clock", "Hour", session.hour)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if session.stage >= .composing {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: session.draft.isAppleIntelligence ? "sparkles" : "pencil.and.scribble")
                            .font(.system(size: 10, weight: .semibold))
                        Text("The curator writes")
                            .font(Theme.caption(11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.roseDeep)
                    (Text(session.draft.curatorNote ?? "")
                        + Text(session.stage == .composing ? " ▍" : "").foregroundStyle(Theme.rose))
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .pearlCard(16, padding: 12)
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.5), value: session.stage)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fact(_ symbol: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.roseDeep)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.blush))
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(Theme.caption(10.5)).foregroundStyle(Theme.ink3)
                Text(value).font(Theme.title(14)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .pearlCard(14, padding: 8)
    }

    // MARK: Progress

    private var progress: some View {
        let stages = AppraisalSession.Stage.allCases.filter { $0 != .sealed }
        let current = min(session.stage.rawValue, stages.count - 1)
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(stages, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue < session.stage.rawValue ? AnyShapeStyle(Theme.roseGold) :
                                s == session.stage ? AnyShapeStyle(Theme.rose.opacity(0.45)) : AnyShapeStyle(Theme.surfaceSunk))
                        .frame(height: 4)
                }
            }
            HStack {
                Text(session.stage == .sealed ? "Sealed" : session.stage.title)
                    .font(Theme.title(14))
                    .foregroundStyle(Theme.ink)
                    .id(session.stage)
                    .transition(.push(from: .bottom))
                Spacer()
                Text("\(current + 1)/\(stages.count)")
                    .font(Theme.number(12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .clipped()
        }
        .animation(.smooth, value: session.stage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stage \(current + 1) of \(stages.count): \(session.stage.title)")
    }
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
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.roseDeep)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Theme.blush))
                Text("The curator hesitates")
                    .font(Theme.display(21))
                    .tracking(Theme.displayTracking)
                    .foregroundStyle(Theme.ink)
                Text("No cat could be authenticated in this photograph.")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button("Retake", action: onRetake)
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                    Button("Proceed anyway", action: onProceed)
                        .buttonStyle(PrimaryButtonStyle(compact: true))
                }
                .padding(.top, 4)
            }
            .padding(22)
            .pearlCard(26, padding: nil)
            .padding(28)
        }
    }
}
