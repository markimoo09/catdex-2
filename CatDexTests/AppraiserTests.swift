import XCTest
@testable import CatDex

final class AppraiserTests: XCTestCase {

    func testMarqueWeightsSumToOneHundred() {
        XCTAssertEqual(Marque.allCases.reduce(0) { $0 + $1.weight }, 100)
    }

    func testRollDistributionRoughlyMatchesWeights() {
        var rng = SeededRandom(seed: 42)
        var counts: [Marque: Int] = [:]
        for _ in 0..<20_000 {
            counts[Appraiser.rollMarque(recent: [], using: &rng), default: 0] += 1
        }
        for marque in Marque.allCases {
            let share = Double(counts[marque, default: 0]) / 20_000 * 100
            XCTAssertEqual(share, Double(marque.weight), accuracy: 1.5, "\(marque)")
        }
    }

    func testNineLotsBelowGoldGuaranteeGoldOrBetter() {
        let drySpell = Array(repeating: Marque.ivory, count: 9)
        for seed in 0..<200 {
            var rng = SeededRandom(seed: UInt64(seed))
            XCTAssertGreaterThanOrEqual(Appraiser.rollMarque(recent: drySpell, using: &rng), .gold)
        }
    }

    func testPityDoesNotApplyAfterAGoldInTheWindow() {
        var spell = Array(repeating: Marque.silver, count: 9)
        spell[4] = .gold
        var sawBelowGold = false
        for seed in 0..<200 {
            var rng = SeededRandom(seed: UInt64(seed))
            if Appraiser.rollMarque(recent: spell, using: &rng) < .gold { sawBelowGold = true }
        }
        XCTAssertTrue(sawBelowGold)
    }

    func testTemperamentIsDeterministicAndRespectsTheFloor() {
        for marque in Marque.allCases {
            let a = Appraiser.temperament(seed: 0xC0FFEE, marque: marque)
            let b = Appraiser.temperament(seed: 0xC0FFEE, marque: marque)
            XCTAssertEqual(a, b)
            for trait in Temperament.Trait.allCases {
                XCTAssertGreaterThanOrEqual(a[trait], marque.temperamentFloor)
                XCTAssertLessThanOrEqual(a[trait], 100)
            }
        }
    }

    func testValuationStaysInsideTheMarqueBandAndRoundsToFifty() {
        for marque in Marque.allCases {
            for seed in 0..<50 as Range<UInt64> {
                let t = Appraiser.temperament(seed: seed, marque: marque)
                let v = Appraiser.valuation(marque: marque, temperament: t, seed: seed)
                XCTAssertTrue(marque.valuationRange.contains(v), "\(marque) \(v)")
                XCTAssertEqual(v % 50, 0)
            }
        }
    }
}

final class CuratorTests: XCTestCase {

    private func brief(seed: UInt64 = 7, marque: Marque = .gold) -> CuratorBrief {
        CuratorBrief(
            marque: marque,
            temperament: Appraiser.temperament(seed: seed, marque: marque),
            palette: Swatch.houseDefault,
            setting: "Drawing Room",
            hour: "Golden Hour",
            seed: seed,
            verdict: .unverified
        )
    }

    func testHouseCuratorIsDeterministic() {
        XCTAssertEqual(HouseCurator.write(brief()), HouseCurator.write(brief()))
    }

    func testHouseCuratorFillsEveryField() {
        for seed in 0..<40 as Range<UInt64> {
            for marque in Marque.allCases {
                let d = HouseCurator.write(brief(seed: seed, marque: marque))
                XCTAssertFalse(d.name.isEmpty)
                XCTAssertFalse(d.epithet.isEmpty)
                XCTAssertFalse(d.motto.isEmpty)
                XCTAssertFalse(d.curatorNote.contains("{"), d.curatorNote)
                XCTAssertFalse(d.provenance.contains("{"), d.provenance)
                XCTAssertTrue(d.curatorNote.contains("drawing room"))
            }
        }
    }

    func testHouseVoiceAnswersFoodQuestionsInCharacter() {
        let persona = Persona(
            name: "Clementine", epithet: "the Unbothered", marque: .gold,
            temperament: Temperament(poise: 90, charm: 50, mischief: 40, languor: 60, curiosity: 30),
            motto: "Nihil sine cibo", mottoTranslation: "Nothing without supper",
            setting: "Garden", palette: ["Marmalade"], seed: 3
        )
        let reply = HouseVoice.reply(to: "Are you hungry for some tuna?", persona: persona, turn: 0)
        XCTAssertFalse(reply.isEmpty)
        XCTAssertFalse(reply.contains("{"))
    }
}

