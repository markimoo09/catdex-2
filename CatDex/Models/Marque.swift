import SwiftUI

/// The house's rarity tiers, named like hallmarks.
enum Marque: String, Codable, CaseIterable, Identifiable, Comparable {
    case ivory, silver, gold, platinum, noir

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ivory: "Ivory"
        case .silver: "Silver"
        case .gold: "Gold"
        case .platinum: "Platinum"
        case .noir: "Noir"
        }
    }

    /// Hallmark stamp letter.
    var stamp: String {
        switch self {
        case .ivory: "I"
        case .silver: "S"
        case .gold: "G"
        case .platinum: "P"
        case .noir: "N"
        }
    }

    /// Roll weight in percent; sums to 100.
    var weight: Int {
        switch self {
        case .ivory: 50
        case .silver: 26
        case .gold: 14
        case .platinum: 7
        case .noir: 3
        }
    }

    /// Valuation band in guineas.
    var valuationRange: ClosedRange<Int> {
        switch self {
        case .ivory: 800...2_400
        case .silver: 2_400...6_000
        case .gold: 6_000...18_000
        case .platinum: 18_000...60_000
        case .noir: 60_000...250_000
        }
    }

    /// Prestige points toward Patronage.
    var prestige: Int {
        switch self {
        case .ivory: 1
        case .silver: 2
        case .gold: 4
        case .platinum: 8
        case .noir: 16
        }
    }

    /// Minimum temperament score — rarer cats carry themselves better.
    var temperamentFloor: Int {
        switch self {
        case .ivory: 18
        case .silver: 30
        case .gold: 42
        case .platinum: 54
        case .noir: 66
        }
    }

    var order: Int {
        switch self {
        case .ivory: 0
        case .silver: 1
        case .gold: 2
        case .platinum: 3
        case .noir: 4
        }
    }

    static func < (lhs: Marque, rhs: Marque) -> Bool { lhs.order < rhs.order }

    /// Foil strength over art; 0 means matte.
    var foilStrength: Double {
        switch self {
        case .ivory: 0
        case .silver: 0.35
        case .gold: 0.6
        case .platinum: 0.85
        case .noir: 1.0
        }
    }

    var celebratesWithGoldLeaf: Bool { self >= .gold }

    /// 0 = pure metal sheen, 1 = full rainbow.
    var foilIridescence: Double {
        switch self {
        case .platinum: 0.55
        case .silver: 0.1
        default: 0.12
        }
    }

    /// 0 = cool silver light, 1 = warm gilt light.
    var foilWarmth: Double {
        switch self {
        case .silver, .platinum: 0.1
        default: 1
        }
    }

    // MARK: Game values

    /// Patron XP for acquiring a lot of this marque.
    var xp: Int {
        switch self {
        case .ivory: 40
        case .silver: 60
        case .gold: 100
        case .platinum: 160
        case .noir: 260
        }
    }

    /// Guineas paid to the patron when the lot is entered.
    var finderFee: Int {
        switch self {
        case .ivory: 60
        case .silver: 120
        case .gold: 250
        case .platinum: 500
        case .noir: 1_000
        }
    }

    /// Bonus points a cat of this marque brings to every concours round.
    var flair: Int {
        switch self {
        case .ivory: 0
        case .silver: 2
        case .gold: 4
        case .platinum: 6
        case .noir: 9
        }
    }

    // MARK: Colour (Pearl theme)

    /// Soft fill for pills and chips.
    var tone: Color {
        switch self {
        case .ivory: Color(hex: 0xF1E8D8)
        case .silver: Color(hex: 0xE5E9EF)
        case .gold: Color(hex: 0xF8EACB)
        case .platinum: Color(hex: 0xECE8F7)
        case .noir: Color(hex: 0x2A2430)
        }
    }

    /// Ink used on top of `tone`, and for the marque's name.
    var toneInk: Color {
        switch self {
        case .ivory: Color(hex: 0x8A7150)
        case .silver: Color(hex: 0x56626F)
        case .gold: Color(hex: 0x946818)
        case .platinum: Color(hex: 0x5D5891)
        case .noir: Theme.roseLight
        }
    }

    /// A metal gradient for hallmarks, frames and seals.
    var metal: LinearGradient {
        let stops: [Color]
        switch self {
        case .ivory:
            stops = [Color(hex: 0xFBF6EC), Color(hex: 0xE6D9BF), Color(hex: 0xC9B48E), Color(hex: 0xF1E7D4)]
        case .silver:
            stops = [Color(hex: 0xF7F8FA), Color(hex: 0xC4CBD4), Color(hex: 0x8D97A3), Color(hex: 0xE1E5EB)]
        case .gold:
            stops = [Color(hex: 0xF8E5B4), Color(hex: 0xE2B65C), Color(hex: 0xB7882C), Color(hex: 0xF0D38C)]
        case .platinum:
            stops = [Color(hex: 0xFFFFFF), Color(hex: 0xDCD9F0), Color(hex: 0xB6BEE0), Color(hex: 0xF0DDEB), Color(hex: 0xD3EAE6)]
        case .noir:
            stops = [Color(hex: 0x4D4252), Color(hex: 0x231D27), Color(hex: 0x3A3040), Color(hex: 0x1C171F)]
        }
        return LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Wax colour for the envelope seal.
    var wax: (light: Color, base: Color, deep: Color) {
        switch self {
        case .ivory: (Color(hex: 0xF6EDDC), Color(hex: 0xDCC9A6), Color(hex: 0xA8916A))
        case .silver: (Color(hex: 0xEEF1F5), Color(hex: 0xAEB7C3), Color(hex: 0x6E7886))
        case .gold: (Color(hex: 0xF8E0A0), Color(hex: 0xD3A143), Color(hex: 0x8A621F))
        case .platinum: (Color(hex: 0xF6F2FC), Color(hex: 0xC8C6E2), Color(hex: 0x8A87AE))
        case .noir: (Color(hex: 0x5A4C5E), Color(hex: 0x2A2430), Color(hex: 0x120E14))
        }
    }

    /// Accent for highlights, glows and bursts.
    var accent: Color {
        switch self {
        case .ivory: Color(hex: 0xC9B48E)
        case .silver: Color(hex: 0x9AA6B4)
        case .gold: Color(hex: 0xE2B65C)
        case .platinum: Color(hex: 0xA9A4DA)
        case .noir: Theme.rose
        }
    }
}
