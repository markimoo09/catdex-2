import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(Motion.self) private var motion
    @Environment(Game.self) private var game
    @Environment(\.modelContext) private var context
    @State private var showSplash = !DebugHooks.noSplash
    @Namespace private var zoom

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            Theme.ground.ignoresSafeArea()

            Group {
                switch router.tab {
                case .salon:
                    stack(.salon) { SalonView(zoom: zoom) }
                case .concours:
                    stack(.concours) { ConcoursLobby() }
                case .gallery:
                    stack(.gallery) { GalleryView(zoom: zoom) }
                case .patron:
                    stack(.patron) { PatronView() }
                }
            }
            .transition(.opacity)

            if !router.isDeep {
                MaisonTabBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            VStack { RewardToasts(); Spacer() }
                .zIndex(5)

            if let levelUp = game.levelUp {
                LevelUpCard(levelUp: levelUp) { withAnimation(.smooth) { game.levelUp = nil } }
                    .transition(.opacity)
                    .zIndex(9)
            }

            if showSplash {
                SplashView { withAnimation(.easeInOut(duration: 0.5)) { showSplash = false } }
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.smooth(duration: 0.3), value: router.isDeep)
        .animation(.smooth(duration: 0.25), value: router.tab)
        .fullScreenCover(isPresented: $router.isAcquiring) {
            AcquireFlowView()
                .environment(router)
                .environment(motion)
                .environment(game)
        }
        .onAppear { motion.start() }
        .task {
            await DemoSeeder.seedIfRequested(context)
            game.adoptCollection((try? context.fetch(FetchDescriptor<Acquisition>())) ?? [])
            applyOpenHook()
        }
    }

    private func stack<Content: View>(_ tab: Router.Tab, @ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack(path: router.path(tab)) {
            content()
                // Inside the stack so each tab root's scroll content honours it.
                .safeAreaInset(edge: .top, spacing: 0) {
                    PatronHUD()
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 8)
                        .background(Theme.pearl.opacity(0.94).ignoresSafeArea(edges: .top))
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 0.5) }
                }
                .navigationDestination(for: UUID.self) { DossierRoute(id: $0, zoom: zoom) }
        }
    }

    private func applyOpenHook() {
        guard let open = DebugHooks.open, ["dossier", "certificate", "audience", "groom"].contains(open) else { return }
        var newest = FetchDescriptor<Acquisition>(sortBy: [SortDescriptor(\.lotNumber, order: .reverse)])
        newest.fetchLimit = 1
        guard let lot = try? context.fetch(newest).first else { return }
        router.showDossier(lot.id)
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
            Theme.pearl.ignoresSafeArea()
        }
    }
}

// MARK: - Tab bar

struct MaisonTabBar: View {
    @Environment(Router.self) private var router
    @Environment(Game.self) private var game

    var body: some View {
        HStack(spacing: 0) {
            tab(.salon, title: "Salon", symbol: "house", badge: game.claimableCount)
            tab(.concours, title: "Shows", symbol: "trophy")
            AcquireButton { router.isAcquiring = true }
                .padding(.horizontal, 6)
            tab(.gallery, title: "Gallery", symbol: "square.grid.2x2")
            tab(.patron, title: "Patron", symbol: "person.crop.circle")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .maisonGlass(in: Capsule())
        .shadow(color: Color(hex: 0x8A5A50, alpha: 0.16), radius: 16, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func tab(_ tab: Router.Tab, title: String, symbol: String, badge: Int = 0) -> some View {
        let selected = router.tab == tab
        return Button {
            if router.tab == tab { router.paths[tab] = [] }
            router.tab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: selected ? .semibold : .regular))
                    .symbolVariant(selected ? .fill : .none)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text("\(badge)")
                                .font(Theme.number(9, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(minWidth: 14, minHeight: 14)
                                .background(Circle().fill(Theme.roseDeep))
                                .offset(x: 9, y: -6)
                        }
                    }
                Text(title)
                    .font(Theme.caption(10, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? Theme.roseDeep : Theme.ink3)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: router.tab)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(title)
    }
}

/// The rose-gold aperture that opens the Lens.
struct AcquireButton: View {
    var action: () -> Void
    @State private var breathe = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.roseGold)
                    .frame(width: 54, height: 54)
                    .shadow(color: Theme.rose.opacity(breathe ? 0.55 : 0.3), radius: breathe ? 12 : 6, y: 3)
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 1.2)
                    .frame(width: 44, height: 44)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("Acquire a cat")
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathe = true }
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

// MARK: - Splash

struct SplashView: View {
    var onFinish: () -> Void
    @State private var reveal = 0.0
    @State private var ring = 0.0

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            Guilloche(color: Theme.rose.opacity(0.18), lineWidth: 0.5, petals: 12, bands: 3, strands: 24)
                .opacity(ring)
                .scaleEffect(0.9 + ring * 0.1)
                .centered(size: 460)
            VStack(spacing: 8) {
                Text("CatDex")
                    .font(.system(size: 52, weight: .heavy))
                    .tracking(-1.5)
                    .foregroundStyle(Theme.roseGold)
                    .textRenderer(GlyphReveal(progress: reveal, spread: 0.55))
                Text("Maison")
                    .font(Theme.caption(14, weight: .semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.ink3)
                    .opacity(reveal)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .task {
            withAnimation(.easeOut(duration: 1.0)) { reveal = 1 }
            withAnimation(.easeOut(duration: 1.4)) { ring = 1 }
            try? await Task.sleep(for: .milliseconds(1700))
            onFinish()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CatDex Maison")
    }
}
