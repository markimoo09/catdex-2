import SwiftUI

/// Maison design tokens — noir chrome, champagne-gold hairlines, ivory type.
enum Theme {
    // MARK: Chrome
    static let ink = Color(hex: 0x0A0A0B)
    static let onyx = Color(hex: 0x121214)
    static let graphite = Color(hex: 0x1B1B1E)
    static let smoke = Color(hex: 0x2A2A2E)
    static let hairline = Color.white.opacity(0.10)

    // MARK: Type colours
    static let ivory = Color(hex: 0xF3EEE4)
    static let parchment = Color(hex: 0xC9C2B6)
    static let mute = Color(hex: 0x8A847A)

    // MARK: Metals
    static let champagne = Color(hex: 0xD9C29A)
    static let gold = Color(hex: 0xC9A45C)
    static let goldDeep = Color(hex: 0x8C6A2F)
    static let goldLight = Color(hex: 0xF3E4C0)

    // MARK: Paper (certificate)
    static let paper = Color(hex: 0xF4EFE4)
    static let paperShade = Color(hex: 0xE6DECD)
    static let inkOnPaper = Color(hex: 0x1D1A16)

    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, goldDeep, gold, goldLight],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let goldSheen = LinearGradient(
        colors: [goldLight, champagne, gold],
        startPoint: .top, endPoint: .bottom
    )

    // MARK: Type
    /// Didot — high-contrast fashion display face.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Didot", size: size, relativeTo: style)
    }

    static func displayItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("Didot-Italic", size: size, relativeTo: style)
    }

    /// New York — book serif for prose.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func serifItalic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif).italic()
    }

    /// Tracked small-caps labels. Pair with `.tracking(Theme.labelTracking)`.
    static func label(_ size: CGFloat = 10, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let labelTracking: CGFloat = 2.4

    /// Curator's hand.
    static func script(_ size: CGFloat) -> Font {
        .custom("SnellRoundhand-Bold", size: size)
    }

    static func numerals(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif).monospacedDigit()
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Small caps label

struct SmallCaps: View {
    let text: String
    var size: CGFloat = 10
    var color: Color = Theme.mute
    var tracking: CGFloat = Theme.labelTracking

    init(_ text: String, size: CGFloat = 10, color: Color = Theme.mute, tracking: CGFloat = Theme.labelTracking) {
        self.text = text
        self.size = size
        self.color = color
        self.tracking = tracking
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(size))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

// MARK: - Hairline rule with a lozenge

struct OrnamentRule: View {
    var color: Color = Theme.champagne.opacity(0.5)
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(color).frame(height: 0.5)
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(color)
            Rectangle().fill(color).frame(height: 0.5)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Liquid Glass with a material fallback

extension View {
    /// iOS 26 Liquid Glass; ultra-thin material with a hairline on earlier systems.
    @ViewBuilder
    func maisonGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(Self.glass(tint: tint, interactive: interactive), in: shape)
        } else {
            self
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if let tint { shape.fill(tint.opacity(0.18)) }
                    }
                }
                .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 0.5))
        }
    }

    @available(iOS 26.0, *)
    private static func glass(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint.opacity(0.35)) }
        if interactive { glass = glass.interactive() }
        return glass
    }

    /// A faint film-grain texture over a surface.
    func filmGrain(_ amount: Double = 0.05) -> some View {
        overlay {
            Rectangle()
                .fill(.white)
                .colorEffect(ShaderLibrary.grain(.float(Float(amount))))
                .blendMode(.overlay)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Buttons

/// Primary call to action: champagne-gold lozenge.
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(12, weight: .bold))
            .tracking(2.6)
            .textCase(.uppercase)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 28)
            .frame(minHeight: 52)
            .background(Capsule().fill(Theme.goldGradient))
            .overlay(Capsule().stroke(Theme.goldLight.opacity(0.7), lineWidth: 0.5))
            .shadow(color: Theme.gold.opacity(configuration.isPressed ? 0.15 : 0.35), radius: 18, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Secondary: hairline capsule.
struct HairlineButtonStyle: ButtonStyle {
    var color: Color = Theme.champagne
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(11, weight: .semibold))
            .tracking(2.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.horizontal, 22)
            .frame(minHeight: 46)
            .background(Capsule().stroke(color.opacity(0.55), lineWidth: 0.75))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Round glass icon button for chrome (close, more, share).
struct GlassIconButton: View {
    let systemName: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ivory)
                .frame(width: 44, height: 44)
                .maisonGlass(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Formatting

enum Format {
    static func guineas(_ value: Int) -> String {
        "\(value.formatted(.number.grouping(.automatic))) gns"
    }

    static func lot(_ number: Int) -> String {
        String(format: "Lot %03d", number)
    }

    static func estimate(_ value: Int) -> String {
        let low = Int((Double(value) * 0.8 / 100).rounded()) * 100
        let high = Int((Double(value) * 1.2 / 100).rounded()) * 100
        return "\(low.formatted()) – \(high.formatted()) gns"
    }

    static let longDate: Date.FormatStyle = .dateTime.day().month(.wide).year()
    static let editorialDate: Date.FormatStyle = .dateTime.weekday(.wide).day().month(.wide)
}
