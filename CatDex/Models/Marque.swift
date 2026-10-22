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

    // MARK: Colour

    /// Signature metal tone.
    var tone: Color {
        switch self {
        case .ivory: Color(hex: 0xE9E1D1)
        case .silver: Color(hex: 0xC5CBD3)
        case .gold: Color(hex: 0xD6AE62)
        case .platinum: Color(hex: 0xDCDFE6)
        case .noir: Color(hex: 0x1A1A1C)
        }
    }

    /// Ink used on top of `tone`.
    var toneInk: Color {
        self == .noir ? Theme.goldLight : Color(hex: 0x1A1612)
    }

    /// A metal gradient for hallmarks, rules and seals.
    var metal: LinearGradient {
        let stops: [Color]
        switch self {
        case .ivory:
            stops = [Color(hex: 0xF7F1E6), Color(hex: 0xE2D7C2), Color(hex: 0xC9BBA0), Color(hex: 0xEDE4D3)]
        case .silver:
            stops = [Color(hex: 0xF4F6F8), Color(hex: 0xB9C0C9), Color(hex: 0x7F8894), Color(hex: 0xDDE2E8)]
        case .gold:
            stops = [Theme.goldLight, Theme.gold, Theme.goldDeep, Color(hex: 0xE8CF94)]
        case .platinum:
            stops = [Color(hex: 0xFFFFFF), Color(hex: 0xD7DCE6), Color(hex: 0xB9C3D8), Color(hex: 0xE9DDF0), Color(hex: 0xD6E8E4)]
        case .noir:
            stops = [Color(hex: 0x3A3631), Color(hex: 0x0B0B0C), Color(hex: 0x24211D), Color(hex: 0x0B0B0C)]
        }
        return LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Wax colour for the envelope seal.
    var wax: (light: Color, base: Color, deep: Color) {
        switch self {
        case .ivory: (Color(hex: 0xF1E6D2), Color(hex: 0xD8C7A8), Color(hex: 0xA8956F))
        case .silver: (Color(hex: 0xE6EAF0), Color(hex: 0xA9B2BE), Color(hex: 0x6C7682))
        case .gold: (Color(hex: 0xF5DC9C), Color(hex: 0xC9973E), Color(hex: 0x7E5A1E))
        case .platinum: (Color(hex: 0xF3F0FA), Color(hex: 0xC4C8DA), Color(hex: 0x8A8FA8))
        case .noir: (Color(hex: 0x4A4540), Color(hex: 0x161514), Color(hex: 0x050505))
        }
    }

    /// Accent used for the marque's name in chrome.
    var accent: Color {
        switch self {
        case .ivory: Color(hex: 0xE9E1D1)
        case .silver: Color(hex: 0xCDD4DD)
        case .gold: Theme.gold
        case .platinum: Color(hex: 0xE4E6F0)
        case .noir: Theme.goldLight
        }
    }
}
