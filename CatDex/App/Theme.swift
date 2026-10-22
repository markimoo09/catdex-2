import SwiftUI

/// Pearl design tokens — pearl and blush grounds, plum ink, rose-gold accents, SF Pro.
enum Theme {
    // MARK: Grounds
    static let pearl = Color(hex: 0xFBF7F2)
    static let blush = Color(hex: 0xF8E6DE)
    static let lilac = Color(hex: 0xEEE8F6)
    static let champagne = Color(hex: 0xF6ECDD)
    static let surface = Color.white
    static let surfaceSunk = Color(hex: 0xF4EEE8)

    // MARK: Ink
    static let ink = Color(hex: 0x2A2430)
    static let ink2 = Color(hex: 0x6E6370)
    static let ink3 = Color(hex: 0xA59AA2)
    static let hairline = Color(hex: 0x2A2430, alpha: 0.08)

    // MARK: Accents
    static let rose = Color(hex: 0xD4927E)
    static let roseDeep = Color(hex: 0xB0705D)
    static let roseLight = Color(hex: 0xF4D5C7)
    static let coin = Color(hex: 0xE3B355)
    static let coinDeep = Color(hex: 0xB9842B)
    static let win = Color(hex: 0x6FA584)
    static let loss = Color(hex: 0xCF6E68)

    // MARK: Paper (certificate)
    static let paper = Color(hex: 0xFBF6EC)
    static let paperShade = Color(hex: 0xEEE3D0)

    static let roseGold = LinearGradient(
        colors: [Color(hex: 0xF3CDBC), Color(hex: 0xD9967F), Color(hex: 0xC27F6A)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let coinGradient = LinearGradient(
        colors: [Color(hex: 0xF7DE9C), coin, coinDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// The app's ground: pearl washing into blush and lilac.
    static let ground = LinearGradient(
        colors: [pearl, Color(hex: 0xFAEEE8), Color(hex: 0xF1ECF7)],
        startPoint: .top, endPoint: .bottom
    )

    // MARK: Type (SF Pro throughout)
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static func caption(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight) }
    /// Rounded figures for the game layer — coins, levels, scores.
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
    /// The curator's signature on certificates.
    static func signature(_ size: CGFloat) -> Font { .custom("SnellRoundhand-Bold", size: size) }

    static let displayTracking: CGFloat = -0.5
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

// MARK: - Surfaces

extension View {
    /// A white card with a soft rose-tinted shadow.
    func pearlCard(_ radius: CGFloat = 18, padding: CGFloat? = 14) -> some View {
        self
            .padding(padding ?? 0)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.hairline, lineWidth: 0.5))
            .shadow(color: Color(hex: 0x8A5A50, alpha: 0.10), radius: 14, y: 6)
    }

    /// iOS 26 Liquid Glass; a frosted white material before that.
    @ViewBuilder
    func maisonGlass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(Self.glass(tint: tint), in: shape)
        } else {
            self
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(Color.white.opacity(0.55))
                        if let tint { shape.fill(tint.opacity(0.15)) }
                    }
                }
                .overlay(shape.stroke(Color.white.opacity(0.9), lineWidth: 0.5))
        }
    }

    @available(iOS 26.0, *)
    private static func glass(tint: Color?) -> Glass {
        tint.map { Glass.regular.tint($0.opacity(0.3)) } ?? .regular
    }
}

// MARK: - Text pieces

/// Section heading with an optional trailing note.
struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.title(17))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.caption(12))
                    .foregroundStyle(Theme.ink3)
            }
        }
    }
}

/// A small rounded tag.
struct Pill: View {
    let text: String
    var fill: Color = Theme.blush
    var ink: Color = Theme.roseDeep
    var symbol: String?

    var body: some View {
        HStack(spacing: 3) {
            if let symbol { Image(systemName: symbol).font(.system(size: 9, weight: .bold)) }
            Text(text)
        }
        .font(Theme.caption(10.5, weight: .semibold))
        .foregroundStyle(ink)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(fill))
    }
}

/// Guineas with the coin glyph.
struct CoinAmount: View {
    let value: Int
    var size: CGFloat = 14
    var signed = false

    var body: some View {
        HStack(spacing: 4) {
            CoinGlyph(size: size * 1.05)
            Text("\(signed && value > 0 ? "+" : "")\(value.formatted())")
                .font(Theme.number(size))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(value)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) guineas")
    }
}

struct CoinGlyph: View {
    var size: CGFloat = 14
    var body: some View {
        ZStack {
            Circle().fill(Theme.coinGradient)
            Circle().stroke(Theme.coinDeep.opacity(0.5), lineWidth: max(0.5, size * 0.06)).padding(size * 0.14)
            Text("G")
                .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.coinDeep)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// Primary call to action: rose-gold capsule.
struct PrimaryButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.title(compact ? 14 : 16))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 16 : 22)
            .frame(minHeight: compact ? 38 : 48)
            .background(Capsule().fill(Theme.roseGold))
            .shadow(color: Theme.rose.opacity(configuration.isPressed ? 0.15 : 0.4), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Secondary: white capsule with a hairline.
struct SecondaryButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.title(compact ? 14 : 16))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, compact ? 16 : 22)
            .frame(minHeight: compact ? 38 : 48)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            .shadow(color: Color(hex: 0x8A5A50, alpha: 0.08), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Round glass icon button for chrome (close, more, share).
struct GlassIconButton: View {
    let systemName: String
    var label: String
    var dark = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(dark ? .white : Theme.ink)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(dark ? 0 : 0.7)))
                .maisonGlass(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
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

    static func compact(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }

    static func estimate(_ value: Int) -> String {
        let low = Int((Double(value) * 0.8 / 100).rounded()) * 100
        let high = Int((Double(value) * 1.2 / 100).rounded()) * 100
        return "\(low.formatted()) – \(high.formatted()) gns"
    }

    static let longDate: Date.FormatStyle = .dateTime.day().month(.wide).year()
    static let shortDate: Date.FormatStyle = .dateTime.day().month(.abbreviated)
}
