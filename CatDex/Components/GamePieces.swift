import SwiftUI

// MARK: - HUD

/// The patron's heads-up display: level ring, purse, streak.
struct PatronHUD: View {
    @Environment(Game.self) private var game
    @Environment(Router.self) private var router

    var body: some View {
        HStack(spacing: 8) {
            Button { router.tab = .patron } label: {
                HStack(spacing: 8) {
                    LevelRing(level: game.level, progress: game.levelProgress, size: 34)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(game.title)
                            .font(Theme.title(13))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text("\(game.xpIntoLevel)/\(game.xpForLevel) XP")
                            .font(Theme.number(10, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                            .contentTransition(.numericText())
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Level \(game.level), \(game.title)")

            Spacer(minLength: 4)

            if game.streak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xF5B36B), Color(hex: 0xE0705A)], startPoint: .top, endPoint: .bottom))
                    Text("\(game.streak)")
                        .font(Theme.number(13))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().stroke(Theme.hairline, lineWidth: 0.5))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(game.streak) day streak")
            }

            CoinAmount(value: game.ledger.guineas, size: 13)
                .padding(.leading, 6)
                .padding(.trailing, 10)
                .frame(height: 30)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().stroke(Theme.hairline, lineWidth: 0.5))
                .animation(.snappy, value: game.ledger.guineas)
        }
    }
}

/// A circular XP ring with the level number inside.
struct LevelRing: View {
    let level: Int
    let progress: Double
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle().fill(Theme.surface)
            Circle().stroke(Theme.roseLight.opacity(0.6), lineWidth: size * 0.1)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(Theme.roseGold, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.8), value: progress)
            Text("\(level)")
                .font(Theme.number(size * 0.42, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(level)))
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.rose.opacity(0.25), radius: 4, y: 2)
    }
}

/// A thin progress bar.
struct ProgressBar: View {
    let value: Double
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.roseGold)
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceSunk)
                Capsule().fill(tint)
                    .frame(width: max(height, proxy.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.7), value: value)
    }
}

// MARK: - Rewards

/// Reward chips that float in at the top and fade after a moment.
struct RewardToasts: View {
    @Environment(Game.self) private var game

    var body: some View {
        VStack(spacing: 6) {
            ForEach(game.toasts) { reward in
                RewardChip(reward: reward)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                    .task {
                        try? await Task.sleep(for: .seconds(2.4))
                        game.dismissToast(reward)
                    }
            }
        }
        .padding(.top, 4)
        .allowsHitTesting(false)
    }
}

struct RewardChip: View {
    let reward: Reward

    var body: some View {
        HStack(spacing: 10) {
            Text(reward.title)
                .font(Theme.title(13))
                .foregroundStyle(Theme.ink)
            if reward.guineas != 0 {
                CoinAmount(value: reward.guineas, size: 12, signed: true)
            }
            if reward.xp != 0 {
                Text("+\(reward.xp) XP")
                    .font(Theme.number(12, weight: .heavy))
                    .foregroundStyle(Theme.roseDeep)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .maisonGlass(in: Capsule())
        .shadow(color: Color(hex: 0x8A5A50, alpha: 0.18), radius: 10, y: 4)
        .sensoryFeedback(.success, trigger: reward.id)
    }
}

/// The level-up celebration card.
struct LevelUpCard: View {
    let levelUp: LevelUp
    var dismiss: () -> Void
    @State private var shown = false
    @State private var leaf = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
                .onTapGesture(perform: dismiss)
            VStack(spacing: 12) {
                Text("Level up")
                    .font(Theme.caption(13, weight: .semibold))
                    .foregroundStyle(Theme.roseDeep)
                LevelRing(level: levelUp.level, progress: 1, size: 86)
                    .scaleEffect(shown ? 1 : 0.4)
                Text(levelUp.title)
                    .font(Theme.display(24))
                    .tracking(Theme.displayTracking)
                    .foregroundStyle(Theme.ink)
                ForEach(levelUp.unlocks, id: \.self) { unlock in
                    Label(unlock, systemImage: "lock.open.fill")
                        .font(Theme.body(14, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                }
                Button("Splendid", action: dismiss)
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 300)
            .pearlCard(28, padding: nil)
            .scaleEffect(shown ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
            GoldLeafBurst(trigger: leaf, count: 60, tint: .noir)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.35)) { shown = true }
            leaf += 1
        }
        .sensoryFeedback(.success, trigger: shown)
    }
}

// MARK: - Rival cats

/// A rival's cat as a coat-coloured bust in a medallion.
struct CatBust: View {
    let coat: [Color]
    var marque: Marque = .ivory
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Theme.pearl, Theme.blush], startPoint: .top, endPoint: .bottom))
            CatHeadShape()
                .fill(LinearGradient(colors: [coat.first ?? Theme.ink3, coat.dropFirst().first ?? coat.first ?? Theme.ink3],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(size * 0.16)
                .offset(y: size * 0.04)
            CatEyes()
                .fill(Color(hex: 0x2A2430, alpha: 0.75))
                .padding(size * 0.16)
                .offset(y: size * 0.04)
            Circle().stroke(marque.metal, lineWidth: max(1.5, size * 0.05))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: Color(hex: 0x8A5A50, alpha: 0.18), radius: 5, y: 3)
        .accessibilityHidden(true)
    }
}

