import Foundation

/// Everything the curator knows when writing an entry.
struct CuratorBrief: Equatable {
    var marque: Marque
    var temperament: Temperament
    var palette: [Swatch]
    var setting: String
    var hour: String
    var seed: UInt64
    var verdict: CatVerdict
}

/// The house writer: a seeded, deterministic curator for devices without
/// Apple Intelligence. Same photo, same entry.
enum HouseCurator {

    static func write(_ brief: CuratorBrief) -> Dossier {
        var rng = SeededRandom(seed: brief.seed ^ 0x5EED_CA75)
        let dominant = brief.temperament.dominant
        let second = brief.temperament.ranked[1]

        let name = rng.pick(names)
        let title = title(for: brief.marque, rng: &rng)
        let fullName = title.map { "\($0) \(name)" } ?? name
        let epithet = rng.pick(epithets[dominant] ?? epithets[.poise]!)
        let motto = rng.pick(mottos)
        let trait = rng.pick(adjectives[dominant] ?? ["Singular"])

        let primary = brief.palette.first?.name ?? "Graphite"
        let secondary = brief.palette.dropFirst().first?.name

        let coat = secondary.map { "\(primary.lowercased()) and \($0.lowercased())" } ?? primary.lowercased()
        let opening = rng.pick(openings)
            .replacingOccurrences(of: "{trait}", with: trait.lowercased())
            .replacingOccurrences(of: "{coat}", with: coat)
            .replacingOccurrences(of: "{setting}", with: brief.setting.lowercased())
            .replacingOccurrences(of: "{hour}", with: brief.hour.lowercased())
        let middle = rng.pick(observations[second] ?? observations[.charm]!)
        let closing = rng.pick(closings[brief.marque] ?? closings[.ivory]!)

        let provenance = rng.pick(provenanceLines)
            .replacingOccurrences(of: "{setting}", with: brief.setting.lowercased())
            .replacingOccurrences(of: "{hour}", with: brief.hour.lowercased())

        return Dossier(
            name: fullName,
            epithet: epithet,
            motto: motto.latin,
            mottoTranslation: motto.english,
            signatureTrait: trait,
            curatorNote: "\(opening) \(middle) \(closing)",
            provenance: provenance
        )
    }

    private static func title(for marque: Marque, rng: inout SeededRandom) -> String? {
        switch marque {
        case .ivory: return rng.unit() < 0.3 ? rng.pick(["Master", "Miss"]) : nil
        case .silver: return rng.pick(["Sir", "Dame", "The Honourable"])
        case .gold: return rng.pick(["Lord", "Lady", "Baron", "Baroness"])
        case .platinum: return rng.pick(["Count", "Countess", "Marquis", "Marquise"])
        case .noir: return rng.pick(["His Serene Highness", "Her Serene Highness", "The Grand Duke", "The Grand Duchess"])
        }
    }

    // MARK: Corpora

    static let names = [
        "Mochi", "Clementine", "Bartholomew", "Pierre", "Coco", "Fitzgerald", "Odette", "Marcel",
        "Juniper", "Theodora", "Basil", "Ottoline", "Percival", "Margaux", "Florian", "Isadora",
        "Leopold", "Celeste", "Augustin", "Rosalind", "Ignatius", "Delphine", "Cassius", "Beatrix",
        "Wolfgang", "Ophelia", "Montgomery", "Sabine", "Lucien", "Henrietta", "Bijou", "Anouk",
        "Cosimo", "Valentina", "Hugo", "Philippa", "Sebastian", "Esmé", "Gatsby", "Truffle",
        "Biscotti", "Saffron", "Wellington", "Persimmon", "Tiberius", "Marzipan", "Peregrine", "Noisette",
    ]

    static let epithets: [Temperament.Trait: [String]] = [
        .poise: [
            "the Unbothered", "of Impeccable Posture", "Keeper of the Mantelpiece",
            "the Unhurried", "Arbiter of Elegance", "of the Perfect Tuck",
        ],
        .charm: [
            "Darling of the Salon", "the Beguiling", "Heartbreaker of the Drawing Room",
            "the Irresistible", "Favourite of the House", "of the Slow Blink",
        ],
        .mischief: [
            "Scourge of Vases", "the Uninvited", "Terror of the Tablecloth",
            "the Unrepentant", "Saboteur of Houseplants", "of the Midnight Gallop",
        ],
        .languor: [
            "Duchess of the Afternoon Nap", "the Horizontal", "Connoisseur of Sunbeams",
            "of the Warm Laundry", "Patron of the Cushion", "the Perpetually Reclined",
        ],
        .curiosity: [
            "Inspector of Boxes", "the Inquisitive", "Surveyor of High Shelves",
            "of the Open Cupboard", "Auditor of Groceries", "the Ever-Watchful",
        ],
    ]

