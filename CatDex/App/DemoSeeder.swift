import SwiftData
import UIKit

/// DEBUG launch seeding: wipes and/or fills the collection from a folder of photos.
@MainActor
enum DemoSeeder {

    static func prepare(_ context: ModelContext) {
        guard DebugHooks.reset else { return }
        try? context.delete(model: Acquisition.self)
        try? context.save()
    }

    /// Runs the real appraisal pipeline at zero pace for each `<name>.jpg` in
    /// `SEED_DIR`, using `<name>-cutout.png` as the lifted subject when present.
    static func seedIfRequested(_ context: ModelContext) async {
        guard let dir = DebugHooks.seedDirectory else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Acquisition>())) ?? 0
        guard existing == 0 else { return }

        let url = URL(fileURLWithPath: dir)
        let files = ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) && !$0.lastPathComponent.contains("-cutout") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let marques = DebugHooks.seedMarques

        for (index, file) in files.enumerated() {
            guard let original = UIImage(contentsOfFile: file.path) else { continue }
            let cutURL = file.deletingLastPathComponent()
                .appendingPathComponent(file.deletingPathExtension().lastPathComponent + "-cutout.png")
            let precut = UIImage(contentsOfFile: cutURL.path)
            // Spread acquisitions over recent days and hours for a lived-in collection.
            let date = Calendar.current.date(byAdding: .hour, value: -(files.count - index) * 19, to: .now) ?? .now
            let session = AppraisalSession(
                original: original, lotNumber: index + 1, recent: [], acquiredAt: date, precut: precut,
                forcedMarque: index < marques.count ? marques[index] : nil
            )
            await session.run(pace: 0)
            guard let acquisition = session.makeAcquisition() else { continue }
            context.insert(acquisition)
        }
        try? context.save()
    }
}
