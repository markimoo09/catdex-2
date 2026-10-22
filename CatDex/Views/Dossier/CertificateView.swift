import SwiftUI

/// Presents the certificate and shares it as an image.
struct CertificateView: View {
    let lot: Acquisition
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: Image?
    @State private var appear = false

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                SmallCaps("Certificate of Provenance", size: 10, color: Theme.champagne)
                Spacer()
                GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Spacer(minLength: 0)
            Certificate(lot: lot)
                .frame(width: Certificate.size.width, height: Certificate.size.height)
                .scaleEffect(appear ? 1 : 0.94)
                .opacity(appear ? 1 : 0)
                .shadow(color: .black.opacity(0.6), radius: 30, y: 20)
                .rotation3DEffect(.degrees(appear ? 0 : 8), axis: (x: 1, y: 0, z: 0))
            Spacer(minLength: 0)

            if let rendered {
                ShareLink(item: rendered, preview: SharePreview("\(lot.name) — Certificate of Provenance", image: rendered)) {
                    Label("Share Certificate", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GoldButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
            }
        }
        .background(Theme.ink.ignoresSafeArea())
        .task {
            withAnimation(.spring(duration: 0.8, bounce: 0.2)) { appear = true }
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
    static let size = CGSize(width: 340, height: 520)

    private var serial: String {
        let year = Calendar.current.component(.year, from: lot.acquiredAt)
        return "CDX-\(year)-\(String(format: "%04d", lot.lotNumber))-\(lot.marque.stamp)"
    }

    var body: some View {
        ZStack {
            paper
            GuillocheBorder(color: Theme.goldDeep.opacity(0.55), inset: 16, waves: 54)
            Guilloche(color: Theme.goldDeep.opacity(0.07), lineWidth: 0.4, petals: 16, bands: 3, strands: 24)
                .frame(width: 300, height: 300)
                .offset(y: -40)

            VStack(spacing: 0) {
                SmallCaps("Maison CatDex", size: 8, color: Theme.inkOnPaper.opacity(0.7), tracking: 5)
                    .padding(.top, 38)
                Text("Certificate")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.inkOnPaper)
                    .padding(.top, 8)
                Text("of Provenance")
                    .font(Theme.displayItalic(17))
                    .foregroundStyle(Theme.goldDeep)

                cameo.padding(.top, 14)

                Text("This is to certify that")
                    .font(Theme.serifItalic(10))
                    .foregroundStyle(Theme.inkOnPaper.opacity(0.65))
                    .padding(.top, 12)
                Text(lot.name)
                    .font(Theme.display(23))
                    .foregroundStyle(Theme.inkOnPaper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 36)
                    .padding(.top, 2)
                Text(lot.epithet)
                    .font(Theme.serifItalic(11))
                    .foregroundStyle(Theme.inkOnPaper.opacity(0.75))
                Text("of the \(lot.marque.displayName) marque, entered into the private collection as \(Format.lot(lot.lotNumber)) on \(lot.acquiredAt.formatted(Format.longDate)).")
                    .font(Theme.serif(9.5))
                    .foregroundStyle(Theme.inkOnPaper.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 46)
                    .padding(.top, 8)

                HStack(spacing: 0) {
                    fact("Estimate", Format.estimate(lot.valuation))
                    divider
                    fact("Setting", lot.setting)
                    divider
                    fact("Hour", lot.hourLabel)
                }
                .padding(.horizontal, 30)
                .padding(.top, 12)

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("The Curator")
                            .font(Theme.script(20))
                            .foregroundStyle(Color(hex: 0x23305A))
                        Rectangle().fill(Theme.inkOnPaper.opacity(0.4)).frame(width: 110, height: 0.5)
                        SmallCaps("Head Curator", size: 6.5, color: Theme.inkOnPaper.opacity(0.6), tracking: 2)
                            .padding(.top, 4)
                    }
                    Spacer()
                    WaxSeal(marque: lot.marque, seed: Double(lot.lotNumber) * 0.13)
                        .frame(width: 66, height: 66)
                        .rotationEffect(.degrees(-12))
                }
                .padding(.horizontal, 36)

                SmallCaps("No. \(serial)", size: 6.5, color: Theme.inkOnPaper.opacity(0.5), tracking: 2.2)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Certificate of provenance for \(lot.name), \(Format.lot(lot.lotNumber)), \(lot.marque.displayName) marque.")
    }

    private var paper: some View {
        ZStack {
            Theme.paper
            RadialGradient(colors: [.clear, Theme.paperShade.opacity(0.9)], center: .center, startRadius: 120, endRadius: 360)
            Rectangle().fill(.white)
                .colorEffect(ShaderLibrary.grain(.float(0.12)))
                .blendMode(.multiply)
                .opacity(0.35)
        }
    }

    private var cameo: some View {
        ZStack {
            Ellipse()
                .fill(.clear)
                .background(PaletteBackdrop(palette: lot.palette, animated: false))
                .clipShape(Ellipse())
            CutoutArt(image: ImageStore.cutout(for: lot), isCameo: lot.isCameo, marque: lot.marque, shadow: false)
                .padding(lot.isCameo ? 8 : 14)
                .clipShape(Ellipse())
            Ellipse().stroke(Theme.goldGradient, lineWidth: 2)
            Ellipse().stroke(Theme.goldDeep.opacity(0.5), lineWidth: 0.5).padding(-5)
        }
        .frame(width: 96, height: 118)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            SmallCaps(label, size: 6, color: Theme.inkOnPaper.opacity(0.55), tracking: 1.6)
            Text(value)
                .font(Theme.serif(8.5))
                .foregroundStyle(Theme.inkOnPaper)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Theme.goldDeep.opacity(0.4)).frame(width: 0.5, height: 20)
    }
}
