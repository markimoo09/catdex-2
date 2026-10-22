import Foundation
import SwiftData

/// A cat entered into the collection.
@Model
final class Acquisition {
    @Attribute(.unique) var id: UUID
    var lotNumber: Int
    var acquiredAt: Date
    var marqueRaw: String

    // Dossier — written by the curator.
    var name: String
    var epithet: String
    var motto: String
    var mottoTranslation: String
    var signatureTrait: String
    var curatorNote: String
    var provenance: String

    // Provenance facts.
    var setting: String
    var hourLabel: String

    // Temperament, 0...100.
    var poise: Int
    var charm: Int
    var mischief: Int
    var languor: Int
    var curiosity: Int

    var valuation: Int
    var paletteData: Data
    /// True when the subject could not be lifted and the photo is framed as a cameo.
    var isCameo: Bool
    /// Vision's cat confidence, or nil when it could not be checked.
    var catConfidence: Double?
    /// Written on-device by Apple Intelligence (vs. the house writer).
    var aiAuthored: Bool

    @Attribute(.externalStorage) var cutoutData: Data
    @Attribute(.externalStorage) var originalData: Data
    var correspondenceData: Data?

    // Game record — defaulted so existing collections migrate.
    var showWins: Int = 0
    var showRounds: Int = 0
    var groomings: Int = 0

    init(
        id: UUID = UUID(),
        lotNumber: Int,
        acquiredAt: Date = .now,
        marque: Marque,
        dossier: Dossier,
        setting: String,
        hourLabel: String,
        temperament: Temperament,
        valuation: Int,
        palette: [Swatch],
        isCameo: Bool,
        catConfidence: Double?,
        aiAuthored: Bool,
        cutoutData: Data,
        originalData: Data
    ) {
        self.id = id
        self.lotNumber = lotNumber
        self.acquiredAt = acquiredAt
        self.marqueRaw = marque.rawValue
        self.name = dossier.name
        self.epithet = dossier.epithet
        self.motto = dossier.motto
        self.mottoTranslation = dossier.mottoTranslation
        self.signatureTrait = dossier.signatureTrait
        self.curatorNote = dossier.curatorNote
        self.provenance = dossier.provenance
        self.setting = setting
        self.hourLabel = hourLabel
        self.poise = temperament.poise
        self.charm = temperament.charm
        self.mischief = temperament.mischief
        self.languor = temperament.languor
        self.curiosity = temperament.curiosity
        self.valuation = valuation
        self.paletteData = Swatch.encode(palette)
        self.isCameo = isCameo
        self.catConfidence = catConfidence
        self.aiAuthored = aiAuthored
        self.cutoutData = cutoutData
        self.originalData = originalData
    }

    var marque: Marque {
        get { Marque(rawValue: marqueRaw) ?? .ivory }
        set { marqueRaw = newValue.rawValue }
    }

    var palette: [Swatch] {
        let decoded = Swatch.decode(paletteData)
        return decoded.isEmpty ? Swatch.houseDefault : decoded
    }

    var temperament: Temperament {
        Temperament(poise: poise, charm: charm, mischief: mischief, languor: languor, curiosity: curiosity)
    }

    var correspondence: [Letter] {
        get { correspondenceData.flatMap { try? JSONDecoder().decode([Letter].self, from: $0) } ?? [] }
        set { correspondenceData = try? JSONEncoder().encode(newValue) }
    }

    var fullTitle: String { "\(name), \(epithet)" }

    /// Show experience: +1 to every round for each three rounds won, up to +5.
    var showExperience: Int { min(5, showWins / 3) }

    /// Grooming raises one trait; rarer marques can be groomed higher.
    func groom(_ trait: Temperament.Trait, by amount: Int) {
        let cap = 100
        switch trait {
        case .poise: poise = min(cap, poise + amount)
        case .charm: charm = min(cap, charm + amount)
        case .mischief: mischief = min(cap, mischief + amount)
        case .languor: languor = min(cap, languor + amount)
        case .curiosity: curiosity = min(cap, curiosity + amount)
        }
        groomings += 1
    }
}

/// Five temperament readings, 0...100.
struct Temperament: Codable, Equatable {
    var poise: Int
    var charm: Int
    var mischief: Int
    var languor: Int
    var curiosity: Int

    enum Trait: String, CaseIterable {
        case poise, charm, mischief, languor, curiosity

        var displayName: String { rawValue.capitalized }
    }

    subscript(trait: Trait) -> Int {
        switch trait {
        case .poise: poise
        case .charm: charm
        case .mischief: mischief
        case .languor: languor
        case .curiosity: curiosity
        }
    }

    var average: Double { Double(poise + charm + mischief + languor + curiosity) / 5 }

    /// Traits ordered strongest first.
    var ranked: [Trait] {
        Trait.allCases.sorted { self[$0] > self[$1] }
    }

    var dominant: Trait { ranked[0] }
}

/// The curator's written entry.
struct Dossier: Codable, Equatable {
    var name: String
    var epithet: String
    var motto: String
    var mottoTranslation: String
    var signatureTrait: String
    var curatorNote: String
    var provenance: String
}

/// One message in an audience with a cat.
struct Letter: Codable, Identifiable, Equatable {
    enum Author: String, Codable { case patron, cat }
    var id = UUID()
    var author: Author
    var text: String
    var date: Date = .now
}
