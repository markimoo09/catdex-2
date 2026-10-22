import SwiftUI

/// The brushed-metal membership card: tier, collection appraisal, progress.
struct PatronCard: View {
    let patronage: Patronage
    @Environment(Motion.self) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tilt = reduceMotion ? .zero : motion.tilt
        ZStack(alignment: .topLeading) {
            metal(tilt: tilt)
            Guilloche(color: Theme.champagne.opacity(0.08), lineWidth: 0.35, petals: 14, bands: 3, strands: 20)
                .frame(width: 260, height: 260)
                .offset(x: 170, y: -40)
            FoilSheen(strength: 0.3, marque: .gold)
                .mask(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        SmallCaps("Maison CatDex", size: 9, color: Theme.parchment, tracking: 3)
                        SmallCaps("Carte de Patron", size: 7.5, color: Theme.mute, tracking: 2)
                    }
                    Spacer()
                    chip
                }
                Spacer(minLength: 12)
                Text(patronage.tier.name)
                    .font(Theme.display(27))
                    .foregroundStyle(Theme.goldSheen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let since = patronage.memberSince {
                    Text("Member since \(since.formatted(.dateTime.month(.wide).year()))")
                        .font(Theme.serifItalic(12))
                        .foregroundStyle(Theme.parchment.opacity(0.8))
                        .padding(.top, 2)
                }
                Spacer(minLength: 14)
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        SmallCaps("Collection appraised", size: 7.5, color: Theme.mute, tracking: 2)
                        Ticker(value: patronage.appraisal, font: Theme.numerals(19))
                            .foregroundStyle(Theme.ivory)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        SmallCaps("Lots", size: 7.5, color: Theme.mute, tracking: 2)
                        Text("\(patronage.lotCount)")
                            .font(Theme.numerals(19))
                            .foregroundStyle(Theme.ivory)
                            .contentTransition(.numericText(value: Double(patronage.lotCount)))
                    }
                }
                progress.padding(.top, 12)
            }
            .padding(20)
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05), .white.opacity(0.2)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75)
        )
        .rotation3DEffect(.degrees(Double(tilt.width) * 5), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(Double(-tilt.height) * 4), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Patron card. \(patronage.tier.name). Collection appraised at \(Format.guineas(patronage.appraisal)). \(patronage.lotCount) lots.")
    }

    private func metal(tilt: CGSize) -> some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [Color(hex: 0x34322F), Color(hex: 0x1A1918), Color(hex: 0x111111), Color(hex: 0x2A2825)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .visualEffect { content, proxy in
                content.colorEffect(ShaderLibrary.brushedMetal(
                    .float2(proxy.size), .float2(Float(tilt.width), Float(tilt.height))
                ))
            }
    }

    /// An engraved gold emblem in place of a card chip.
    private var chip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.goldGradient)
                .frame(width: 40, height: 30)
            VStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Rectangle().fill(Theme.goldDeep.opacity(0.55)).frame(width: 26, height: 0.6)
                }
            }
            Rectangle().fill(Theme.goldDeep.opacity(0.55)).frame(width: 0.6, height: 22)
        }
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Theme.goldGradient)
                        .frame(width: max(3, proxy.size.width * patronage.progress))
                        .shadow(color: Theme.gold.opacity(0.6), radius: 4)
                }
            }
            .frame(height: 2.5)
            HStack {
                SmallCaps("\(patronage.prestige) prestige", size: 7.5, color: Theme.mute, tracking: 1.6)
                Spacer()
                if let next = patronage.nextTier {
                    SmallCaps("Next · \(next.name)", size: 7.5, color: Theme.champagne.opacity(0.8), tracking: 1.6)
                } else {
                    SmallCaps("The highest circle", size: 7.5, color: Theme.champagne.opacity(0.8), tracking: 1.6)
                }
            }
        }
    }
}

// MARK: - Exhibitions

struct ExhibitionsRow: View {
    let exhibitions: [Exhibition]
    @State private var focused: Exhibition?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 18) {
                ForEach(sorted) { exhibition in
                    Button { focused = exhibition } label: {
                        Medallion(exhibition: exhibition)
                    }
                    .buttonStyle(PressScale())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
        .sheet(item: $focused) { exhibition in
            ExhibitionDetail(exhibition: exhibition)
                .presentationDetents([.height(340)])
                .presentationBackground(Theme.onyx)
                .presentationCornerRadius(30)
        }
    }

    /// Completed first, then closest to completion.
    private var sorted: [Exhibition] {
        exhibitions.sorted {
            if $0.isComplete != $1.isComplete { return $0.isComplete }
            return $0.progress > $1.progress
        }
    }
}

struct Medallion: View {
    let exhibition: Exhibition
    var size: CGFloat = 66

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if exhibition.isComplete {
                    Circle().fill(Theme.goldGradient)
                    Circle().stroke(Theme.goldDeep.opacity(0.6), lineWidth: 0.8).padding(5)
                    Image(systemName: exhibition.symbol)
                        .font(.system(size: size * 0.34, weight: .medium))
                        .foregroundStyle(Theme.goldDeep)
                        .shadow(color: Theme.goldLight.opacity(0.8), radius: 0, x: -0.5, y: -0.5)
                } else {
                    Circle().fill(Theme.graphite)
                    Circle().stroke(Theme.hairline, lineWidth: 1).padding(5)
                    Circle()
                        .trim(from: 0, to: exhibition.progress)
                        .stroke(Theme.champagne, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(1)
                    Image(systemName: exhibition.symbol)
                        .font(.system(size: size * 0.3, weight: .light))
                        .foregroundStyle(Theme.mute)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: exhibition.isComplete ? Theme.gold.opacity(0.35) : .clear, radius: 10)

            VStack(spacing: 3) {
                Text(exhibition.title)
                    .font(Theme.serifItalic(12.5))
                    .foregroundStyle(exhibition.isComplete ? Theme.ivory : Theme.parchment.opacity(0.7))
                    .lineLimit(1)
                SmallCaps("\(exhibition.current)/\(exhibition.goal)", size: 8, color: Theme.mute, tracking: 1.4)
            }
            .frame(width: size + 26)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exhibition.title), \(exhibition.subtitle). \(exhibition.current) of \(exhibition.goal).")
    }
}

struct ExhibitionDetail: View {
    let exhibition: Exhibition

    var body: some View {
        VStack(spacing: 18) {
            Medallion(exhibition: exhibition, size: 92)
            Text(exhibition.subtitle)
                .font(Theme.serifItalic(17))
                .foregroundStyle(Theme.parchment)
                .multilineTextAlignment(.center)
            SmallCaps(exhibition.isComplete ? "Exhibited" : "In preparation", size: 9,
                      color: exhibition.isComplete ? Theme.champagne : Theme.mute)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.onyx)
    }
}
