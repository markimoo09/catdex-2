import SwiftUI

/// A cat show tier: harder rivals, higher stakes.
struct ShowTier: Identifiable, Equatable {
    let id: String
    let name: String
    let venue: String
    let unlockLevel: Int
    let entryFee: Int
    let prize: Int
    let xp: Int
    let consolationXP: Int
    let rivalRange: ClosedRange<Int>
    let rivalMarques: [Marque]
    let ribbon: Color
    let ribbonDeep: Color

    static let fete = ShowTier(
        id: "fete", name: "Village Fête", venue: "The Orangery", unlockLevel: 1, entryFee: 0, prize: 150, xp: 50,
        consolationXP: 15, rivalRange: 28...62, rivalMarques: [.ivory, .ivory, .silver],
        ribbon: Color(hex: 0xE7A797), ribbonDeep: Color(hex: 0xC27866)
    )
    static let automne = ShowTier(
        id: "automne", name: "Salon d'Automne", venue: "The Long Gallery", unlockLevel: 3, entryFee: 100, prize: 420, xp: 90,
        consolationXP: 25, rivalRange: 42...76, rivalMarques: [.ivory, .silver, .gold],
        ribbon: Color(hex: 0xA9A4DA), ribbonDeep: Color(hex: 0x6F69AE)
    )
    static let grand = ShowTier(
        id: "grand", name: "Grand Concours", venue: "The Winter Palace", unlockLevel: 6, entryFee: 300, prize: 1_100, xp: 160,
        consolationXP: 40, rivalRange: 55...88, rivalMarques: [.silver, .gold, .platinum],
        ribbon: Color(hex: 0xE2B65C), ribbonDeep: Color(hex: 0xA97D25)
    )
    static let royal = ShowTier(
        id: "royal", name: "Concours Royal", venue: "The Hall of Mirrors", unlockLevel: 10, entryFee: 800, prize: 2_800, xp: 300,
        consolationXP: 70, rivalRange: 68...97, rivalMarques: [.gold, .platinum, .noir],
        ribbon: Color(hex: 0x3A3040), ribbonDeep: Color(hex: 0x1C171F)
    )

    static let all = [fete, automne, grand, royal]
}

/// A cat entered in a concours — the patron's own or a rival's.
struct Contender: Identifiable, Equatable {
    let id: UUID
    let name: String
    let marque: Marque
    let temperament: Temperament
    let coat: [Color]
    let experience: Int
    /// The patron's lot this contender represents (nil for rivals).
    let lotID: UUID?

    init(id: UUID = UUID(), name: String, marque: Marque, temperament: Temperament, coat: [Color],
         experience: Int = 0, lotID: UUID? = nil) {
        self.id = id
        self.name = name
        self.marque = marque
        self.temperament = temperament
        self.coat = coat
        self.experience = experience
        self.lotID = lotID
    }

    init(_ lot: Acquisition) {
        self.init(name: lot.name, marque: lot.marque, temperament: lot.temperament,
                  coat: lot.palette.map(\.color), experience: lot.showExperience, lotID: lot.id)
    }

    /// Points before the judge's whim.
    func base(for trait: Temperament.Trait) -> Int {
        temperament[trait] + marque.flair + experience
    }
}

/// A rival collector and their three cats.
struct Rival: Equatable {
    let name: String
    let monogram: String
    let tint: Color
    let contenders: [Contender]
}

/// One judged round.
struct RoundResult: Equatable {
    let trait: Temperament.Trait
    let patron: Contender
    let rival: Contender
    let patronWhim: Int
    let rivalWhim: Int

    var patronScore: Int { patron.base(for: trait) + patronWhim }
    var rivalScore: Int { rival.base(for: trait) + rivalWhim }
    /// Ties go to the patron's cat — the house is a gracious host.
    var patronWon: Bool { patronScore >= rivalScore }
}

/// The rules of the concours. Pure and seeded so matches are testable.
enum Concours {
    static let whimRange = -6...6

