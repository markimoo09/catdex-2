import SwiftUI

/// The collectible face of a lot: a coat-tinted backdrop, the cat under soft
/// light, foil by marque, and a frosted name plate.
struct LotCard: View {
    let lot: LotPresentation
    var compact: Bool = false
    var showsFoil: Bool = true

    private var corner: CGFloat { compact ? 14 : 22 }
    private var isNoir: Bool { lot.marque == .noir }
    private var inkColor: Color { isNoir ? .white : Theme.ink }

    var body: some View {
        ZStack {
            PaletteBackdrop(palette: lot.palette, marque: lot.marque, animated: !compact)
            Spotlight(color: isNoir ? Theme.rose : .white, intensity: isNoir ? 0.25 : 0.7)

            CutoutArt(image: lot.cutout, isCameo: lot.isCameo, marque: lot.marque)
                .padding(.horizontal, compact ? 10 : 26)
                .padding(.top, compact ? 22 : 44)
                .padding(.bottom, compact ? 40 : 92)
                .tiltParallax(compact ? 0 : 5)

            if showsFoil, lot.marque.foilStrength > 0 {
                FoilSheen(strength: lot.marque.foilStrength * (compact ? 0.5 : 0.75),
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
        .shadow(color: Color(hex: 0x8A5A50, alpha: compact ? 0.14 : 0.2), radius: compact ? 8 : 18, y: compact ? 4 : 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.lot(lot.lotNumber)), \(lot.name), \(lot.epithet). \(lot.marque.displayName) marque.")
    }

    /// Foil reads on the frame and the art, never on the type.
    private var foilMask: some View {
        ZStack {
            if lot.marque >= .platinum { Rectangle().opacity(0.3) }
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(lineWidth: compact ? 8 : 16)
            CutoutArt(image: lot.cutout, isCameo: lot.isCameo, shadow: false)
                .padding(.horizontal, compact ? 10 : 26)
                .padding(.top, compact ? 22 : 44)
                .padding(.bottom, compact ? 40 : 92)
                .opacity(0.5)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(String(format: "№ %03d", lot.lotNumber))
                .font(Theme.number(compact ? 9 : 11, weight: .semibold))
                .foregroundStyle(inkColor.opacity(0.7))
            Spacer()
            Hallmark(marque: lot.marque, size: compact ? 12 : 17)
        }
        .padding(.horizontal, compact ? 9 : 14)
        .padding(.top, compact ? 9 : 14)
    }

    private var plate: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            if !compact {
                MarquePill(marque: lot.marque)
                    .padding(.bottom, 2)
            }
            Text(lot.name)
                .font(compact ? Theme.title(12.5) : Theme.display(21))
                .tracking(compact ? 0 : -0.3)
                .foregroundStyle(inkColor)
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(0.75)
            if !compact {
                Text(lot.epithet)
                    .font(Theme.body(13))
                    .foregroundStyle(isNoir ? Theme.roseLight.opacity(0.9) : Theme.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 9 : 14)
        .padding(.vertical, compact ? 7 : 12)
        .background {
            if isNoir {
                Rectangle().fill(Color(hex: 0x1C171F, alpha: 0.55))
            } else {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Color.white.opacity(0.55))
            }
        }
    }

    @ViewBuilder
    private var frame: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        if lot.marque == .ivory {
            shape.stroke(Color.white.opacity(0.9), lineWidth: compact ? 2 : 3)
        } else {
            shape.stroke(lot.marque.metal, lineWidth: compact ? 1.5 : 2.5)
                .overlay(shape.inset(by: compact ? 2 : 3).stroke(Color.white.opacity(isNoir ? 0.15 : 0.7), lineWidth: 1))
        }
    }
}
