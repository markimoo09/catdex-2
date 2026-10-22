import SwiftData
import SwiftUI

// MARK: - Lobby

/// The Shows tab: every concours tier, locked by patron level.
struct ConcoursLobby: View {
    @Environment(Game.self) private var game
    @Environment(Router.self) private var router
    @Environment(Motion.self) private var motion
    @Query(sort: \Acquisition.lotNumber, order: .reverse) private var lots: [Acquisition]
    @State private var entering: ShowTier?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Concours")
                        .font(Theme.display(26))
                        .tracking(Theme.displayTracking)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(game.ledger.showsWon) won")
                        .font(Theme.caption(12))
                        .foregroundStyle(Theme.ink3)
                }
                ForEach(ShowTier.all) { tier in
                    TierCard(tier: tier, unlocked: game.isUnlocked(tier), affordable: game.ledger.guineas >= tier.entryFee,
                             teamReady: lots.count >= 3) {
                        if lots.count < 3 { router.isAcquiring = true } else { entering = tier }
                    }
                }
                rules
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $entering) { tier in
            ConcoursFlow(tier: tier)
                .environment(game)
                .environment(motion)
        }
        .task(id: lots.count) {
            if DebugHooks.open == "match", lots.count >= 3, entering == nil, game.ledger.showsEntered == 0 { entering = .fete }
        }
    }

    private var rules: some View {
        HStack(spacing: 12) {
            ForEach(Temperament.Trait.allCases, id: \.self) { trait in
                VStack(spacing: 4) {
                    Image(systemName: trait.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(trait.color)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(trait.color.opacity(0.14)))
                    Text(trait.displayName)
                        .font(Theme.caption(10))
                        .foregroundStyle(Theme.ink3)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .pearlCard(18, padding: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Judging categories: poise, charm, mischief, languor, curiosity")
    }
}

struct TierCard: View {
    let tier: ShowTier
    let unlocked: Bool
    let affordable: Bool
    let teamReady: Bool
    var enter: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Rosette(tier: tier, size: 54, label: "")
                .frame(width: 58, height: 70)
                .saturation(unlocked ? 1 : 0)
                .opacity(unlocked ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.name)
                    .font(Theme.title(16))
                    .foregroundStyle(unlocked ? Theme.ink : Theme.ink3)
                Text(tier.venue)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.ink3)
                HStack(spacing: 6) {
                    Pill(text: "Prize \(Format.compact(tier.prize))", fill: Theme.champagne, ink: Theme.coinDeep, symbol: "trophy.fill")
                    Pill(text: "\(tier.xp) XP", fill: Theme.blush, ink: Theme.roseDeep)
                }
            }
            Spacer(minLength: 0)
            if unlocked {
                Button(action: enter) {
                    VStack(spacing: 1) {
                        Text(teamReady ? "Enter" : "Acquire")
                        if teamReady && tier.entryFee > 0 {
                            Text("\(tier.entryFee) gns").font(Theme.number(10, weight: .semibold)).opacity(0.85)
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))
                .disabled(teamReady && !affordable)
                .opacity(teamReady && !affordable ? 0.5 : 1)
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "lock.fill").font(.system(size: 14, weight: .semibold))
                    Text("Lv \(tier.unlockLevel)").font(Theme.number(11, weight: .bold))
                }
                .foregroundStyle(Theme.ink3)
                .frame(width: 56)
            }
        }
        .pearlCard(20, padding: 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Flow

/// Team selection → match → result, presented full screen.
struct ConcoursFlow: View {
    let tier: ShowTier
    @Environment(\.dismiss) private var dismiss
    @Environment(Game.self) private var game
    @Environment(\.modelContext) private var context
    @Query(sort: \Acquisition.lotNumber, order: .reverse) private var lots: [Acquisition]
    @State private var match: ConcoursMatch?
    @State private var recorded = false

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            if let match {
                MatchView(match: match, lots: lotsByID) {
                    record(match)
                } onAgain: {
                    self.match = nil
                    recorded = false
                } onDone: {
                    dismiss()
                }
                .transition(.opacity)
            } else {
                TeamPicker(tier: tier, lots: lots) { team in begin(with: team) } onClose: { dismiss() }
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: match == nil)
    }

    private var lotsByID: [UUID: Acquisition] {
        Dictionary(uniqueKeysWithValues: lots.map { ($0.id, $0) })
    }

    private func begin(with team: [Acquisition]) {
        guard game.spend(tier.entryFee) else { return }
        match = ConcoursMatch(tier: tier, team: team.map(Contender.init))
    }

    private func record(_ match: ConcoursMatch) {
        guard !recorded else { return }
        recorded = true
        for round in match.rounds {
            guard let id = round.patron.lotID, let lot = lotsByID[id] else { continue }
            lot.showRounds += 1
            if round.patronWon { lot.showWins += 1 }
        }
        try? context.save()
        game.recordShow(tier, won: match.patronWon)
    }
}

