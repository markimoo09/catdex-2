import SwiftUI

/// One concours in progress: best of three judged rounds against a rival.
@MainActor
@Observable
final class ConcoursMatch {
    enum Phase: Equatable { case choosing, reveal, finished }

    let tier: ShowTier
    let rival: Rival
    let categories: [Temperament.Trait]
    private(set) var hand: [Contender]
    private(set) var rivalHand: [Contender]
    private(set) var rounds: [RoundResult] = []
    private(set) var phase: Phase = .choosing
    private var rng = SystemRandomNumberGenerator()

    init(tier: ShowTier, team: [Contender], seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.tier = tier
        self.rival = Concours.rival(for: tier, seed: seed)
        self.categories = Concours.categories(seed: seed)
        self.hand = team
        self.rivalHand = rival.contenders
    }

    var roundIndex: Int { min(rounds.count, categories.count - 1) }
    var currentTrait: Temperament.Trait { categories[phase == .reveal ? rounds.count - 1 : roundIndex] }
    var patronWins: Int { rounds.filter(\.patronWon).count }
    var rivalWins: Int { rounds.count - patronWins }
    var lastRound: RoundResult? { rounds.last }
    var isDecided: Bool { patronWins >= 2 || rivalWins >= 2 || rounds.count == categories.count }
    var patronWon: Bool { patronWins > rivalWins }

    /// The patron sends a cat; the rival's pick is made blind to it.
    func play(_ contender: Contender) {
        guard phase == .choosing, hand.contains(contender) else { return }
        let trait = categories[rounds.count]
        let rivalPick = Concours.rivalPick(from: rivalHand, for: trait, using: &rng)
        let result = RoundResult(
            trait: trait, patron: contender, rival: rivalPick,
            patronWhim: Concours.whim(using: &rng), rivalWhim: Concours.whim(using: &rng)
        )
        hand.removeAll { $0.id == contender.id }
        rivalHand.removeAll { $0.id == rivalPick.id }
        rounds.append(result)
        phase = .reveal
    }

    func advance() {
        guard phase == .reveal else { return }
        phase = isDecided ? .finished : .choosing
    }
}
