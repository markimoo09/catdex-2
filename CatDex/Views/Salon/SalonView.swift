import SwiftData
import SwiftUI

/// Home: today's pick, daily commissions, the next show, recent finds.
struct SalonView: View {
    let zoom: Namespace.ID
    @Environment(Router.self) private var router
    @Environment(Game.self) private var game
    @Query(sort: \Acquisition.lotNumber, order: .reverse) private var lots: [Acquisition]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                greeting
                if let featured = PieceDuJour.pick(from: lots) {
                    PieceDuJourCard(lot: featured, zoom: zoom) { router.paths[.salon, default: []].append(featured.id) }
                } else {
                    WelcomeCard { router.isAcquiring = true }
                }
                CommissionBoard()
                ShowBanner(lotCount: lots.count) { router.tab = .concours }
                if !lots.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Recent finds", trailing: "\(lots.count) in collection")
                        recent
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var greeting: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(greetingText)
                .font(Theme.display(26))
                .tracking(Theme.displayTracking)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(Theme.caption(12))
                .foregroundStyle(Theme.ink3)
        }
    }

    private var greetingText: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private var recent: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(lots.prefix(10)) { lot in
                    Button { router.paths[.salon, default: []].append(lot.id) } label: {
                        LotCard(lot: lot.presentation, compact: true, showsFoil: false)
                            .frame(width: 98)
                            .matchedTransitionSource(id: lot.id, in: zoom)
                    }
                    .buttonStyle(PressScale())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }
}

// MARK: - Pièce du jour

struct PieceDuJourCard: View {
    let lot: Acquisition
    let zoom: Namespace.ID
    var open: () -> Void

    var body: some View {
        let p = lot.presentation
        Button(action: open) {
            HStack(spacing: 0) {
                ZStack {
                    PaletteBackdrop(palette: lot.palette, marque: lot.marque)
                    Spotlight(color: .white, intensity: 0.6)
                    CutoutArt(image: p.cutout, isCameo: lot.isCameo, marque: lot.marque)
                        .padding(12)
                        .tiltParallax(4)
                }
                .frame(width: 138)
                .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Pièce du jour")
                            .font(Theme.caption(11, weight: .semibold))
                            .foregroundStyle(Theme.roseDeep)
                        Spacer()
                        Hallmark(marque: lot.marque, size: 15)
                    }
                    Text(lot.name)
                        .font(Theme.display(19))
                        .tracking(-0.3)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(lot.epithet)
                        .font(Theme.body(12.5))
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        MarquePill(marque: lot.marque)
                        let top = lot.temperament.dominant
                        Pill(text: "\(top.displayName) \(lot.temperament[top])", fill: top.color.opacity(0.16), ink: top.color, symbol: top.symbol)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 168)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 0.5))
            .shadow(color: Color(hex: 0x8A5A50, alpha: 0.12), radius: 14, y: 6)
            .matchedTransitionSource(id: lot.id, in: zoom)
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("Pièce du jour: \(lot.name), \(lot.marque.displayName)")
    }
}

struct WelcomeCard: View {
    var acquire: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.roseGold).frame(width: 56, height: 56)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Begin your collection")
                    .font(Theme.title(17))
                    .foregroundStyle(Theme.ink)
                Text("Your first lot awaits.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.ink2)
            }
            Spacer(minLength: 0)
        }
        .pearlCard(20)
        .contentShape(Rectangle())
        .onTapGesture(perform: acquire)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Commissions

struct CommissionBoard: View {
    @Environment(Game.self) private var game

    var body: some View {
        let board = game.commissions
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Today's commissions", trailing: "\(board.filter(\.claimed).count) of \(board.count) done")
            VStack(spacing: 0) {
                ForEach(Array(board.enumerated()), id: \.element.id) { index, status in
                    CommissionRow(status: status) { game.claim(status) }
                    if index < board.count - 1 {
                        Rectangle().fill(Theme.hairline).frame(height: 0.5).padding(.leading, 52)
                    }
                }
            }
            .pearlCard(18, padding: 4)
        }
    }
}

struct CommissionRow: View {
    let status: CommissionStatus
    var claim: () -> Void

    var body: some View {
        let c = status.commission
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(status.claimed ? Theme.win.opacity(0.15) : Theme.blush)
                Image(systemName: status.claimed ? "checkmark" : c.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(status.claimed ? Theme.win : Theme.roseDeep)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(c.title)
                        .font(Theme.title(14))
                        .foregroundStyle(status.claimed ? Theme.ink3 : Theme.ink)
                        .strikethrough(status.claimed, color: Theme.ink3)
                    Spacer()
                    Text("\(status.progress)/\(c.goal)")
                        .font(Theme.number(11, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
                HStack(spacing: 8) {
                    ProgressBar(value: Double(status.progress) / Double(c.goal), height: 4)
                    HStack(spacing: 6) {
                        CoinAmount(value: c.guineas, size: 10)
                        Text("\(c.xp) XP")
                            .font(Theme.number(10, weight: .bold))
                            .foregroundStyle(Theme.roseDeep)
                    }
                    .fixedSize()
                }
            }

            if status.isClaimable {
                Button("Claim", action: claim)
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .animation(.spring(duration: 0.4), value: status)
    }
}

// MARK: - Show banner

struct ShowBanner: View {
    let lotCount: Int
    var open: () -> Void
    @Environment(Game.self) private var game

    var body: some View {
        let tier = ShowTier.all.last { game.isUnlocked($0) } ?? .fete
        Button(action: open) {
            HStack(spacing: 14) {
                Rosette(tier: tier, size: 52, label: "")
                    .frame(width: 56, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tier.name)
                        .font(Theme.title(16))
                        .foregroundStyle(Theme.ink)
                    Text(lotCount >= 3 ? "\(tier.venue) · prize \(tier.prize.formatted()) gns" : "Needs three cats")
                        .font(Theme.body(12.5))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink3)
            }
            .pearlCard(18, padding: 12)
        }
        .buttonStyle(PressScale())
    }
}
