import SwiftData
import SwiftUI

/// The patron's profile: membership card, record, rosettes, marques, exhibitions.
struct PatronView: View {
    @Environment(Game.self) private var game
    @Query(sort: \Acquisition.lotNumber, order: .reverse) private var lots: [Acquisition]
    @State private var focused: Exhibition?

    private var stats: CollectionStats { CollectionStats(lots: lots.map(LotSummary.init)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PatronCard(memberSince: stats.memberSince ?? game.ledger.createdAt)
                record
                rosettes
                marques
                exhibitions
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $focused) { exhibition in
            ExhibitionDetail(exhibition: exhibition)
                .presentationDetents([.height(300)])
                .presentationBackground(Theme.pearl)
                .presentationCornerRadius(28)
        }
    }

    private var record: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(title: "Collection value", symbol: "banknote", value: Format.compact(stats.appraisal) + " gns")
            StatTile(title: "Lots", symbol: "square.grid.2x2", value: "\(stats.lotCount)")
            StatTile(title: "Shows won", symbol: "trophy", value: "\(game.ledger.showsWon) / \(game.ledger.showsEntered)")
            StatTile(title: "Purse", symbol: "dollarsign.circle", value: game.ledger.guineas.formatted() + " gns")
        }
    }

    private var rosettes: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Rosette cabinet", trailing: "\(game.ledger.rosettes.values.reduce(0, +)) won")
            HStack(spacing: 0) {
                ForEach(ShowTier.all) { tier in
                    let count = game.ledger.rosettes[tier.id] ?? 0
                    VStack(spacing: 4) {
                        Rosette(tier: tier, size: 46, label: count > 0 ? "\(count)" : "")
                            .frame(width: 50, height: 60)
                            .saturation(count > 0 ? 1 : 0)
                            .opacity(count > 0 ? 1 : 0.35)
                        Text(tier.name)
                            .font(Theme.caption(10, weight: .medium))
                            .foregroundStyle(count > 0 ? Theme.ink2 : Theme.ink3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(tier.name): \(count) rosettes")
                }
            }
            .pearlCard(18, padding: 12)
        }
    }

    private var marques: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Marques held")
            HStack(spacing: 8) {
                ForEach(Marque.allCases) { marque in
                    let count = lots.filter { $0.marque == marque }.count
                    VStack(spacing: 6) {
                        Hallmark(marque: marque, size: 22)
                            .saturation(count > 0 ? 1 : 0)
                            .opacity(count > 0 ? 1 : 0.4)
                        Text("\(count)")
                            .font(Theme.number(15))
                            .foregroundStyle(count == 0 ? Theme.ink3 : marque == .noir ? .white : Theme.ink)
                        Text(marque.displayName)
                            .font(Theme.caption(10))
                            .foregroundStyle(count > 0 && marque == .noir ? Theme.roseLight : Theme.ink3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(count > 0 ? marque.tone.opacity(0.6) : Theme.surfaceSunk))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(count) \(marque.displayName)")
                }
            }
        }
    }

    private var exhibitions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Exhibitions", trailing: "\(stats.completedExhibitions) of \(stats.exhibitions.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                ForEach(stats.exhibitions) { exhibition in
                    Button { focused = exhibition } label: { Medallion(exhibition: exhibition, size: 52) }
                        .buttonStyle(PressScale())
                }
            }
            .pearlCard(18, padding: 12)
        }
    }
}

// MARK: - Membership card

struct PatronCard: View {
    let memberSince: Date
    @Environment(Game.self) private var game
    @Environment(Motion.self) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tilt = reduceMotion ? .zero : motion.tilt
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0xE4A28C), Color(hex: 0xCF866F), Color(hex: 0xB46C59), Color(hex: 0xD7937D)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.brushedMetal(.float2(proxy.size), .float2(Float(tilt.width), Float(tilt.height))))
                }
            Guilloche(color: Color.white.opacity(0.28), lineWidth: 0.4, petals: 14, bands: 3, strands: 20)
                .frame(width: 240, height: 240)
                .offset(x: 170, y: -50)
            FoilSheen(strength: 0.35, marque: .gold)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Maison CatDex")
                            .font(Theme.title(13))
                        Text("Carte de Patron")
                            .font(Theme.caption(11))
                            .opacity(0.8)
                    }
                    Spacer()
                    LevelRing(level: game.level, progress: game.levelProgress, size: 44)
                }
                Spacer(minLength: 8)
                Text(game.title)
                    .font(Theme.display(26))
                    .tracking(Theme.displayTracking)
                Text("Member since \(memberSince.formatted(.dateTime.month(.wide).year()))")
                    .font(Theme.caption(11.5))
                    .opacity(0.85)
                Spacer(minLength: 10)
                HStack {
                    Text("Level \(game.level)")
                        .font(Theme.number(12, weight: .heavy))
                    Spacer()
                    Text("\(game.xpIntoLevel) / \(game.xpForLevel) XP")
                        .font(Theme.number(11, weight: .semibold))
                        .opacity(0.85)
                }
                ProgressBar(value: game.levelProgress, tint: AnyShapeStyle(Color.white), height: 5)
                    .padding(.top, 5)
            }
            .foregroundStyle(.white)
            .padding(18)
        }
        .aspectRatio(1.7, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.6), lineWidth: 1))
        .rotation3DEffect(.degrees(Double(tilt.width) * 5), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(Double(-tilt.height) * 4), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .shadow(color: Theme.rose.opacity(0.35), radius: 18, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Patron card. Level \(game.level), \(game.title).")
    }
}

struct StatTile: View {
    let title: String
    let symbol: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.roseDeep)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.blush))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(Theme.number(16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(Theme.caption(11))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 0)
        }
        .pearlCard(16, padding: 10)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Exhibitions

struct Medallion: View {
    let exhibition: Exhibition
    var size: CGFloat = 52

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if exhibition.isComplete {
                    Circle().fill(Theme.roseGold)
                    Circle().stroke(Color.white.opacity(0.7), lineWidth: 1).padding(4)
                    Image(systemName: exhibition.symbol)
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Circle().fill(Theme.surfaceSunk)
                    Circle()
                        .trim(from: 0, to: exhibition.progress)
                        .stroke(Theme.rose, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(1.5)
                    Image(systemName: exhibition.symbol)
                        .font(.system(size: size * 0.32, weight: .regular))
                        .foregroundStyle(Theme.ink3)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: exhibition.isComplete ? Theme.rose.opacity(0.35) : .clear, radius: 6, y: 3)
            Text(exhibition.title)
                .font(Theme.caption(10, weight: .medium))
                .foregroundStyle(exhibition.isComplete ? Theme.ink : Theme.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exhibition.title), \(exhibition.subtitle). \(exhibition.current) of \(exhibition.goal).")
    }
}

struct ExhibitionDetail: View {
    let exhibition: Exhibition

    var body: some View {
        VStack(spacing: 14) {
            Medallion(exhibition: exhibition, size: 84)
            Text(exhibition.subtitle)
                .font(Theme.title(17))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            ProgressBar(value: exhibition.progress)
                .frame(width: 160)
            Text("\(exhibition.current) of \(exhibition.goal)")
                .font(Theme.number(13, weight: .semibold))
                .foregroundStyle(Theme.ink3)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
