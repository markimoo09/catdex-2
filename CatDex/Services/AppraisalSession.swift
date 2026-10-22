import SwiftUI
import UIKit

/// Drives the appraisal ceremony for one photograph, stage by stage.
@MainActor
@Observable
final class AppraisalSession {

    enum Stage: Int, CaseIterable, Comparable {
        case isolating, readingCoat, provenance, composing, appraising, sealed

        static func < (a: Stage, b: Stage) -> Bool { a.rawValue < b.rawValue }

        var title: String {
            switch self {
            case .isolating: "Isolating the subject"
            case .readingCoat: "Reading the coat"
            case .provenance: "Noting provenance"
            case .composing: "Composing the dossier"
            case .appraising: "Appraising"
            case .sealed: "Sealed"
            }
        }
    }

    let original: UIImage
    let lotNumber: Int
    let acquiredAt: Date
    private let recent: [Marque]
    private let precut: UIImage?
    private let forcedMarque: Marque?

    private(set) var stage: Stage = .isolating
    private(set) var cutout: CutoutResult?
    private(set) var verdict: CatVerdict = .unverified
    private(set) var palette: [Swatch] = []
    private(set) var setting: String?
    private(set) var hour: String
    private(set) var draft = DossierDraft()
    private(set) var dossier: Dossier?
    private(set) var aiAuthored = false
    private(set) var appraisal: Appraisal?
    private(set) var isDoubtful = false
    private(set) var wasAbandoned = false

    private var doubtContinuation: CheckedContinuation<Bool, Never>?
    private let seed: UInt64

    init(
        original: UIImage, lotNumber: Int, recent: [Marque], acquiredAt: Date = .now,
        precut: UIImage? = nil, forcedMarque: Marque? = nil
    ) {
        let upright = CutoutService.normalized(original)
        self.original = upright
        self.lotNumber = lotNumber
        self.recent = recent
        self.acquiredAt = acquiredAt
        self.precut = precut
        self.forcedMarque = forcedMarque ?? DebugHooks.forceMarque
        self.hour = HourLexicon.label(for: acquiredAt)
        self.seed = ImageFingerprint.seed(for: upright)
    }

    var presentation: LotPresentation? {
        guard let cutout, let dossier, let appraisal else { return nil }
        return LotPresentation(
            lotNumber: lotNumber, name: dossier.name, epithet: dossier.epithet, marque: appraisal.marque,
            valuation: appraisal.valuation, palette: palette, cutout: cutout.cutout, isCameo: cutout.isCameo
        )
    }

    // MARK: Ceremony

    /// Runs every stage. `pace` scales the ceremonial pauses (0 for seeding).
    func run(pace: Double = 1) async {
        let started = Date()

        // 1 — Isolating
        async let lifted = CutoutService.lift(precut ?? original)
        async let verdictCheck = Perception.verifyCat(in: original)
        let result = await lifted
        let verdict = await verdictCheck
        self.verdict = DebugHooks.forceDoubt ? .notCat : verdict
        withAnimation(.easeInOut(duration: 0.4)) { cutout = result }
        await pause(max(0, 2.6 - Date().timeIntervalSince(started)), pace)

        if self.verdict == .notCat {
            isDoubtful = true
            let proceed = await withCheckedContinuation { doubtContinuation = $0 }
            isDoubtful = false
            guard proceed else { wasAbandoned = true; return }
        }

        // 2 — Reading the coat
        advance(to: .readingCoat)
        let cut = result
        let swatches = await Task.detached(priority: .userInitiated) {
            PaletteExtractor.palette(of: cut.cutout, isCameo: cut.isCameo)
        }.value
        withAnimation(.spring(duration: 0.6)) { palette = swatches }
        await pause(1.6, pace)

        // 3 — Provenance
        advance(to: .provenance)
        let read = await Perception.setting(of: original)
        var rng = SeededRandom(seed: seed)
        withAnimation(.easeOut(duration: 0.5)) {
            setting = read ?? rng.pick(SettingLexicon.fallbacks)
        }
        await pause(1.3, pace)

        // 4 — Composing
        var system = SystemRandomNumberGenerator()
        let appraisal = Appraiser.appraise(seed: seed, recent: recent, forced: forcedMarque, using: &system)
        self.appraisal = appraisal
        advance(to: .composing)
        let brief = CuratorBrief(
            marque: appraisal.marque, temperament: appraisal.temperament, palette: swatches,
            setting: setting ?? "Private Residence", hour: hour, seed: seed, verdict: self.verdict
        )
        let composeStart = Date()
        if pace == 0 {
            dossier = HouseCurator.write(brief)
        } else {
            let written = await Curator.compose(brief) { [weak self] draft in
                self?.draft = draft
            }
            dossier = written.dossier
            aiAuthored = written.aiAuthored
            await pause(max(0, 1.2 - Date().timeIntervalSince(composeStart)), pace)
        }

        // 5 — Appraising
        advance(to: .appraising)
        await pause(1.8, pace)

        advance(to: .sealed)
    }

