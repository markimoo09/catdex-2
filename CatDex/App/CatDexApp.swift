import SwiftData
import SwiftUI

@main
struct CatDexApp: App {
    let container: ModelContainer
    @State private var router = Router()
    @State private var motion = Motion()
    @State private var game: Game

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Acquisition.self, Ledger.self)
        } catch {
            fatalError("Could not open the collection: \(error)")
        }
        DemoSeeder.prepare(container.mainContext)
        self.container = container
        _game = State(initialValue: Game(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(motion)
                .environment(game)
                .preferredColorScheme(.light)
                .tint(Theme.roseDeep)
        }
        .modelContainer(container)
    }
}

/// App-wide navigation state.
@MainActor
@Observable
final class Router {
    enum Tab: Hashable { case salon, concours, gallery, patron }

    var tab: Tab = .salon
    var paths: [Tab: [UUID]] = [:]
    var isAcquiring = false
    var galleryMode: GalleryMode = .grid

    var isDeep: Bool { !(paths[tab] ?? []).isEmpty }

    func path(_ tab: Tab) -> Binding<[UUID]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    /// Opens a lot's dossier from anywhere (e.g. right after it's added).
    func showDossier(_ id: UUID) {
        tab = .gallery
        paths[.gallery] = [id]
    }

    init() {
        switch DebugHooks.open {
        case "gallery": tab = .gallery
        case "hang": tab = .gallery; galleryMode = .hang
        case "concours", "match": tab = .concours
        case "patron": tab = .patron
        case "lens": isAcquiring = true
        default: break
        }
        if DebugHooks.autoPhoto != nil { isAcquiring = true }
    }
}

enum GalleryMode: String, CaseIterable, Identifiable {
    case grid = "Collection"
    case hang = "Showcase"
    var id: String { rawValue }
}
