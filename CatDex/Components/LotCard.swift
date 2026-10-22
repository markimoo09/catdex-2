import SwiftUI

/// The collectible face of a lot: coat-palette backdrop, the cat under a
/// spotlight, foil by marque, and an engraved name plate.
struct LotCard: View {
    let lot: LotPresentation
    var compact: Bool = false
    var showsFoil: Bool = true

    private var corner: CGFloat { compact ? 16 : 26 }

    var body: some View {
        ZStack {
            PaletteBackdrop(palette: lot.palette, animated: !compact)
            Spotlight(intensity: lot.marque == .noir ? 0.22 : 0.14)

            CutoutArt(image: lot.cutout, isCameo: lot.isCameo, marque: lot.marque)
                .padding(.horizontal, compact ? 14 : 30)
                .padding(.top, compact ? 30 : 64)
                .padding(.bottom, compact ? 62 : 128)
                .tiltParallax(compact ? 0 : 6)

            if showsFoil, lot.marque.foilStrength > 0 {
                FoilSheen(strength: lot.marque.foilStrength * (compact ? 0.45 : 0.6),
                          hueShift: Double(lot.lotNumber % 7) / 7, marque: lot.marque)
                    .mask(foilMask)
            }

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                plate
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(frame)
        .compositingGroup()
        .shadow(color: .black.opacity(0.5), radius: compact ? 10 : 28, y: compact ? 6 : 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.lot(lot.lotNumber)), \(lot.name), \(lot.epithet). \(lot.marque.displayName) marque.")
    }

    /// Foil reads on the frame and the art, never on the type.
    private var foilMask: some View {
        ZStack {
            // The rarest marques carry a whisper of foil across the whole card.
            if lot.marque == .noir || lot.marque == .platinum {
                Rectangle().opacity(0.3)
            }
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(lineWidth: compact ? 10 : 22)
            CutoutArt(image: lot.cutout, isCameo: lot.isCameo, shadow: false)
                .padding(.horizontal, compact ? 14 : 30)
                .padding(.top, compact ? 30 : 64)
                .padding(.bottom, compact ? 62 : 128)
                .opacity(0.4)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            SmallCaps(Format.lot(lot.lotNumber), size: compact ? 8 : 10, color: Theme.ivory.opacity(0.75))
            Spacer()
            Hallmark(marque: lot.marque, size: compact ? 14 : 20)
        }
        .padding(.horizontal, compact ? 12 : 20)
        .padding(.top, compact ? 12 : 20)
    }

    private var plate: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            SmallCaps(lot.marque.displayName, size: compact ? 7 : 9, color: lot.marque.accent)
            Text(lot.name)
                .font(Theme.display(compact ? 17 : 30))
                .foregroundStyle(Theme.ivory)
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(0.7)
            if !compact {
                Text(lot.epithet)
                    .font(Theme.serifItalic(15))
                    .foregroundStyle(Theme.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 12 : 22)
        .padding(.vertical, compact ? 10 : 18)
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.55), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .padding(.top, compact ? -24 : -50)
        }
    }

    @ViewBuilder
    private var frame: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        switch lot.marque {
        case .ivory:
            shape.stroke(Color.white.opacity(0.12), lineWidth: 0.75)
        case .silver, .gold, .platinum:
            shape.stroke(lot.marque.metal, lineWidth: compact ? 1 : 1.5)
                .overlay(shape.inset(by: compact ? 4 : 7).stroke(lot.marque.accent.opacity(0.3), lineWidth: 0.5))
        case .noir:
            shape.stroke(Theme.goldGradient, lineWidth: compact ? 1.5 : 2.5)
                .overlay(shape.inset(by: compact ? 4 : 8).stroke(Theme.gold.opacity(0.55), lineWidth: 0.75))
        }
    }
}
