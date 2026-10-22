import Foundation

/// The facts about one lot that progression cares about.
struct LotSummary: Equatable {
    var marque: Marque
    var acquiredAt: Date
    var valuation: Int
    var isMonochrome: Bool

    init(marque: Marque, acquiredAt: Date, valuation: Int, isMonochrome: Bool) {
        self.marque = marque
        self.acquiredAt = acquiredAt
        self.valuation = valuation
        self.isMonochrome = isMonochrome
    }

    init(_ a: Acquisition) {
        self.init(marque: a.marque, acquiredAt: a.acquiredAt, valuation: a.valuation, isMonochrome: a.palette.isMonochrome)
    }
}

/// Collection-wide figures and Exhibitions, derived live from the lots.
struct CollectionStats: Equatable {
    let appraisal: Int
    let lotCount: Int
    let memberSince: Date?
    let exhibitions: [Exhibition]

    init(lots: [LotSummary], calendar: Calendar = .current) {
        appraisal = lots.reduce(0) { $0 + $1.valuation }
        lotCount = lots.count
        memberSince = lots.map(\.acquiredAt).min()
        exhibitions = Exhibition.evaluate(lots, calendar: calendar)
    }

    var completedExhibitions: Int { exhibitions.filter(\.isComplete).count }
}

/// A curated achievement set — shown as a medallion.
struct Exhibition: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let current: Int
    let goal: Int

    var isComplete: Bool { current >= goal }
    var progress: Double { min(1, Double(current) / Double(goal)) }

    static func evaluate(_ lots: [LotSummary], calendar: Calendar = .current) -> [Exhibition] {
        let marques = Set(lots.map(\.marque))
        let days = Dictionary(grouping: lots) { calendar.startOfDay(for: $0.acquiredAt) }
        let busiestDay = days.values.map(\.count).max() ?? 0

        return [
            Exhibition(id: "vernissage", title: "Vernissage", subtitle: "The first acquisition",
                       symbol: "sparkle", current: min(lots.count, 1), goal: 1),
            Exhibition(id: "salon", title: "Salon de Cinq", subtitle: "Five lots in the collection",
                       symbol: "square.grid.3x2", current: min(lots.count, 5), goal: 5),
            Exhibition(id: "gilded", title: "The Gilded Room", subtitle: "A Gold marque or finer",
                       symbol: "crown", current: lots.contains { $0.marque >= .gold } ? 1 : 0, goal: 1),
            Exhibition(id: "nocturne", title: "Nocturne", subtitle: "Acquired after dark",
                       symbol: "moon.stars", current: lots.contains { HourLexicon.isNocturne($0.acquiredAt, calendar: calendar) } ? 1 : 0, goal: 1),
            Exhibition(id: "golden", title: "Golden Hour", subtitle: "Acquired in the golden light",
                       symbol: "sun.horizon", current: lots.contains { HourLexicon.isGoldenHour($0.acquiredAt, calendar: calendar) } ? 1 : 0, goal: 1),
            Exhibition(id: "monochrome", title: "Monochrome", subtitle: "A cat in black, white or grey",
                       symbol: "circle.lefthalf.filled", current: lots.contains(where: \.isMonochrome) ? 1 : 0, goal: 1),
            Exhibition(id: "couture", title: "Haute Couture", subtitle: "Three different marques",
                       symbol: "rhombus", current: min(marques.count, 3), goal: 3),
            Exhibition(id: "amis", title: "Les Amis", subtitle: "Three acquisitions in a day",
                       symbol: "person.3", current: min(busiestDay, 3), goal: 3),
            Exhibition(id: "season", title: "The Season", subtitle: "Acquisitions on five days",
                       symbol: "calendar", current: min(days.count, 5), goal: 5),
            Exhibition(id: "noir", title: "Noir", subtitle: "The rarest marque of all",
                       symbol: "seal", current: marques.contains(.noir) ? 1 : 0, goal: 1),
        ]
    }
}

/// A daily featured cat, stable for the whole day.
enum PieceDuJour {
    static func pick<T>(from items: [T], on date: Date = .now, calendar: Calendar = .current) -> T? {
        guard !items.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        var rng = SeededRandom(seed: UInt64(day) &* 0x2545_F491_4F6C_DD1D)
        return items[Int(rng.next() % UInt64(items.count))]
    }
}