/// Head and ears, in unit space.
struct CatHeadShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.addEllipse(in: CGRect(x: r.minX + w * 0.1, y: r.minY + h * 0.3, width: w * 0.8, height: h * 0.62))
        p.move(to: CGPoint(x: r.minX + w * 0.14, y: r.minY + h * 0.55))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.22, y: r.minY + h * 0.06), control: CGPoint(x: r.minX + w * 0.1, y: r.minY + h * 0.15))
        p.addLine(to: CGPoint(x: r.minX + w * 0.44, y: r.minY + h * 0.34))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.minX + w * 0.56, y: r.minY + h * 0.34))
        p.addLine(to: CGPoint(x: r.minX + w * 0.78, y: r.minY + h * 0.06))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.86, y: r.minY + h * 0.55), control: CGPoint(x: r.minX + w * 0.9, y: r.minY + h * 0.15))
        p.closeSubpath()
        return p
    }
}

/// Two calm closed-eye arcs and a nose.
struct CatEyes: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        for cx in [0.36, 0.64] {
            let x = r.minX + w * cx, y = r.minY + h * 0.6
            p.move(to: CGPoint(x: x - w * 0.08, y: y))
            p.addQuadCurve(to: CGPoint(x: x + w * 0.08, y: y), control: CGPoint(x: x, y: y + h * 0.06))
            p.addQuadCurve(to: CGPoint(x: x - w * 0.08, y: y), control: CGPoint(x: x, y: y + h * 0.035))
        }
        p.move(to: CGPoint(x: r.minX + w * 0.47, y: r.minY + h * 0.7))
        p.addLine(to: CGPoint(x: r.minX + w * 0.53, y: r.minY + h * 0.7))
        p.addLine(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.74))
        p.closeSubpath()
        return p
    }
}

// MARK: - Rosette

/// A prize rosette: pleated ring, centre button and two ribbon tails.
struct Rosette: View {
    var tier: ShowTier
    var size: CGFloat = 120
    var label: String = "1st"

    var body: some View {
        ZStack {
            // Tails.
            HStack(spacing: size * 0.04) {
                RibbonTail().fill(LinearGradient(colors: [tier.ribbon, tier.ribbonDeep], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.26, height: size * 0.62)
                    .rotationEffect(.degrees(12), anchor: .top)
                RibbonTail().fill(LinearGradient(colors: [tier.ribbon, tier.ribbonDeep], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.26, height: size * 0.62)
                    .rotationEffect(.degrees(-12), anchor: .top)
            }
            .offset(y: size * 0.42)
            // Pleats.
            PleatRing(points: 28)
                .fill(LinearGradient(colors: [tier.ribbon, tier.ribbonDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            PleatRing(points: 22)
                .fill(Color.white.opacity(0.35))
                .frame(width: size * 0.78, height: size * 0.78)
            Circle()
                .fill(Theme.roseGold)
                .frame(width: size * 0.52, height: size * 0.52)
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2).padding(size * 0.03))
            Text(label)
                .font(.system(size: size * 0.17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size * 1.3, alignment: .top)
        .shadow(color: tier.ribbonDeep.opacity(0.35), radius: 10, y: 6)
        .accessibilityHidden(true)
    }
}

struct PleatRing: Shape {
    var points: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0...(points * 2) {
            let a = Double(i) / Double(points * 2) * .pi * 2
            let rr = i % 2 == 0 ? r : r * 0.86
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

struct RibbonTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.width * 0.45))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
