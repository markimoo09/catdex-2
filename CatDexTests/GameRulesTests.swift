import XCTest
@testable import CatDex

final class ProgressionTests: XCTestCase {

    func testLevelThresholds() {
        XCTAssertEqual(Progression.level(forXP: 0), 1)
        XCTAssertEqual(Progression.level(forXP: 119), 1)
        XCTAssertEqual(Progression.level(forXP: 120), 2)
        XCTAssertEqual(Progression.level(forXP: 360), 3)
        XCTAssertEqual(Progression.level(forXP: 5_400), 10)
    }

    func testProgressStaysWithinUnitRange() {
        for xp in stride(from: 0, through: 6_000, by: 37) {
            let p = Progression.progress(xp: xp)
            XCTAssertGreaterThanOrEqual(p, 0)
            XCTAssertLessThan(p, 1)
        }
    }

    func testTitlesClimbWithLevel() {
        XCTAssertEqual(Progression.title(for: 1), "Visitor")
        XCTAssertEqual(Progression.title(for: 4), "Friend of the Maison")
        XCTAssertEqual(Progression.title(for: 30), "Founder's Circle")
    }

    func testEveryShowTierUnlocksAtALevel() {
        for tier in ShowTier.all where tier.unlockLevel > 1 {
            XCTAssertEqual(Progression.unlocks(at: tier.unlockLevel), ["\(tier.name) unlocked"])
        }
    }
}

final class CommissionTests: XCTestCase {

    func testBoardHasOneOfEachGroupAndIsStableForTheDay() {
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
        let night = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: .now)!
        let board = Commission.board(for: morning)
        XCTAssertEqual(board.map(\.group), [.acquire, .show, .care])
        XCTAssertEqual(board, Commission.board(for: night))
    }

    func testBoardRotatesAcrossDays() {
        let boards = (0..<10).map { Commission.board(for: Date(timeIntervalSinceNow: Double($0) * 86_400)).map(\.id) }
        XCTAssertGreaterThan(Set(boards).count, 1)
    }

    func testStatusCompletesAtGoal() {
        let c = Commission.pool.first { $0.id == "acquire2" }!
        XCTAssertFalse(CommissionStatus(commission: c, progress: 1, claimed: false).isClaimable)
        XCTAssertTrue(CommissionStatus(commission: c, progress: 2, claimed: false).isClaimable)
        XCTAssertFalse(CommissionStatus(commission: c, progress: 2, claimed: true).isClaimable)
    }
}

final class StreakTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func key(_ daysAgo: Int, from today: Date) -> String {
        DayKey.key(for: calendar.date(byAdding: .day, value: -daysAgo, to: today)!, calendar: calendar)
    }

    func testCountsConsecutiveDaysEndingToday() {
        let today = Date()
        let days: Set<String> = [key(0, from: today), key(1, from: today), key(2, from: today), key(4, from: today)]
        XCTAssertEqual(Streak.length(activeDays: days, today: today, calendar: calendar), 3)
    }

    func testSurvivesUntilMidnightFromYesterday() {
        let today = Date()
        let days: Set<String> = [key(1, from: today), key(2, from: today)]
        XCTAssertEqual(Streak.length(activeDays: days, today: today, calendar: calendar), 2)
    }

    func testBreaksAfterAMissedDay() {
        let today = Date()
        XCTAssertEqual(Streak.length(activeDays: [key(2, from: today)], today: today, calendar: calendar), 0)
    }
}

final class ConcoursTests: XCTestCase {

    func testRivalsAreSeededAndWithinTheTierRange() {
        for tier in ShowTier.all {
            let a = Concours.rival(for: tier, seed: 99), b = Concours.rival(for: tier, seed: 99)
            XCTAssertEqual(a.name, b.name)
            XCTAssertEqual(a.contenders.map(\.name), b.contenders.map(\.name))
            XCTAssertEqual(a.contenders.map(\.temperament), b.contenders.map(\.temperament))
            XCTAssertEqual(a.contenders.count, 3)
            XCTAssertEqual(a.contenders.map(\.marque), tier.rivalMarques)
            for cat in a.contenders {
                for trait in Temperament.Trait.allCases {
                    XCTAssertTrue(tier.rivalRange.contains(cat.temperament[trait]))
                }
            }
        }
    }

    func testCategoriesAreThreeDistinctTraits() {
        for seed in 0..<50 as Range<UInt64> {
            let traits = Concours.categories(seed: seed)
            XCTAssertEqual(traits.count, 3)
            XCTAssertEqual(Set(traits).count, 3)
        }
    }

    func testScoreAddsFlairAndExperienceAndTiesGoToThePatron() {
        let t = Temperament(poise: 50, charm: 50, mischief: 50, languor: 50, curiosity: 50)
        let patron = Contender(name: "A", marque: .gold, temperament: t, coat: [], experience: 2)
        let rival = Contender(name: "B", marque: .ivory, temperament: t, coat: [])
        XCTAssertEqual(patron.base(for: .poise), 56)
        let tie = RoundResult(trait: .poise, patron: patron, rival: rival, patronWhim: -6, rivalWhim: 0)
        XCTAssertTrue(tie.patronWon)
    }

    @MainActor
    func testMatchEndsAfterTwoWinsAndConsumesBothHands() {
        let strong = Temperament(poise: 100, charm: 100, mischief: 100, languor: 100, curiosity: 100)
        let team = (0..<3).map { Contender(name: "Cat \($0)", marque: .noir, temperament: strong, coat: []) }
        let match = ConcoursMatch(tier: .fete, team: team, seed: 7)
        while match.phase != .finished {
            if match.phase == .choosing { match.play(match.hand[0]) } else { match.advance() }
        }
        XCTAssertTrue(match.patronWon)
        XCTAssertEqual(match.patronWins, 2)
        XCTAssertEqual(match.rounds.count, 2)
        XCTAssertEqual(match.hand.count, 1)
    }
}

final class GroomingTests: XCTestCase {

    func testCostRisesWithTheTrait() {
        XCTAssertEqual(Grooming.cost(currentValue: 20), 40)
        XCTAssertLessThan(Grooming.cost(currentValue: 50), Grooming.cost(currentValue: 90))
    }

    func testMarqueGameValuesClimbWithRarity() {
        let ordered = Marque.allCases.sorted()
        XCTAssertEqual(ordered.map(\.xp), ordered.map(\.xp).sorted())
        XCTAssertEqual(ordered.map(\.finderFee), ordered.map(\.finderFee).sorted())
        XCTAssertEqual(ordered.map(\.flair), ordered.map(\.flair).sorted())
    }
}