// MARK: - Team picker

struct TeamPicker: View {
    let tier: ShowTier
    let lots: [Acquisition]
    var begin: ([Acquisition]) -> Void
    var onClose: () -> Void
    @Environment(Game.self) private var game
    @State private var picked: [UUID] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                GlassIconButton(systemName: "xmark", label: "Close", action: onClose)
                Spacer()
                VStack(spacing: 1) {
                    Text(tier.name).font(Theme.title(16)).foregroundStyle(Theme.ink)
                    Text("Choose three cats").font(Theme.caption(12)).foregroundStyle(Theme.ink3)
                }
                Spacer()
                CoinAmount(value: game.ledger.guineas, size: 12)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            HStack(spacing: 10) {
                ForEach(0..<3) { slot in
                    slotView(slot)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                    ForEach(lots) { lot in
                        let order = picked.firstIndex(of: lot.id)
                        Button { toggle(lot) } label: {
                            VStack(spacing: 5) {
                                LotCard(lot: lot.presentation, compact: true, showsFoil: false)
                                    .overlay(alignment: .topLeading) {
                                        if let order {
                                            Text("\(order + 1)")
                                                .font(Theme.number(12, weight: .heavy))
                                                .foregroundStyle(.white)
                                                .frame(width: 22, height: 22)
                                                .background(Circle().fill(Theme.roseGold))
                                                .offset(x: -5, y: -5)
                                        }
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Theme.rose, lineWidth: order == nil ? 0 : 2.5)
                                    )
                                TraitStrip(temperament: lot.temperament)
                            }
                        }
                        .buttonStyle(PressScale())
                        .accessibilityLabel("\(lot.name)\(order != nil ? ", selected" : "")")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .padding(.bottom, 90)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button("Best three") {
                    withAnimation(.spring(duration: 0.35)) { picked = Concours.suggestedTeam(from: lots).map(\.id) }
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
                Button {
                    begin(picked.compactMap { id in lots.first { $0.id == id } })
                } label: {
                    Text(tier.entryFee > 0 ? "Enter · \(tier.entryFee) gns" : "Enter the ring")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(picked.count < 3)
                .opacity(picked.count < 3 ? 0.5 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.pearl.opacity(0.95).ignoresSafeArea())
        }
        .sensoryFeedback(.selection, trigger: picked)
        .onAppear { if picked.isEmpty { picked = Concours.suggestedTeam(from: lots).map(\.id) } }
        .task {
            if DebugHooks.autoMatch {
                try? await Task.sleep(for: .milliseconds(900))
                begin(Concours.suggestedTeam(from: lots))
            }
        }
    }

    private func slotView(_ slot: Int) -> some View {
        let lot = slot < picked.count ? lots.first { $0.id == picked[slot] } : nil
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(lot == nil ? Theme.surfaceSunk : Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(lot == nil ? Theme.hairline : Theme.rose.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: lot == nil ? [4, 3] : [])))
            if let lot {
                HStack(spacing: 6) {
                    CutoutArt(image: ImageStore.cutout(for: lot), isCameo: lot.isCameo, marque: lot.marque, shadow: false)
                        .frame(width: 30, height: 34)
                    Text(lot.name.components(separatedBy: " ").last ?? lot.name)
                        .font(Theme.title(11.5))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 6)
            } else {
                Text("\(slot + 1)")
                    .font(Theme.number(14))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .frame(height: 46)
        .frame(maxWidth: .infinity)
    }

    private func toggle(_ lot: Acquisition) {
        withAnimation(.spring(duration: 0.3)) {
            if let index = picked.firstIndex(of: lot.id) {
                picked.remove(at: index)
            } else if picked.count < 3 {
                picked.append(lot.id)
            } else {
                picked[2] = lot.id
            }
        }
    }
}

/// Five tiny trait bars under a card.
struct TraitStrip: View {
    let temperament: Temperament
    var highlight: Temperament.Trait?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Temperament.Trait.allCases, id: \.self) { trait in
                VStack(spacing: 2) {
                    GeometryReader { proxy in
                        ZStack(alignment: .bottom) {
                            Capsule().fill(Theme.surfaceSunk)
                            Capsule().fill(trait.color.opacity(highlight == nil || highlight == trait ? 1 : 0.3))
                                .frame(height: proxy.size.height * CGFloat(temperament[trait]) / 100)
                        }
                    }
                    .frame(width: 5, height: 18)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Match

struct MatchView: View {
    let match: ConcoursMatch
    let lots: [UUID: Acquisition]
    var onFinish: () -> Void
    var onAgain: () -> Void
    var onDone: () -> Void
    @Environment(Game.self) private var game
    @State private var reveal = 0.0
    @State private var bump = 0

    var body: some View {
        VStack(spacing: 12) {
            scoreboard
            if match.phase == .finished {
                MatchResult(match: match, canAgain: game.ledger.guineas >= match.tier.entryFee, onAgain: onAgain, onDone: onDone)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                judgeCard
                rivalRow
                if match.phase == .reveal, let round = match.lastRound {
                    FaceOff(round: round, patronLot: round.patron.lotID.flatMap { lots[$0] }, rivalName: match.rival.name, progress: reveal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    Button(match.isDecided ? "See the verdict" : "Next round") {
                        withAnimation(.spring(duration: 0.45)) { match.advance() }
                        if match.phase == .finished { onFinish() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .opacity(reveal >= 1 ? 1 : 0)
                } else {
                    hand
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .animation(.spring(duration: 0.45), value: match.phase)
        .task(id: match.rounds.count * 10 + (match.phase == .reveal ? 1 : 0)) { await autoPlayStep() }
        .sensoryFeedback(.impact(weight: .medium), trigger: match.rounds.count)
        .sensoryFeedback(trigger: bump) { _, _ in
            match.lastRound?.patronWon == true ? .success : .warning
        }
    }

    /// DEBUG: plays the best cat for each category, then advances.
    private func autoPlayStep() async {
        guard DebugHooks.autoPlay else { return }
        try? await Task.sleep(for: .milliseconds(match.phase == .reveal ? 2600 : 1300))
        switch match.phase {
        case .choosing:
            let trait = match.currentTrait
            if let best = match.hand.max(by: { $0.base(for: trait) < $1.base(for: trait) }) { send(best) }
        case .reveal:
            withAnimation(.spring(duration: 0.45)) { match.advance() }
            if match.phase == .finished { onFinish() }
        case .finished:
            break
        }
    }

    private func send(_ cat: Contender) {
        reveal = 0
        withAnimation(.spring(duration: 0.45)) { match.play(cat) }
        withAnimation(.easeOut(duration: 1.1).delay(0.35)) { reveal = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            bump += 1
        }
    }

    private var scoreboard: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                LevelRing(level: game.level, progress: game.levelProgress, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text("You").font(Theme.title(13)).foregroundStyle(Theme.ink)
                    pips(match.patronWins, tint: Theme.rose)
                }
            }
            Spacer()
            VStack(spacing: 0) {
                Text("Round \(min(match.rounds.count + (match.phase == .choosing ? 1 : 0), 3)) of 3")
                    .font(Theme.caption(11, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                Text("\(match.patronWins) – \(match.rivalWins)")
                    .font(Theme.number(22, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            Spacer()
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(match.rival.name).font(Theme.title(13)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                    pips(match.rivalWins, tint: match.rival.tint)
                }
                Text(match.rival.monogram)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(match.rival.tint))
            }
        }
        .pearlCard(18, padding: 10)
        .padding(.top, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You \(match.patronWins), \(match.rival.name) \(match.rivalWins)")
    }

    private func pips(_ wins: Int, tint: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<2) { i in
                Circle().fill(i < wins ? tint : Theme.surfaceSunk).frame(width: 7, height: 7)
            }
        }
    }

    private var judgeCard: some View {
        let trait = match.currentTrait
        return HStack(spacing: 12) {
            Image(systemName: trait.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(trait.color))
                .shadow(color: trait.color.opacity(0.5), radius: 8, y: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(trait.judge)
                    .font(Theme.title(16))
                    .foregroundStyle(Theme.ink)
                Text(match.tier.name + " · " + match.tier.venue)
                    .font(Theme.caption(11.5))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 0)
        }
        .pearlCard(18, padding: 12)
        .id(match.rounds.count)
        .transition(.push(from: .trailing))
    }

    private var rivalRow: some View {
        let trait = match.currentTrait
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(match.rival.name)'s cats")
                .font(Theme.caption(12, weight: .semibold))
                .foregroundStyle(Theme.ink3)
            HStack(spacing: 10) {
                ForEach(match.rival.contenders) { cat in
                    let spent = match.rounds.contains { $0.rival.id == cat.id }
                    VStack(spacing: 4) {
                        CatBust(coat: cat.coat, marque: cat.marque, size: 50)
                        Text(cat.name).font(Theme.title(11.5)).foregroundStyle(Theme.ink).lineLimit(1)
                        HStack(spacing: 3) {
                            Image(systemName: trait.symbol).font(.system(size: 9, weight: .bold))
                            Text("\(cat.temperament[trait])").font(Theme.number(12))
                        }
                        .foregroundStyle(trait.color)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(spent ? 0.3 : 1)
                    .saturation(spent ? 0 : 1)
                }
            }
        }
        .pearlCard(18, padding: 12)
    }

    private var hand: some View {
        let trait = match.currentTrait
        return VStack(alignment: .leading, spacing: 8) {
            Text("Send a cat")
                .font(Theme.caption(12, weight: .semibold))
                .foregroundStyle(Theme.ink3)
            HStack(spacing: 10) {
                ForEach(match.hand) { cat in
                    Button { send(cat) } label: {
                        VStack(spacing: 6) {
                            if let lot = cat.lotID.flatMap({ lots[$0] }) {
                                LotCard(lot: lot.presentation, compact: true, showsFoil: false)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: trait.symbol).font(.system(size: 10, weight: .bold))
                                Text("\(cat.base(for: trait))").font(Theme.number(15, weight: .heavy))
                            }
                            .foregroundStyle(trait.color)
                        }
                    }
                    .buttonStyle(PressScale())
                    .accessibilityLabel("Send \(cat.name), \(trait.displayName) \(cat.base(for: trait))")
                }
                ForEach(0..<max(0, 3 - match.hand.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// The two cats meet; scores count up with their breakdown.
struct FaceOff: View {
    let round: RoundResult
    let patronLot: Acquisition?
    let rivalName: String
    let progress: Double

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                side(name: round.patron.name, score: round.patronScore, base: round.patron.temperament[round.trait],
                     flair: round.patron.marque.flair + round.patron.experience, whim: round.patronWhim,
                     won: round.patronWon) {
                    if let patronLot {
                        CutoutArt(image: ImageStore.cutout(for: patronLot), isCameo: patronLot.isCameo, marque: patronLot.marque)
                            .frame(height: 96)
                    }
                }
                Text("vs")
                    .font(Theme.caption(12, weight: .bold))
                    .foregroundStyle(Theme.ink3)
                    .padding(.bottom, 60)
                side(name: round.rival.name, score: round.rivalScore, base: round.rival.temperament[round.trait],
                     flair: round.rival.marque.flair, whim: round.rivalWhim, won: !round.patronWon) {
                    CatBust(coat: round.rival.coat, marque: round.rival.marque, size: 84)
                        .frame(height: 96)
                }
            }
            if progress >= 1 {
                Text(round.patronWon ? "Round to you" : "Round to \(rivalName)")
                    .font(Theme.title(15))
                    .foregroundStyle(round.patronWon ? Theme.win : Theme.loss)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .pearlCard(22, padding: 14)
        .animation(.spring(duration: 0.4), value: progress >= 1)
    }

    private func side<Art: View>(name: String, score: Int, base: Int, flair: Int, whim: Int, won: Bool,
                                 @ViewBuilder art: () -> Art) -> some View {
        let shown = Int((Double(score) * progress).rounded())
        return VStack(spacing: 6) {
            art()
                .scaleEffect(progress >= 1 && won ? 1.06 : 1)
            Text(name)
                .font(Theme.title(12.5))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(shown)")
                .font(Theme.number(30, weight: .heavy))
                .foregroundStyle(progress >= 1 ? (won ? Theme.win : Theme.ink3) : round.trait.color)
                .contentTransition(.numericText(value: Double(shown)))
            HStack(spacing: 4) {
                Pill(text: "\(base)", fill: round.trait.color.opacity(0.15), ink: round.trait.color, symbol: round.trait.symbol)
                if flair > 0 { Pill(text: "+\(flair)", fill: Theme.champagne, ink: Theme.coinDeep, symbol: "sparkle") }
                Pill(text: whim >= 0 ? "+\(whim)" : "\(whim)", fill: Theme.lilac, ink: Color(hex: 0x6D63A8), symbol: "dice")
            }
            .opacity(progress)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(score) points")
    }
}

// MARK: - Result

struct MatchResult: View {
    let match: ConcoursMatch
    let canAgain: Bool
    var onAgain: () -> Void
    var onDone: () -> Void
    @State private var shown = false
    @State private var leaf = 0

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                Rosette(tier: match.tier, size: 130, label: match.patronWon ? "1st" : "2nd")
                    .scaleEffect(shown ? 1 : 0.3)
                    .rotationEffect(.degrees(shown ? 0 : -25))
                Text(match.patronWon ? "Best in show" : "Runner-up")
                    .font(Theme.display(30))
                    .tracking(Theme.displayTracking)
                    .foregroundStyle(Theme.ink)
                Text("\(match.patronWins) – \(match.rivalWins) against \(match.rival.name)")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.ink2)
                HStack(spacing: 10) {
                    if match.patronWon { CoinAmount(value: match.tier.prize, size: 16, signed: true) }
                    Text("+\(match.patronWon ? match.tier.xp : match.tier.consolationXP) XP")
                        .font(Theme.number(16, weight: .heavy))
                        .foregroundStyle(Theme.roseDeep)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.surface))
                roundsSummary
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button("Done", action: onDone)
                        .buttonStyle(SecondaryButtonStyle())
                    Button(match.tier.entryFee > 0 ? "Again · \(match.tier.entryFee) gns" : "Again", action: onAgain)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canAgain)
                        .opacity(canAgain ? 1 : 0.5)
                }
            }
            GoldLeafBurst(trigger: leaf, count: 80, tint: match.patronWon ? .gold : .ivory)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.4)) { shown = true }
            if match.patronWon { leaf += 1 }
        }
    }

    private var roundsSummary: some View {
        VStack(spacing: 6) {
            ForEach(Array(match.rounds.enumerated()), id: \.offset) { _, round in
                HStack(spacing: 8) {
                    Image(systemName: round.trait.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(round.trait.color)
                        .frame(width: 18)
                    Text(round.patron.name).font(Theme.body(13, weight: .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer()
                    Text("\(round.patronScore) – \(round.rivalScore)")
                        .font(Theme.number(13))
                        .foregroundStyle(round.patronWon ? Theme.win : Theme.loss)
                }
            }
        }
        .pearlCard(16, padding: 12)
    }
}
