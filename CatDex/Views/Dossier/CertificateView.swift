import SwiftUI

/// Presents the certificate and shares it as an image.
struct CertificateView: View {
    let lot: Acquisition
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: Image?
    @State private var appear = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Certificate of provenance")
                    .font(Theme.title(16))
                    .foregroundStyle(Theme.ink)
                Spacer()
                GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer(minLength: 0)
            Certificate(lot: lot)
                .frame(width: Certificate.size.width, height: Certificate.size.height)
                .scaleEffect(appear ? 1 : 0.94)
                .opacity(appear ? 1 : 0)
                .shadow(color: Color(hex: 0x8A5A50, alpha: 0.25), radius: 24, y: 14)
            Spacer(minLength: 0)

            if let rendered {
                ShareLink(item: rendered, preview: SharePreview("\(lot.name) — Certificate of Provenance", image: rendered)) {
                    Label("Share certificate", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
            }
        }
        .background(Theme.ground.ignoresSafeArea())
        .task {
            withAnimation(.spring(duration: 0.7, bounce: 0.2)) { appear = true }
            render()
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content:
            Certificate(lot: lot)
                .frame(width: Certificate.size.width, height: Certificate.size.height)
                .environment(Motion())
        )
        renderer.scale = 3
        if let image = renderer.uiImage {
            rendered = Image(uiImage: image)
        }
    }
}

/// The certificate itself: engraved border, cameo, seal and signature on ivory paper.
struct Certificate: View {
    let lot: Acquisition
    static let size = CGSize(width: 330, height: 480)
    private let engraving = Theme.roseDeep

    private var serial: String {
        let year = Calendar.current.component(.year, from: lot.acquiredAt)
        return "CDX-\(year)-\(String(format: "%04d", lot.lotNumber))-\(lot.marque.stamp)"
    }

    var body: some View {
        ZStack {
            paper
            GuillocheBorder(color: engraving.opacity(0.5), inset: 14, waves: 50)
            Guilloche(color: engraving.opacity(0.08), lineWidth: 0.4, petals: 16, bands: 3, strands: 24)
                .frame(width: 280, height: 280)
                .offset(y: -40)

            VStack(spacing: 0) {
                Text("Maison CatDex")
                    .font(Theme.caption(10, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 34)
                Text("Certificate of Provenance")
                    .font(Theme.display(21))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 6)

                cameo.padding(.top, 12)

                Text(lot.name)
                    .font(Theme.display(20))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 34)
                    .padding(.top, 10)
                Text(lot.epithet)
                    .font(Theme.body(11, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                Text("\(lot.marque.displayName) marque · entered as \(Format.lot(lot.lotNumber)) on \(lot.acquiredAt.formatted(Format.longDate))")
                    .font(Theme.body(9.5))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 44)
                    .padding(.top, 6)

                HStack(spacing: 0) {
                    fact("Estimate", Format.estimate(lot.valuation))
                    divider
                    fact("Setting", lot.setting)
                    divider
                    fact("Hour", lot.hourLabel)
                }
                .padding(.horizontal, 28)
                .padding(.top, 10)

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("The Curator")
                            .font(Theme.signature(19))
                            .foregroundStyle(Color(hex: 0x3A3F6E))
                        Rectangle().fill(Theme.ink.opacity(0.3)).frame(width: 104, height: 0.5)
                        Text("Head curator")
                            .font(Theme.caption(8, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                            .padding(.top, 3)
                    }
                    Spacer()
                    WaxSeal(marque: lot.marque, seed: Double(lot.lotNumber) * 0.13)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-12))
                }
                .padding(.horizontal, 32)

                Text("No. \(serial)")
                    .font(Theme.number(8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink3)
                    .padding(.top, 10)
                    .padding(.bottom, 26)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Certificate of provenance for \(lot.name), \(Format.lot(lot.lotNumber)), \(lot.marque.displayName) marque.")
    }

    private var paper: some View {
        ZStack {
            Theme.paper
            RadialGradient(colors: [.clear, Theme.paperShade.opacity(0.8)], center: .center, startRadius: 120, endRadius: 340)
            Rectangle().fill(.white)
                .colorEffect(ShaderLibrary.grain(.float(0.12)))
                .blendMode(.multiply)
                .opacity(0.25)
        }
    }

    private var cameo: some View {
        ZStack {
            PaletteBackdrop(palette: lot.palette, marque: lot.marque, animated: false)
                .clipShape(Ellipse())
            CutoutArt(image: ImageStore.cutout(for: lot), isCameo: lot.isCameo, marque: lot.marque, shadow: false)
                .padding(lot.isCameo ? 6 : 12)
                .clipShape(Ellipse())
            Ellipse().stroke(Theme.roseGold, lineWidth: 2)
            Ellipse().stroke(engraving.opacity(0.4), lineWidth: 0.5).padding(-5)
        }
        .frame(width: 96, height: 118)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Theme.caption(7.5, weight: .semibold))
                .foregroundStyle(Theme.ink3)
            Text(value)
                .font(Theme.body(8.5, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(engraving.opacity(0.3)).frame(width: 0.5, height: 20)
    }
}
