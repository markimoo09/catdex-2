import SwiftData
import SwiftUI

struct SalonView: View {
    let zoom: Namespace.ID
    @Environment(Router.self) private var router
    @Query(sort: \Acquisition.lotNumber, order: .reverse) private var lots: [Acquisition]

    private var patronage: Patronage { Patronage(lots: lots.map(LotSummary.init)) }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    header
                    if let featured = PieceDuJour.pick(from: lots) {
                        pieceDuJour(featured)
                    } else {
                        EmptySalon { router.isAcquiring = true }
                    }
                    section("Patronage") {
                        PatronCard(patronage: patronage)
                    }
                    section("Exhibitions", trailing: "\(patronage.completedExhibitions) of \(patronage.exhibitions.count)") {
                        ExhibitionsRow(exhibitions: patronage.exhibitions)
                    }
                    .id("exhibitions")
                    if lots.count > 1 {
                        section("Recent Acquisitions") { recent }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(backdrop)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if DebugHooks.scrollDown {
                    try? await Task.sleep(for: .milliseconds(600))
                    reader.scrollTo("exhibitions", anchor: .top)
                }
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            Theme.ink
            Spotlight(color: Theme.champagne, intensity: 0.08)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("CATDEX")
                    .font(Theme.display(20))
                    .tracking(7)
                    .foregroundStyle(Theme.goldSheen)
                Spacer()
                SmallCaps(Date.now.formatted(Format.editorialDate), size: 9.5, color: Theme.mute, tracking: 2)
            }
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
            Text(greeting)
                .font(Theme.displayItalic(36))
                .foregroundStyle(Theme.ivory)
                .padding(.top, 6)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning."
        case 12..<18: return "Good afternoon."
        default: return "Good evening."
        }
    }

    // MARK: Pièce du jour

    private func pieceDuJour(_ lot: Acquisition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SmallCaps("Pièce du Jour", size: 10, color: Theme.champagne)
                Spacer()
                SmallCaps(Format.estimate(lot.valuation), size: 9, color: Theme.mute, tracking: 1.6)
            }
            Button {
                router.salonPath.append(lot.id)
            } label: {
                LotCard(lot: lot.presentation)
                    .matchedTransitionSource(id: lot.id, in: zoom)
            }
            .buttonStyle(PressScale())
            Text("“\(lot.motto)”")
                .font(Theme.serifItalic(15))
                .foregroundStyle(Theme.parchment)
                + Text("  — \(lot.mottoTranslation)")
                .font(Theme.serif(13))
                .foregroundStyle(Theme.mute)
        }
    }

    // MARK: Recent

    private var recent: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(lots.prefix(8)) { lot in
                    Button {
                        router.salonPath.append(lot.id)
                    } label: {
                        LotCard(lot: lot.presentation, compact: true, showsFoil: false)
                            .frame(width: 132)
                            .matchedTransitionSource(id: lot.id, in: zoom)
                    }
                    .buttonStyle(PressScale())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
    }

    // MARK: Section chrome

    private func section<Content: View>(_ title: String, trailing: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SmallCaps(title, size: 10, color: Theme.champagne)
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
                if let trailing {
                    SmallCaps(trailing, size: 9, color: Theme.mute, tracking: 1.6)
                }
            }
            content()
        }
    }
}

// MARK: - Empty state

struct EmptySalon: View {
    var acquire: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Spotlight(color: Theme.champagne, intensity: 0.2)
                    .frame(height: 260)
                VStack(spacing: 0) {
                    Spacer()
                    Plinth(width: 150)
                }
                .frame(height: 240)
            }
            Text("The gallery awaits\nits first acquisition.")
                .font(Theme.displayItalic(26))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ivory)
            Button("Acquire", action: acquire)
                .buttonStyle(GoldButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

/// A marble plinth with a brass plaque.
struct Plinth: View {
    var width: CGFloat
    var plaque: String?

    var body: some View {
        VStack(spacing: 0) {
            // Capital
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [Color(hex: 0x3A3836), Color(hex: 0x1E1D1C)], startPoint: .top, endPoint: .bottom))
                .frame(width: width * 1.08, height: width * 0.07)
            // Shaft
            ZStack {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: 0x141414), Color(hex: 0x2C2B29), Color(hex: 0x353331), Color(hex: 0x1A1A19)],
                                         startPoint: .leading, endPoint: .trailing))
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.grain(.float(0.08)))
                    .blendMode(.overlay)
                    .opacity(0.35)
                if let plaque {
                    Text(plaque)
                        .font(Theme.label(7.5, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Color(hex: 0x2A1E0E))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 1.5).fill(Theme.goldGradient))
                        .padding(.horizontal, 12)
                }
            }
            .frame(width: width, height: width * 0.62)
            // Base
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [Color(hex: 0x2E2D2B), Color(hex: 0x111111)], startPoint: .top, endPoint: .bottom))
                .frame(width: width * 1.14, height: width * 0.08)
        }
        .shadow(color: .black.opacity(0.6), radius: 14, y: 10)
        .accessibilityHidden(true)
    }
}
