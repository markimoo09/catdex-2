import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(Motion.self) private var motion
    @Environment(\.modelContext) private var context
    @State private var showSplash = !DebugHooks.noSplash
    @Namespace private var zoom

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            Theme.ink.ignoresSafeArea()

            Group {
                switch router.tab {
                case .salon:
                    NavigationStack(path: $router.salonPath) {
                        SalonView(zoom: zoom)
                            .navigationDestination(for: UUID.self) { DossierRoute(id: $0, zoom: zoom) }
                    }
                case .gallery:
                    NavigationStack(path: $router.galleryPath) {
                        GalleryView(zoom: zoom)
                            .navigationDestination(for: UUID.self) { DossierRoute(id: $0, zoom: zoom) }
                    }
                }
            }
            .transition(.opacity)

            if !router.isDeep {
                // Content scrolls away beneath the status bar rather than under the clock.
                VStack(spacing: 0) {
                    Color.clear.frame(height: 0).background(Theme.ink.ignoresSafeArea(edges: .top))
                    LinearGradient(colors: [Theme.ink, Theme.ink.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 14)
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)

                MaisonTabBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showSplash {
                SplashView { withAnimation(.easeInOut(duration: 0.6)) { showSplash = false } }
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.smooth(duration: 0.35), value: router.isDeep)
        .animation(.smooth(duration: 0.3), value: router.tab)
        .fullScreenCover(isPresented: $router.isAcquiring) {
            AcquireFlowView()
                .environment(router)
                .environment(motion)
        }
        .onAppear { motion.start() }
        .task {
            await DemoSeeder.seedIfRequested(context)
            applyOpenHook()
        }
    }

    private func applyOpenHook() {
        guard let open = DebugHooks.open, ["dossier", "certificate", "audience"].contains(open) else { return }
        var newest = FetchDescriptor<Acquisition>(sortBy: [SortDescriptor(\.lotNumber, order: .reverse)])
        newest.fetchLimit = 1
        guard let lot = try? context.fetch(newest).first else { return }
        router.tab = .gallery
        router.galleryPath = [lot.id]
    }
}

/// Resolves a dossier by id (navigation values must be Hashable).
struct DossierRoute: View {
    let id: UUID
    let zoom: Namespace.ID
    @Query private var matches: [Acquisition]

    init(id: UUID, zoom: Namespace.ID) {
        self.id = id
        self.zoom = zoom
        _matches = Query(filter: #Predicate<Acquisition> { $0.id == id })
    }

    var body: some View {
        if let lot = matches.first {
            DossierView(lot: lot)
                .navigationTransition(.zoom(sourceID: id, in: zoom))
        } else {
            Theme.ink.ignoresSafeArea()
        }
    }
}

// MARK: - Tab bar

struct MaisonTabBar: View {
    @Environment(Router.self) private var router

    var body: some View {
        HStack(spacing: 0) {
            tab(.salon, title: "Salon", symbol: "building.columns")
            AcquireButton { router.isAcquiring = true }
                .padding(.horizontal, 18)
            tab(.gallery, title: "Gallery", symbol: "square.stack")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .maisonGlass(in: Capsule())
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .padding(.bottom, 6)
    }

    private func tab(_ tab: Router.Tab, title: String, symbol: String) -> some View {
        let selected = router.tab == tab
        return Button {
            if router.tab == tab {
                // Re-tapping pops to the root.
                if tab == .salon { router.salonPath = [] } else { router.galleryPath = [] }
            }
            router.tab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: selected ? .semibold : .regular))
                    .symbolVariant(selected ? .fill : .none)
                SmallCaps(title, size: 8.5, color: selected ? Theme.champagne : Theme.mute, tracking: 1.8)
            }
            .foregroundStyle(selected ? Theme.champagne : Theme.mute)
            .frame(width: 76, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: router.tab)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(title)
    }
}

/// The gold aperture that opens the Lens.
struct AcquireButton: View {
    var action: () -> Void
    @State private var breathe = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.goldGradient)
                    .frame(width: 58, height: 58)
                    .shadow(color: Theme.gold.opacity(breathe ? 0.55 : 0.25), radius: breathe ? 16 : 8)
                Circle()
                    .stroke(Theme.ink.opacity(0.35), lineWidth: 1)
                    .frame(width: 46, height: 46)
                Aperture()
                    .stroke(Theme.ink.opacity(0.75), lineWidth: 1.2)
                    .frame(width: 26, height: 26)
            }
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("Acquire a cat")
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

/// Six-bladed aperture iris glyph.
struct Aperture: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        for i in 0..<6 {
            let a = Double(i) / 6 * .pi * 2
            let start = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            let end = CGPoint(x: c.x + cos(a + 2.1) * r * 0.42, y: c.y + sin(a + 2.1) * r * 0.42)
            p.move(to: start)
            p.addLine(to: end)
        }
        return p
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

// MARK: - Splash

struct SplashView: View {
    var onFinish: () -> Void
    @State private var reveal = 0.0
    @State private var rule = 0.0
    @State private var subtitle = false

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            Guilloche(color: Theme.champagne.opacity(0.09), lineWidth: 0.4, petals: 12, bands: 3, strands: 24)
                .opacity(rule)
                .centered(size: 520)
            VStack(spacing: 18) {
                Text("CATDEX")
                    .font(Theme.display(54))
                    .tracking(14)
                    .foregroundStyle(Theme.goldSheen)
                    .textRenderer(GlyphReveal(progress: reveal, spread: 0.55))
                Rectangle()
                    .fill(Theme.champagne.opacity(0.6))
                    .frame(width: 180 * rule, height: 0.5)
                SmallCaps("Maison  ·  Collection Privée", size: 10, color: Theme.parchment, tracking: 4)
                    .opacity(subtitle ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .task {
            withAnimation(.easeOut(duration: 1.3)) { reveal = 1 }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeInOut(duration: 0.9)) { rule = 1 }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeIn(duration: 0.6)) { subtitle = true }
            try? await Task.sleep(for: .milliseconds(1100))
            onFinish()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CatDex Maison")
    }
}
