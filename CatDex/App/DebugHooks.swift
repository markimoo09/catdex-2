import Foundation

/// DEBUG-only launch hooks for scripted Simulator runs and UI tests
/// (`SIMCTL_CHILD_<NAME>=…` with `xcrun simctl launch`). All inert in Release.
enum DebugHooks {
    private static func env(_ key: String) -> String? {
        #if DEBUG
        ProcessInfo.processInfo.environment[key]
        #else
        nil
        #endif
    }

    /// Wipe the collection at launch.
    static var reset: Bool { env("RESET") == "1" }
    /// Folder of `<name>.jpg` (+ optional `<name>-cutout.png`) to seed as lots.
    static var seedDirectory: String? { env("SEED_DIR") }
    /// Comma-separated marques assigned to seeded lots in order.
    static var seedMarques: [Marque] {
        (env("SEED_MARQUES") ?? "").split(separator: ",").compactMap { Marque(rawValue: String($0)) }
    }
    /// Photo fed straight into the appraisal ceremony at launch.
    static var autoPhoto: String? { env("AUTO_PHOTO") }
    /// A pre-lifted cutout for `AUTO_PHOTO` (the Simulator lacks the lift model).
    static var autoPrecut: String? { env("AUTO_PRECUT") }
    /// Pin the marque roll.
    static var forceMarque: Marque? { env("FORCE_MARQUE").flatMap(Marque.init(rawValue:)) }
    /// Treat every photo as not-a-cat (doubt interstitial).
    static var forceDoubt: Bool { env("FORCE_DOUBT") == "1" }
    /// Break the seal without a tap.
    static var autoUnseal: Bool { env("AUTO_UNSEAL") == "1" }
    /// Add the revealed lot to the collection without a tap.
    static var autoAdd: Bool { env("AUTO_ADD") == "1" }
    /// Skip the opening wordmark.
    static var noSplash: Bool { env("NO_SPLASH") == "1" }
    /// Start somewhere specific: gallery, catalogue, dossier, certificate, audience, lens.
    static var open: String? { env("OPEN") }
    /// Scroll a screen to its lower content (synthesised scrolls are unreliable on the Simulator).
    static var scrollDown: Bool { env("SCROLL_DOWN") == "1" }
}
