import SwiftData
import SwiftUI

struct DossierView: View {
    @Bindable var lot: Acquisition
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Game.self) private var game
    @Environment(Motion.self) private var motion
    @Environment(Router.self) private var router
    @State private var showCertificate = DebugHooks.open == "certificate"
    @State private var showAudience = DebugHooks.open == "audience"
    @State private var renaming = false
    @State private var draftName = ""
    @State private var confirmRelease = false
    @State private var pastHero = false

    var body: some View {
        let presentation = lot.presentation
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 0) {
                    hero(presentation)
                    content
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 40)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                                .fill(Theme.pearl)
                                .shadow(color: Color(hex: 0x8A5A50, alpha: 0.12), radius: 16, y: -4)
                        )
                        .padding(.top, -28)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 300 } action: { _, past in
                withAnimation(.easeOut(duration: 0.2)) { pastHero = past }
            }
            .task {
                if DebugHooks.scrollDown || DebugHooks.open == "groom" {
                    try? await Task.sleep(for: .milliseconds(700))
                    withAnimation { reader.scrollTo("temperament", anchor: .top) }
                }
            }
        }
        .background(Theme.pearl.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) { topBar }
        .sheet(isPresented: $showCertificate) {
            CertificateView(lot: lot)
                .presentationBackground(Theme.pearl)
                .presentationCornerRadius(30)
        }
        .fullScreenCover(isPresented: $showAudience) {
            AudienceView(lot: lot)
                .environment(game)
                .environment(motion)
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
            PaletteBackdrop(palette: lot.palette, marque: lot.marque)
            Spotlight(color: lot.marque == .noir ? Theme.rose : .white, intensity: lot.marque == .noir ? 0.3 : 0.7)
            CutoutArt(image: p.cutout, isCameo: lot.isCameo, marque: lot.marque)
                .overlay {
                    if lot.marque.foilStrength > 0 && !lot.isCameo {
                        FoilSheen(strength: lot.marque.foilStrength * 0.6, hueShift: Double(lot.lotNumber % 7) / 7, marque: lot.marque)
                            .mask(CutoutArt(image: p.cutout, isCameo: false, shadow: false))
                    }
                }
                .padding(.horizontal, 48)
                .padding(.top, 96)
                .padding(.bottom, 52)
                .tiltParallax(8)
        }
        .frame(height: 420)
        .clipped()
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            GlassIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            CoinAmount(value: game.ledger.guineas, size: 12)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(Color.white.opacity(0.7)))
                .maisonGlass(in: Capsule())
            Menu {
                Button { draftName = lot.name; renaming = true } label: { Label("Rename", systemImage: "pencil.line") }
                Button(role: .destructive) { confirmRelease = true } label: { Label("Deaccession", systemImage: "archivebox") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.7)))
                    .maisonGlass(in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background {
            if pastHero {
                Theme.pearl
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 0.5) }
                    .transition(.opacity)
            }
        }
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            titleBlock
            actions
            temperament
                .id("temperament")
            curatorNote
            coat
            provenance
            footnote
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(String(format: "№ %03d", lot.lotNumber))
                    .font(Theme.number(12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                MarquePill(marque: lot.marque)
                if lot.showWins > 0 {
                    Pill(text: "\(lot.showWins) wins", fill: Theme.blush, ink: Theme.roseDeep, symbol: "rosette")
                }
                Spacer()
                CoinAmount(value: lot.valuation, size: 13)
            }
            Text(lot.name)
                .font(Theme.display(28))
                .tracking(Theme.displayTracking)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(lot.epithet)
                .font(Theme.body(15, weight: .medium))
                .foregroundStyle(Theme.ink2)
            Text("“\(lot.motto)” · \(lot.mottoTranslation)")
                .font(Theme.body(12.5).italic())
                .foregroundStyle(Theme.ink3)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            action("Audience", "bubble.left.and.text.bubble.right.fill") { showAudience = true }
            action("Certificate", "seal.fill") { showCertificate = true }
            action("Shows", "trophy.fill") {
                router.paths[router.tab] = []
                router.tab = .concours
            }
        }
    }

    private func action(_ title: String, _ symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.roseDeep)
                Text(title)
                    .font(Theme.caption(12, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline, lineWidth: 0.5))
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(title == "Audience" ? "Request an Audience" : title)
    }

    private var temperament: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Temperament")
            VStack(spacing: 10) {
                ForEach(Temperament.Trait.allCases, id: \.self) { trait in
                    GroomRow(lot: lot, trait: trait)
                }
            }
            .pearlCard(18, padding: 12)
        }
    }

    private var curatorNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Curator's note")
            VStack(alignment: .leading, spacing: 8) {
                Text(lot.curatorNote)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Image(systemName: lot.aiAuthored ? "sparkles" : "pencil.and.scribble")
                        .font(.system(size: 10))
                    Text(lot.aiAuthored ? "Written on-device by Apple Intelligence" : "Written by the house curator")
                        .font(Theme.caption(11))
                }
                .foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pearlCard(18, padding: 14)
        }
    }

    private var coat: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "The coat")
            HStack(alignment: .top, spacing: 8) {
                ForEach(lot.palette) { swatch in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(swatch.color)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .frame(width: 38, height: 38)
                            .shadow(color: Color(hex: 0x5A3A30, alpha: 0.18), radius: 4, y: 2)
                        Text(swatch.name)
                            .font(Theme.caption(11.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("\(Int(swatch.share * 100))%")
                            .font(Theme.number(10, weight: .medium))
                            .foregroundStyle(Theme.ink3)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(swatch.name), \(Int(swatch.share * 100)) percent of the coat")
                }
            }
            .pearlCard(18, padding: 12)
        }
    }

    private var provenance: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Provenance")
            VStack(spacing: 0) {
                row("Acquired", lot.acquiredAt.formatted(Format.longDate))
                row("Hour", lot.hourLabel)
                row("Setting", lot.setting)
                row("Authentication", lot.catConfidence.map { "Felis catus · \(Int($0 * 100))%" } ?? "By the curator's eye")
                row("Estimate", Format.estimate(lot.valuation))
                row("Show record", "\(lot.showWins) of \(lot.showRounds) rounds won", last: true)
            }
            .pearlCard(18, padding: 12)
        }
    }

    private func row(_ label: String, _ value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(Theme.body(13)).foregroundStyle(Theme.ink3)
                Spacer(minLength: 12)
                Text(value).font(Theme.body(13.5, weight: .medium)).foregroundStyle(Theme.ink).multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 8)
            if !last { Rectangle().fill(Theme.hairline).frame(height: 0.5) }
        }
    }

    private var footnote: some View {
        Text(lot.provenance)
            .font(Theme.caption(12))
            .foregroundStyle(Theme.ink3)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

// MARK: - Grooming

/// A temperament reading with an inline grooming button.
struct GroomRow: View {
    let lot: Acquisition
    let trait: Temperament.Trait
    @Environment(Game.self) private var game
    @State private var pulse = 0

    var body: some View {
        let value = lot.temperament[trait]
        let cost = Grooming.cost(currentValue: value)
        let maxed = value >= 100
        let affordable = game.ledger.guineas >= cost
        HStack(spacing: 10) {
            Image(systemName: trait.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(trait.color)
                .frame(width: 24, height: 24)
                .background(Circle().fill(trait.color.opacity(0.14)))
            Text(trait.displayName)
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 72, alignment: .leading)
            ProgressBar(value: Double(value) / 100, tint: AnyShapeStyle(trait.color), height: 6)
            Text("\(value)")
                .font(Theme.number(14, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(width: 28, alignment: .trailing)
                .contentTransition(.numericText(value: Double(value)))
                .scaleEffect(pulse > 0 ? 1 : 1)
            Button {
                if game.groom(lot, trait) {
                    pulse += 1
                }
            } label: {
                HStack(spacing: 2) {
                    Text(maxed ? "Max" : "+\(Grooming.gain)")
                        .font(Theme.number(11, weight: .heavy))
                    if !maxed {
                        CoinGlyph(size: 9)
                        Text(Format.compact(cost)).font(Theme.number(10, weight: .semibold))
                    }
                }
                .foregroundStyle(maxed || !affordable ? Theme.ink3 : Theme.roseDeep)
                .padding(.horizontal, 7)
                .frame(height: 26)
                .background(Capsule().fill(maxed || !affordable ? Theme.surfaceSunk : Theme.blush))
            }
            .buttonStyle(PressScale())
            .disabled(maxed || !affordable)
            .accessibilityLabel(maxed ? "\(trait.displayName) is at its peak" : "Groom \(trait.displayName) for \(cost) guineas")
        }
        .animation(.spring(duration: 0.4), value: value)
        .sensoryFeedback(.increase, trigger: pulse)
        .accessibilityElement(children: .contain)
    }
}