    static let collectors: [(name: String, tint: UInt32)] = [
        ("Countess Vrell", 0x9C7BB8), ("Sir Ambrose Pike", 0x6F8FAF), ("Madame Fairfax", 0xC9867A),
        ("Baron von Kessel", 0x7E8A6A), ("Lady Persimmon Hale", 0xD39A5A), ("Mr. Cornelius Bly", 0x8A7A9E),
        ("The Duchess of Orme", 0xB06F86), ("Monsieur Delacroix", 0x5E8E8A),
    ]

    static let coats: [[UInt32]] = [
        [0xD2752E, 0xEFE6D2], [0x141414, 0xF2EBDD], [0x8F8B85, 0x5B6168], [0xC4A484, 0x6A4E3D],
        [0xE3A066, 0xF2EBDD], [0x444446, 0xA8A39A], [0xDCC7A1, 0x9A4F25], [0x2B1E17, 0xB8875A],
        [0xF2EBDD, 0xD9A6A6], [0x6E6D6A, 0xE9E4DA],
    ]

    static func rival(for tier: ShowTier, seed: UInt64) -> Rival {
        var rng = SeededRandom(seed: seed)
        let collector = rng.pick(collectors)
        let initials = collector.name.split(separator: " ").filter { $0.first?.isUppercase == true }
        let monogram = String(initials.suffix(2).compactMap(\.first))
        var names = HouseCurator.names.shuffled(using: &rng)
        let contenders = tier.rivalMarques.map { marque -> Contender in
            func reading() -> Int {
                let span = tier.rivalRange.upperBound - tier.rivalRange.lowerBound
                return tier.rivalRange.lowerBound + Int((rng.unit() + rng.unit()) / 2 * Double(span))
            }
            let coat = rng.pick(coats).map { Color(hex: $0) }
            return Contender(
                name: names.removeFirst(), marque: marque,
                temperament: Temperament(poise: reading(), charm: reading(), mischief: reading(),
                                         languor: reading(), curiosity: reading()),
                coat: coat
            )
        }
        return Rival(name: collector.name, monogram: monogram, tint: Color(hex: collector.tint), contenders: contenders)
    }

    /// Three distinct judging categories for the match.
    static func categories(seed: UInt64) -> [Temperament.Trait] {
        var rng = SeededRandom(seed: seed ^ 0xC0DE)
        return Array(Temperament.Trait.allCases.shuffled(using: &rng).prefix(3))
    }

    /// Rivals usually field their best cat for the category — but not always.
    static func rivalPick<G: RandomNumberGenerator>(from remaining: [Contender], for trait: Temperament.Trait,
                                                    using rng: inout G) -> Contender {
        let best = remaining.max { $0.base(for: trait) < $1.base(for: trait) }!
        guard remaining.count > 1, Double.random(in: 0..<1, using: &rng) < 0.3 else { return best }
        return remaining.filter { $0.id != best.id }.randomElement(using: &rng)!
    }

    static func whim<G: RandomNumberGenerator>(using rng: inout G) -> Int {
        Int.random(in: whimRange, using: &rng)
    }

    /// The patron's three strongest cats by overall bearing.
    static func suggestedTeam(from lots: [Acquisition]) -> [Acquisition] {
        Array(lots.sorted { score($0) > score($1) }.prefix(3))
    }

    private static func score(_ lot: Acquisition) -> Double {
        lot.temperament.average + Double(lot.marque.flair + lot.showExperience)
    }
}

extension Temperament.Trait {
    var symbol: String {
        switch self {
        case .poise: "crown"
        case .charm: "heart"
        case .mischief: "bolt"
        case .languor: "moon.zzz"
        case .curiosity: "magnifyingglass"
        }
    }

    var color: Color {
        switch self {
        case .poise: Color(hex: 0xA58BD0)
        case .charm: Color(hex: 0xE38E9C)
        case .mischief: Color(hex: 0xE3A04F)
        case .languor: Color(hex: 0x7FA3C9)
        case .curiosity: Color(hex: 0x6FAE8C)
        }
    }

    var judge: String {
        switch self {
        case .poise: "The judge favours poise"
        case .charm: "The judge favours charm"
        case .mischief: "The judge favours mischief"
        case .languor: "The judge favours languor"
        case .curiosity: "The judge favours curiosity"
        }
    }
}