final class PaletteTests: XCTestCase {

    func testNamesNearestCoutureColour() {
        XCTAssertEqual(CoutureColors.name(for: SIMD3(0.82, 0.46, 0.18)), "Marmalade")
        XCTAssertEqual(CoutureColors.name(for: SIMD3(0.05, 0.05, 0.06)), "Jet")
    }

    func testExcludesNamesAlreadyUsed() {
        let first = CoutureColors.name(for: SIMD3(0.82, 0.46, 0.18))
        let second = CoutureColors.name(for: SIMD3(0.82, 0.46, 0.18), excluding: [first])
        XCTAssertNotEqual(first, second)
    }

    func testExtractsDominantColoursFromASolidImage() {
        let size = CGSize(width: 40, height: 40)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.82, green: 0.46, blue: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 40, height: 28)))
            UIColor(white: 0.95, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 28, width: 40, height: 12))
        }
        let palette = PaletteExtractor.palette(of: image, isCameo: false)
        XCTAssertGreaterThanOrEqual(palette.count, 2)
        XCTAssertEqual(palette.first?.name, "Marmalade")
        XCTAssertEqual(palette.reduce(0) { $0 + $1.share }, 1, accuracy: 0.05)
    }

    func testMonochromeDetection() {
        let greys = [Swatch(name: "Onyx", red: 0.08, green: 0.08, blue: 0.08, share: 0.7),
                     Swatch(name: "Pearl", red: 0.9, green: 0.89, blue: 0.87, share: 0.3)]
        XCTAssertTrue(greys.isMonochrome)
        XCTAssertFalse([Swatch(name: "Marmalade", red: 0.82, green: 0.46, blue: 0.18, share: 1)].isMonochrome)
    }
}

final class PatronageTests: XCTestCase {

    private func date(_ day: Int, _ hour: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    func testEmptyCollectionIsAVisitor() {
        let p = Patronage(lots: [])
        XCTAssertEqual(p.tier.name, "Visitor")
        XCTAssertEqual(p.appraisal, 0)
        XCTAssertEqual(p.completedExhibitions, 0)
    }

    func testPrestigeClimbsTiers() {
        let lots = [Marque.noir, .gold, .ivory].map {
            LotSummary(marque: $0, acquiredAt: date(1, 12), valuation: 1000, isMonochrome: false)
        }
        let p = Patronage(lots: lots)
        XCTAssertEqual(p.prestige, 21)
        XCTAssertEqual(p.tier.name, "Patron")
        XCTAssertEqual(p.nextTier?.name, "Benefactor")
        XCTAssertEqual(p.appraisal, 3000)
    }

    func testExhibitionsTrackTimeOfDayAndDays() {
        let lots = [
            LotSummary(marque: .ivory, acquiredAt: date(1, 23), valuation: 900, isMonochrome: true),
            LotSummary(marque: .silver, acquiredAt: date(2, 18), valuation: 3000, isMonochrome: false),
            LotSummary(marque: .gold, acquiredAt: date(2, 10), valuation: 9000, isMonochrome: false),
        ]
        let byID = Dictionary(uniqueKeysWithValues: Exhibition.evaluate(lots, calendar: Calendar(identifier: .gregorian)).map { ($0.id, $0) })
        XCTAssertTrue(byID["nocturne"]!.isComplete)
        XCTAssertTrue(byID["golden"]!.isComplete)
        XCTAssertTrue(byID["monochrome"]!.isComplete)
        XCTAssertTrue(byID["couture"]!.isComplete)
        XCTAssertTrue(byID["gilded"]!.isComplete)
        XCTAssertEqual(byID["season"]!.current, 2)
        XCTAssertEqual(byID["amis"]!.current, 2)
        XCTAssertFalse(byID["noir"]!.isComplete)
    }

    func testPieceDuJourIsStableWithinADay() {
        let items = Array(0..<10)
        let morning = date(5, 8), night = date(5, 22)
        XCTAssertEqual(PieceDuJour.pick(from: items, on: morning), PieceDuJour.pick(from: items, on: night))
    }

    func testSettingLexiconMapsSceneLabels() {
        XCTAssertEqual(SettingLexicon.setting(for: ["cat", "sofa"]), "Drawing Room")
        XCTAssertEqual(SettingLexicon.setting(for: ["grass"]), "Garden")
        XCTAssertNil(SettingLexicon.setting(for: ["cat"]))
    }
}
