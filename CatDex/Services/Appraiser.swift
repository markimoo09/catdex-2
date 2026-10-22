import Foundation

/// The appraisal: marque, temperament and estimate.
struct Appraisal: Equatable {
    var marque: Marque
    var temperament: Temperament
    var valuation: Int
}

enum Appraiser {

    /// Lots below Gold in a row before the house guarantees Gold or better.
    static let pityThreshold = 9

    /// Rolls a marque. `recent` is newest-first; nine sub-Gold lots in a row
    /// guarantee the next is Gold or better.
    static func rollMarque<G: RandomNumberGenerator>(recent: [Marque], using rng: inout G) -> Marque {
        let drySpell = recent.prefix(pityThreshold).allSatisfy { $0 < .gold } && recent.count >= pityThreshold
        let pool: [Marque] = drySpell ? Marque.allCases.filter { $0 >= .gold } : Marque.allCases
        let total = pool.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<total, using: &rng)
        for marque in pool {
            if roll < marque.weight { return marque }
            roll -= marque.weight
        }
        return pool.last!
    }

    /// Seeded temperament: same photo, same character. The marque sets a floor.
    static func temperament(seed: UInt64, marque: Marque) -> Temperament {
        var rng = SeededRandom(seed: seed ^ 0xA5A5_5A5A_C3C3_3C3C)
        let floor = marque.temperamentFloor
        func reading() -> Int {
            // Two draws averaged — readings cluster toward the middle of the band.
            let a = rng.unit(), b = rng.unit()
            return floor + Int(((a + b) / 2) * Double(100 - floor))
        }
        return Temperament(poise: reading(), charm: reading(), mischief: reading(), languor: reading(), curiosity: reading())
    }

    /// Places the estimate inside the marque's band by temperament, rounded to 50.
    static func valuation(marque: Marque, temperament: Temperament, seed: UInt64) -> Int {
        var rng = SeededRandom(seed: seed ^ 0x0F0F_F0F0_1234_4321)
        let range = marque.valuationRange
        let quality = (temperament.average - Double(marque.temperamentFloor)) / Double(100 - marque.temperamentFloor)
        let position = min(1, max(0, quality * 0.8 + rng.unit() * 0.2))
        let raw = Double(range.lowerBound) + position * Double(range.upperBound - range.lowerBound)
        return Int((raw / 50).rounded()) * 50
    }

    static func appraise<G: RandomNumberGenerator>(
        seed: UInt64, recent: [Marque], forced: Marque? = nil, using rng: inout G
    ) -> Appraisal {
        let marque = forced ?? rollMarque(recent: recent, using: &rng)
        let temperament = temperament(seed: seed, marque: marque)
        return Appraisal(marque: marque, temperament: temperament,
                         valuation: valuation(marque: marque, temperament: temperament, seed: seed))
    }
}
