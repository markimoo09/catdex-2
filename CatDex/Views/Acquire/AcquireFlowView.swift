import SwiftData
import SwiftUI

/// Lens → Appraisal → Unsealing → into the collection.
struct AcquireFlowView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Game.self) private var game
    @Query(sort: \Acquisition.lotNumber, order: .reverse) private var lots: [Acquisition]

    @State private var session: AppraisalSession?
    @State private var phase: Phase = .lens

    enum Phase: Equatable { case lens, appraisal, unsealing }

    private var nextLot: Int { (lots.first?.lotNumber ?? 0) + 1 }

    var body: some View {
        ZStack {
            Theme.pearl.ignoresSafeArea()
            switch phase {
            case .lens:
                LensView(lotNumber: nextLot, onPhoto: { begin(with: $0) }, onClose: { dismiss() })
                    .transition(.opacity)
            case .appraisal:
                if let session {
                    AppraisalView(session: session, onRetake: retake)
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            case .unsealing:
                if let session, let lot = session.presentation {
                    UnsealView(lot: lot, onAdd: add, onRelease: { dismiss() })
                        .transition(.opacity)
                }
            }
        }
        .animation(.smooth(duration: 0.6), value: phase)
        .task { autoPhotoIfRequested() }
    }

    private func begin(with image: UIImage, precut: UIImage? = nil) {
        let session = AppraisalSession(
            original: image, lotNumber: nextLot, recent: lots.prefix(Appraiser.pityThreshold).map(\.marque), precut: precut
        )
        self.session = session
        phase = .appraisal
        Task {
            await session.run()
            if session.wasAbandoned {
                retake()
            } else {
                phase = .unsealing
            }
        }
    }

    private func retake() {
        session = nil
        phase = .lens
    }

    private func add() {
        guard let session, let acquisition = session.makeAcquisition() else { return }
        context.insert(acquisition)
        try? context.save()
        game.recordAcquisition(acquisition)
        let id = acquisition.id
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            router.showDossier(id)
        }
    }

    private func autoPhotoIfRequested() {
        guard phase == .lens, session == nil, let path = DebugHooks.autoPhoto,
              let image = UIImage(contentsOfFile: path) else { return }
        let precut = DebugHooks.autoPrecut.flatMap { UIImage(contentsOfFile: $0) }
        begin(with: image, precut: precut)
    }
}