    func resolveDoubt(proceed: Bool) {
        doubtContinuation?.resume(returning: proceed)
        doubtContinuation = nil
    }

    private func advance(to next: Stage) {
        withAnimation(.smooth(duration: 0.5)) { stage = next }
    }

    private func pause(_ seconds: Double, _ pace: Double) async {
        guard pace > 0, seconds > 0 else { return }
        try? await Task.sleep(for: .seconds(seconds * pace))
    }

    // MARK: Entry

    func makeAcquisition() -> Acquisition? {
        guard let cutout, let dossier, let appraisal else { return nil }
        let cutoutImage = ImageStore.downscaled(cutout.cutout, maxDimension: 1400)
        let originalImage = ImageStore.downscaled(original, maxDimension: 1800)
        return Acquisition(
            lotNumber: lotNumber,
            acquiredAt: acquiredAt,
            marque: appraisal.marque,
            dossier: dossier,
            setting: setting ?? "Private Residence",
            hourLabel: hour,
            temperament: appraisal.temperament,
            valuation: appraisal.valuation,
            palette: palette,
            isCameo: cutout.isCameo,
            catConfidence: verdict.confidence,
            aiAuthored: aiAuthored,
            cutoutData: (cutout.isCameo ? cutoutImage.jpegData(compressionQuality: 0.88) : cutoutImage.pngData()) ?? Data(),
            originalData: originalImage.jpegData(compressionQuality: 0.85) ?? Data()
        )
    }
}

/// Everything a lot card needs, whether or not the lot is saved yet.
struct LotPresentation: Identifiable {
    var id: Int { lotNumber }
    var lotNumber: Int
    var name: String
    var epithet: String
    var marque: Marque
    var valuation: Int
    var palette: [Swatch]
    var cutout: UIImage
    var isCameo: Bool
}

extension Acquisition {
    var presentation: LotPresentation {
        LotPresentation(
            lotNumber: lotNumber, name: name, epithet: epithet, marque: marque, valuation: valuation,
            palette: palette, cutout: ImageStore.cutout(for: self), isCameo: isCameo
        )
    }
}

/// Decoded-image cache so galleries don't re-decode on every frame.
enum ImageStore {
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        return cache
    }()

    static func cutout(for a: Acquisition) -> UIImage {
        image(key: "\(a.id)-cutout", data: a.cutoutData)
    }

    static func original(for a: Acquisition) -> UIImage {
        image(key: "\(a.id)-original", data: a.originalData)
    }

    private static func image(key: String, data: Data) -> UIImage {
        if let hit = cache.object(forKey: key as NSString) { return hit }
        let decoded = UIImage(data: data)?.preparingForDisplay() ?? UIImage(data: data) ?? UIImage()
        cache.setObject(decoded, forKey: key as NSString)
        return decoded
    }

    static func evict(_ id: UUID) {
        cache.removeObject(forKey: "\(id)-cutout" as NSString)
        cache.removeObject(forKey: "\(id)-original" as NSString)
    }

    static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
