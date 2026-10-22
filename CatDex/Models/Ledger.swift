import Foundation
import SwiftData

/// The patron's persistent game state: purse, experience, and daily tallies.
/// One per install.
@Model
final class Ledger {
    var guineas: Int = 500
    var xp: Int = 0
    var showsEntered: Int = 0
    var showsWon: Int = 0
    var audiences: Int = 0
    var groomings: Int = 0
    var createdAt: Date = Date.now
    /// `[dayKey: DayTally]` JSON — what happened each day (for commissions and streaks).
    var dailyData: Data = Data()
    /// Commission keys claimed, `"yyyy-MM-dd:id"`.
    var claimedData: Data = Data()
    /// `[tierID: count]` JSON — rosettes won per concours tier.
    var rosettesData: Data = Data()

    init() {}

    var daily: [String: DayTally] {
        get { (try? JSONDecoder().decode([String: DayTally].self, from: dailyData)) ?? [:] }
        set { dailyData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var claimed: Set<String> {
        get { Set((try? JSONDecoder().decode([String].self, from: claimedData)) ?? []) }
        set { claimedData = (try? JSONEncoder().encode(Array(newValue))) ?? Data() }
    }

    var rosettes: [String: Int] {
        get { (try? JSONDecoder().decode([String: Int].self, from: rosettesData)) ?? [:] }
        set { rosettesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

/// Everything counted for one calendar day.
struct DayTally: Codable, Equatable {
    var acquired = 0
    var silverPlus = 0
    var showsEntered = 0
    var showsWon = 0
    var audiences = 0
    var groomings = 0

    subscript(metric: DayTally.Metric) -> Int {
        switch metric {
        case .acquired: acquired
        case .silverPlus: silverPlus
        case .showsEntered: showsEntered
        case .showsWon: showsWon
        case .audiences: audiences
        case .groomings: groomings
        }
    }

    enum Metric: String, Codable {
        case acquired, silverPlus, showsEntered, showsWon, audiences, groomings
    }

    var isActive: Bool { acquired > 0 || showsEntered > 0 }
}

enum DayKey {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
