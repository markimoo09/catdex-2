import SwiftData
import SwiftUI

/// A reward to toast on screen.
struct Reward: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let guineas: Int
    let xp: Int
}

/// A level reached, for the celebration card.
struct LevelUp: Identifiable, Equatable {
    var id: Int { level }
    let level: Int
    let title: String
    let unlocks: [String]
}

/// The game layer: purse, XP, commissions, streak. Wraps the persistent `Ledger`.
@MainActor
@Observable
final class Game {
    let ledger: Ledger
    private let context: ModelContext

    var toasts: [Reward] = []
    var levelUp: LevelUp?

    init(context: ModelContext) {
        self.context = context
        if let existing = try? context.fetch(FetchDescriptor<Ledger>()).first {
            ledger = existing
        } else {
            let fresh = Ledger()
            // Collections that predate the game layer start with their XP banked.
            let lots = (try? context.fetch(FetchDescriptor<Acquisition>())) ?? []
            fresh.xp = lots.reduce(0) { $0 + $1.marque.xp }
            context.insert(fresh)
            try? context.save()
            ledger = fresh
        }
    }

    /// Banks XP and finder's fees for lots that arrived without the game
    /// layer seeing them (demo seeding), and applies DEBUG overrides.
    func adoptCollection(_ lots: [Acquisition]) {
        if ledger.xp == 0, !lots.isEmpty {
            ledger.xp = lots.reduce(0) { $0 + $1.marque.xp }
            ledger.guineas += lots.reduce(0) { $0 + $1.marque.finderFee }
        }
        if let xp = DebugHooks.patronXP { ledger.xp = xp }
        save()
    }

    // MARK: Derived

    var level: Int { Progression.level(forXP: ledger.xp) }
    var title: String { Progression.title(for: level) }
    var levelProgress: Double { Progression.progress(xp: ledger.xp) }
    var xpIntoLevel: Int { ledger.xp - Progression.xpToReach(level) }
    var xpForLevel: Int { Progression.xpToReach(level + 1) - Progression.xpToReach(level) }

    var today: DayTally { ledger.daily[DayKey.key(for: .now)] ?? DayTally() }

    var streak: Int {
        Streak.length(activeDays: Set(ledger.daily.filter { $0.value.isActive }.map(\.key)))
    }

    var commissions: [CommissionStatus] {
        let key = DayKey.key(for: .now)
        let claimed = ledger.claimed
        return Commission.board(for: .now).map {
            CommissionStatus(commission: $0, progress: min($0.goal, today[$0.metric]), claimed: claimed.contains("\(key):\($0.id)"))
        }
    }

    var claimableCount: Int { commissions.filter(\.isClaimable).count }

    func isUnlocked(_ tier: ShowTier) -> Bool { level >= tier.unlockLevel }

    // MARK: Actions

    func award(_ title: String, xp: Int, guineas: Int) {
        let before = level
        ledger.xp += xp
        ledger.guineas += guineas
        save()
        withAnimation(.spring(duration: 0.5)) {
            toasts.append(Reward(title: title, guineas: guineas, xp: xp))
        }
        if level > before {
            levelUp = LevelUp(level: level, title: Progression.title(for: level), unlocks: Progression.unlocks(at: level))
        }
    }

    /// Spends guineas if the purse allows.
    @discardableResult
    func spend(_ guineas: Int) -> Bool {
        guard ledger.guineas >= guineas else { return false }
        ledger.guineas -= guineas
        save()
        return true
    }

    func recordAcquisition(_ lot: Acquisition) {
        tally { $0.acquired += 1; if lot.marque >= .silver { $0.silverPlus += 1 } }
        award("\(lot.marque.displayName) lot entered", xp: lot.marque.xp, guineas: lot.marque.finderFee)
    }

    func recordShow(_ tier: ShowTier, won: Bool) {
        ledger.showsEntered += 1
        if won {
            ledger.showsWon += 1
            var rosettes = ledger.rosettes
            rosettes[tier.id, default: 0] += 1
            ledger.rosettes = rosettes
        }
        tally { $0.showsEntered += 1; if won { $0.showsWon += 1 } }
        if won {
            award("Best in show", xp: tier.xp, guineas: tier.prize)
        } else {
            award("Runner-up", xp: tier.consolationXP, guineas: 0)
        }
    }

    func recordAudience() {
        ledger.audiences += 1
        tally { $0.audiences += 1 }
        save()
    }

    func groom(_ lot: Acquisition, _ trait: Temperament.Trait) -> Bool {
        guard lot.temperament[trait] < 100, spend(Grooming.cost(currentValue: lot.temperament[trait])) else { return false }
        lot.groom(trait, by: Grooming.gain)
        ledger.groomings += 1
        tally { $0.groomings += 1 }
        save()
        return true
    }

    func claim(_ status: CommissionStatus) {
        guard status.isClaimable else { return }
        var claimed = ledger.claimed
        claimed.insert("\(DayKey.key(for: .now)):\(status.commission.id)")
        ledger.claimed = claimed
        award(status.commission.title, xp: status.commission.xp, guineas: status.commission.guineas)
    }

    func dismissToast(_ reward: Reward) {
        withAnimation(.smooth) { toasts.removeAll { $0.id == reward.id } }
    }

    // MARK: Helpers

    private func tally(_ change: (inout DayTally) -> Void) {
        let key = DayKey.key(for: .now)
        var daily = ledger.daily
        var day = daily[key] ?? DayTally()
        change(&day)
        daily[key] = day
        // Keep a fortnight — enough for streaks.
        if daily.count > 21 {
            for stale in daily.keys.sorted().prefix(daily.count - 21) { daily.removeValue(forKey: stale) }
        }
        ledger.daily = daily
    }

    private func save() { try? context.save() }
}