    static let adjectives: [Temperament.Trait: [String]] = [
        .poise: ["Imperious", "Serene", "Statuesque", "Composed", "Regal"],
        .charm: ["Beguiling", "Winsome", "Magnetic", "Disarming", "Radiant"],
        .mischief: ["Incorrigible", "Roguish", "Impish", "Audacious", "Unruly"],
        .languor: ["Languid", "Indolent", "Drowsy", "Unhurried", "Velvet"],
        .curiosity: ["Inquisitive", "Vigilant", "Restless", "Searching", "Perceptive"],
    ]

    static let mottos: [(latin: String, english: String)] = [
        ("Somnus ante omnia", "Sleep before all"),
        ("Veni, vidi, dormivi", "I came, I saw, I napped"),
        ("Nihil sine cibo", "Nothing without supper"),
        ("Mea est sella", "The chair is mine"),
        ("Per aspera ad cubile", "Through hardship to the cushion"),
        ("Carpe radium solis", "Seize the sunbeam"),
        ("Non ducor, duco", "I am not led; I lead"),
        ("Festina lente", "Make haste slowly"),
        ("Omnia mea", "All of it is mine"),
        ("Cave felem", "Beware the cat"),
        ("Fortuna favet felibus", "Fortune favours the feline"),
        ("Dum spiro, ronchisso", "While I breathe, I purr"),
        ("Arca mea, regnum meum", "My box, my kingdom"),
        ("Semper sursum", "Ever upward — to the top shelf"),
        ("In vino nihil, in lacte omnia", "Nothing in wine, everything in cream"),
        ("Tempus fugit, felis manet", "Time flies; the cat stays"),
        ("Aut cibum aut nihil", "Supper or nothing"),
        ("Ex fenestra, imperium", "From the window, an empire"),
    ]

    static let openings = [
        "A {trait} specimen in {coat}, encountered in the {setting} at {hour}.",
        "Presented in {coat}, this {trait} subject was received in the {setting} during the {hour}.",
        "Observed at {hour} in the {setting}: a {trait} figure dressed in {coat}.",
        "The house records a {trait} arrival — {coat}, at ease in the {setting} at {hour}.",
        "Of {coat} livery and {trait} bearing, first noted in the {setting} at {hour}.",
    ]

    static let observations: [Temperament.Trait: [String]] = [
        .poise: [
            "Holds a pose with the discipline of a marble bust.",
            "Moves only when movement is beneath reproach.",
            "Sits as though the portrait were already being painted.",
        ],
        .charm: [
            "Wins rooms with a single, unhurried blink.",
            "Accepts admiration as a matter of course.",
            "Has been known to reduce visitors to baby talk within seconds.",
        ],
        .mischief: [
            "Small objects near table edges are advised to reconsider.",
            "Regards closed doors as a personal affront.",
            "Leaves a faint trail of displaced ornaments wherever it goes.",
        ],
        .languor: [
            "Naps with a dedication most reserve for the arts.",
            "Treats every warm surface as a private commission.",
            "Considers the afternoon a single, uninterrupted engagement.",
        ],
        .curiosity: [
            "No box goes uninspected, no bag unexplored.",
            "Monitors the household's affairs from the highest available vantage.",
            "Investigates each delivery with a customs officer's rigour.",
        ],
    ]

    static let closings: [Marque: [String]] = [
        .ivory: [
            "A charming addition to any collection.",
            "Understated, and all the better for it.",
            "Quietly excellent company.",
        ],
        .silver: [
            "A piece of rare polish and presence.",
            "The house recommends it without reservation.",
            "Collectors of discernment will take note.",
        ],
        .gold: [
            "A lot of genuine distinction.",
            "The kind of piece around which a collection is built.",
            "Destined, one suspects, for the catalogue cover.",
        ],
        .platinum: [
            "The house has seen few of its calibre.",
            "Museums would quarrel over it.",
            "An heirloom in the making.",
        ],
        .noir: [
            "Simply, the finest the house has ever handled.",
            "A once-in-a-generation acquisition.",
            "Legends are made of less.",
        ],
    ]

    static let provenanceLines = [
        "Acquired in the {setting} at {hour}, by private arrangement.",
        "Entered into the collection from the {setting}, {hour}.",
        "Received directly from the {setting} at {hour}; no prior owners of record.",
        "Private sale, the {setting}, {hour}.",
    ]
}
