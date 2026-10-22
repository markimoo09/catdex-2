import SwiftData
import SwiftUI

@main
struct CatDexApp: App {
    let container: ModelContainer
    @State private var router = Router()
    @State private var motion = Motion()

    init() {
        do {
            container = try ModelContainer(for: Acquisition.self)
        } catch {
            fatalError("Could not open the collection: \(error)")
        }
        DemoSeeder.prepare(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(motion)
                .preferredColorScheme(.dark)
                .tint(Theme.champagne)
        }
        .modelContainer(container)
    }
}

/// App-wide navigation state.
@MainActor
@Observable
final class Router {
    enum Tab: Hashable { case salon, gallery }

    var tab: Tab = .salon
    var salonPath: [UUID] = []
    var galleryPath: [UUID] = []
    var isAcquiring = false
    var galleryMode: GalleryMode = .salon

    var isDeep: Bool {
        switch tab {
        case .salon: !salonPath.isEmpty
        case .gallery: !galleryPath.isEmpty
        }
    }

    /// Opens a lot's dossier from anywhere (e.g. right after it's added).
    func showDossier(_ id: UUID) {
        tab = .gallery
        galleryPath = [id]
    }

    init() {
        switch DebugHooks.open {
        case "gallery": tab = .gallery
        case "catalogue": tab = .gallery; galleryMode = .catalogue
        case "lens": isAcquiring = true
        default: break
        }
        if DebugHooks.autoPhoto != nil { isAcquiring = true }
    }
}

enum GalleryMode: String, CaseIterable, Identifiable {
    case salon = "Salon Hang"
    case catalogue = "Catalogue"
    var id: String { rawValue }
}
