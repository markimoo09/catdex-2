import Foundation

/// Patron levels: XP needed to reach level L is 60·(L−1)·L.
enum Progression {
    static func xpToReach(_ level: Int) -> Int { 60 * (level - 1) * level }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpToReach(level + 1) <= xp { level += 1 }
        return level
    }

    /// Progress through the current level, 0...1.
    static func progress(xp: Int) -> Double {
        let level = level(forXP: xp)
        let floor = xpToReach(level), ceiling = xpToReach(level + 1)
        return Double(xp - floor) / Double(ceiling - floor)
    }

    static let titles: [(level: Int, title: String)] = [
        (1, "Visitor"), (2, "Admirer"), (4, "Friend of the Maison"), (6, "Patron"),
        (9, "Benefactor"), (13, "Grand Patron"), (18, "Founder's Circle"),
    ]

    static func title(for level: Int) -> String {
        titles.last { level >= $0.level }?.title ?? "Visitor"
    }

    /// Show tiers a level opens, for the level-up card.
    static func unlocks(at level: Int) -> [String] {
        ShowTier.all.filter { $0.unlockLevel == level && level > 1 }.map { "\($0.name) unlocked" }
    }
}

/// A daily commission — a small goal paying guineas and XP.
struct Commission: Identifiable, Equatable {
    enum Group { case acquire, show, care }

    let id: String
    let title: String
    let symbol: String
    let metric: DayTally.Metric
    let goal: Int
    let guineas: Int
    let xp: Int
    let group: Group

    static let pool: [Commission] = [
        Commission(id: "acquire1", title: "Acquire a cat", symbol: "camera.aperture", metric: .acquired, goal: 1, guineas: 150, xp: 40, group: .acquire),
        Commission(id: "acquire2", title: "Acquire two cats", symbol: "camera.aperture", metric: .acquired, goal: 2, guineas: 320, xp: 90, group: .acquire),
        Commission(id: "silver", title: "Find a Silver or finer", symbol: "rhombus", metric: .silverPlus, goal: 1, guineas: 280, xp: 70, group: .acquire),
        Commission(id: "enter2", title: "Enter two concours", symbol: "trophy", metric: .showsEntered, goal: 2, guineas: 200, xp: 60, group: .show),
        Commission(id: "win1", title: "Win a concours", symbol: "rosette", metric: .showsWon, goal: 1, guineas: 350, xp: 100, group: .show),
        Commission(id: "audience", title: "Hold an audience", symbol: "bubble.left.and.text.bubble.right", metric: .audiences, goal: 1, guineas: 120, xp: 30, group: .care),
        Commission(id: "groom", title: "Groom a cat", symbol: "scissors", metric: .groomings, goal: 1, guineas: 140, xp: 40, group: .care),
    ]

    /// Three a day — one each of acquiring, showing and caring — rotating at midnight.
    static func board(for date: Date, calendar: Calendar = .current) -> [Commission] {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        var rng = SeededRandom(seed: UInt64(day) &* 0x9E37_79B9 &+ 17)
        return [Group.acquire, .show, .care].map { group in
            rng.pick(pool.filter { $0.group == group })
        }
    }
}

/// A commission's state today.
struct CommissionStatus: Identifiable, Equatable {
    let commission: Commission
    let progress: Int
    let claimed: Bool

    var id: String { commission.id }
    var isComplete: Bool { progress >= commission.goal }
    var isClaimable: Bool { isComplete && !claimed }
}

enum Streak {
    /// Consecutive active days ending today (or yesterday, so it survives until midnight).
    static func length(activeDays: Set<String>, today: Date = .now, calendar: Calendar = .current) -> Int {
        var day = today
        if !activeDays.contains(DayKey.key(for: day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  activeDays.contains(DayKey.key(for: yesterday, calendar: calendar)) else { return 0 }
            day = yesterday
        }
        var count = 0
        while activeDays.contains(DayKey.key(for: day, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}

enum Grooming {
    static let gain = 3

    /// Grooming gets dearer as a trait approaches perfection.
    static func cost(currentValue: Int) -> Int {
        40 + max(0, currentValue - 30) * 4
    }
}
