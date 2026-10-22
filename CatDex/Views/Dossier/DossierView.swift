import SwiftData
import SwiftUI

struct DossierView: View {
    @Bindable var lot: Acquisition
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showCertificate = DebugHooks.open == "certificate"
    @State private var showAudience = DebugHooks.open == "audience"
    @State private var renaming = false
    @State private var draftName = ""
    @State private var confirmRelease = false

    var body: some View {
        let presentation = lot.presentation
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 0) {
                    hero(presentation)
                    content
                        .padding(.horizontal, 24)
                        .padding(.top, 30)
                        .padding(.bottom, 60)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)
                                .fill(Theme.onyx)
                                .shadow(color: .black.opacity(0.5), radius: 20, y: -6)
                        )
                        .padding(.top, -34)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .task {
                if DebugHooks.scrollDown {
                    try? await Task.sleep(for: .milliseconds(700))
                    withAnimation { reader.scrollTo("temperament", anchor: .top) }
                }
            }
        }
        .background(Theme.onyx.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            // A soft scrim so the chrome stays legible over scrolled text.
            LinearGradient(colors: [Theme.onyx.opacity(0.92), Theme.onyx.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 130)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) { topBar }
        .sheet(isPresented: $showCertificate) {
            CertificateView(lot: lot)
                .presentationBackground(Theme.ink)
                .presentationCornerRadius(34)
        }
        .fullScreenCover(isPresented: $showAudience) {
            AudienceView(lot: lot)
        }
        .alert("Rename", isPresented: $renaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Engrave") {
                let name = draftName.trimmed
                if !name.isEmpty { lot.name = name }
            }
        } message: {
            Text("The new name will be engraved on the plaque.")
        }
        .confirmationDialog("Deaccession \(lot.name)?", isPresented: $confirmRelease, titleVisibility: .visible) {
            Button("Deaccession", role: .destructive) {
                ImageStore.evict(lot.id)
                context.delete(lot)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("The lot will be removed from the collection permanently.")
        }
    }

    // MARK: Hero

    private func hero(_ p: LotPresentation) -> some View {
        ZStack {
            PaletteBackdrop(palette: lot.palette)
            Spotlight(intensity: 0.2)
            CutoutArt(image: p.cutout, isCameo: lot.isCameo, marque: lot.marque)
                .overlay {
                    if lot.marque.foilStrength > 0 && !lot.isCameo {
                        FoilSheen(strength: lot.marque.foilStrength * 0.55, hueShift: Double(lot.lotNumber % 7) / 7, marque: lot.marque)
                            .mask(CutoutArt(image: p.cutout, isCameo: false, shadow: false))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 110)
                .padding(.bottom, 70)
                .tiltParallax(10)
        }
        .frame(height: 540)
        .clipped()
    }

    private var topBar: some View {
        HStack {
            GlassIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            GlassIconButton(systemName: "seal", label: "Certificate of provenance") { showCertificate = true }
            Menu {
                Button { draftName = lot.name; renaming = true } label: {
                    Label("Rename", systemImage: "pencil.line")
                }
                Button(role: .destructive) { confirmRelease = true } label: {
                    Label("Deaccession", systemImage: "archivebox")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ivory)
                    .frame(width: 44, height: 44)
                    .maisonGlass(in: Circle())
                .contentShape(Circle())
            }
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 30) {
            titleBlock
            OrnamentRule()
            curatorNote
            section("Temperament") { TemperamentReadout(temperament: lot.temperament) }
                .id("temperament")
            section("The Coat") { PaletteSwatches(palette: lot.palette) }
            section("Provenance") { provenanceTable }
            actions
            footnote
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SmallCaps(Format.lot(lot.lotNumber), size: 10, color: Theme.parchment)
                Hallmark(marque: lot.marque, size: 14)
                SmallCaps(lot.marque.displayName, size: 10, color: lot.marque.accent)
                Spacer()
            }
            Text(lot.name)
                .font(Theme.display(42))
                .foregroundStyle(Theme.ivory)
                .fixedSize(horizontal: false, vertical: true)
            Text(lot.epithet)
                .font(Theme.serifItalic(20))
                .foregroundStyle(Theme.parchment)
            HStack(spacing: 8) {
                Text("“\(lot.motto)”")
                    .font(Theme.serifItalic(15))
                    .foregroundStyle(Theme.champagne)
                Text("— \(lot.mottoTranslation)")
                    .font(Theme.serif(13))
                    .foregroundStyle(Theme.mute)
            }
            .padding(.top, 4)
        }
    }

    private var curatorNote: some View {
        let note = lot.curatorNote
        let first = note.first.map(String.init) ?? ""
        let rest = String(note.dropFirst())
        return VStack(alignment: .leading, spacing: 14) {
            SmallCaps("Curator's Note", size: 10, color: Theme.champagne)
            (Text(first).font(Theme.display(46)).foregroundStyle(Theme.goldSheen)
                + Text(rest).font(Theme.serif(17)).foregroundStyle(Theme.ivory.opacity(0.92)))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Text("The Curator")
                    .font(Theme.script(24))
                    .foregroundStyle(Theme.champagne)
            }
        }
    }

    private var provenanceTable: some View {
        VStack(spacing: 0) {
            row("Acquired", lot.acquiredAt.formatted(Format.longDate))
            row("Hour", lot.hourLabel)
            row("Setting", lot.setting)
            row("Authentication", authentication)
            row("Signature trait", lot.signatureTrait)
            row("Estimate", Format.estimate(lot.valuation))
            Text(lot.provenance)
                .font(Theme.serifItalic(14))
                .foregroundStyle(Theme.parchment)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)
        }
    }

    private var authentication: String {
        if let confidence = lot.catConfidence {
            return "Felis catus · \(Int(confidence * 100))%"
        }
        return "By the curator's eye"
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SmallCaps(label, size: 9, color: Theme.mute, tracking: 1.8)
                Spacer(minLength: 16)
                Text(value)
                    .font(Theme.serif(15))
                    .foregroundStyle(Theme.ivory)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 11)
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                showAudience = true
            } label: {
                Label("Request an Audience", systemImage: "envelope.open")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GoldButtonStyle())
            Button {
                showCertificate = true
            } label: {
                Text("Certificate of Provenance").frame(maxWidth: .infinity)
            }
            .buttonStyle(HairlineButtonStyle())
        }
        .padding(.top, 6)
    }

    private var footnote: some View {
        HStack(spacing: 6) {
            Image(systemName: lot.aiAuthored ? "sparkles" : "pencil.and.scribble")
                .font(.system(size: 11))
            Text(lot.aiAuthored ? "Composed on-device by Apple Intelligence" : "Composed by the house curator")
                .font(Theme.serifItalic(12))
        }
        .foregroundStyle(Theme.mute)
        .frame(maxWidth: .infinity)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                SmallCaps(title, size: 10, color: Theme.champagne)
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
            }
            content()
        }
    }
}

// MARK: - Temperament

struct TemperamentReadout: View {
    let temperament: Temperament
    @State private var shown = false

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Temperament.Trait.allCases, id: \.self) { trait in
                let value = temperament[trait]
                HStack(spacing: 14) {
                    SmallCaps(trait.displayName, size: 9.5, color: Theme.parchment, tracking: 1.8)
                        .frame(width: 92, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                            HStack(spacing: 0) {
                                ForEach(0..<11) { i in
                                    Rectangle().fill(Theme.hairline).frame(width: 0.5, height: i % 5 == 0 ? 7 : 4)
                                    if i < 10 { Spacer(minLength: 0) }
                                }
                            }
                            Rectangle()
                                .fill(Theme.goldGradient)
                                .frame(width: shown ? proxy.size.width * CGFloat(value) / 100 : 0, height: 2)
                            Circle()
                                .fill(Theme.goldLight)
                                .frame(width: 6, height: 6)
                                .shadow(color: Theme.gold, radius: 4)
                                .offset(x: (shown ? proxy.size.width * CGFloat(value) / 100 : 0) - 3)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 10)
                    Text("\(value)")
                        .font(Theme.display(17))
                        .foregroundStyle(trait == temperament.dominant ? Theme.champagne : Theme.ivory)
                        .frame(width: 30, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(trait.displayName) \(value) of 100")
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 1.1, bounce: 0.15).delay(0.15)) { shown = true }
        }
    }
}

// MARK: - Palette

struct PaletteSwatches: View {
    let palette: [Swatch]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(palette) { swatch in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(swatch.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(.white).colorEffect(ShaderLibrary.grain(.float(0.07))).blendMode(.overlay)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 0.5))
                        .frame(height: 64)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
                    Text(swatch.name)
                        .font(Theme.serifItalic(13))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    SmallCaps(swatch.hex, size: 7.5, color: Theme.mute, tracking: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(swatch.name), \(Int(swatch.share * 100)) percent of the coat")
            }
        }
    }
}
