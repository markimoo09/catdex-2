import SwiftUI

/// One colour read from a cat's coat, with its couture name.
struct Swatch: Codable, Hashable, Identifiable {
    var name: String
    var red: Double
    var green: Double
    var blue: Double
    /// Share of the coat this colour covers, 0...1.
    var share: Double

    var id: String { "\(name)-\(hex)" }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    var hex: String {
        String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    var saturation: Double {
        let maxC = max(red, green, blue), minC = min(red, green, blue)
        return maxC == 0 ? 0 : (maxC - minC) / maxC
    }

    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    /// A deepened version for backdrops (keeps hue, drops brightness).
    func deepened(_ amount: Double) -> Color {
        Color(.sRGB, red: red * (1 - amount), green: green * (1 - amount), blue: blue * (1 - amount))
    }

    static func encode(_ swatches: [Swatch]) -> Data {
        (try? JSONEncoder().encode(swatches)) ?? Data()
    }

    static func decode(_ data: Data) -> [Swatch] {
        (try? JSONDecoder().decode([Swatch].self, from: data)) ?? []
    }

    /// Neutral fallback palette (charcoal & champagne).
    static let houseDefault: [Swatch] = [
        Swatch(name: "Graphite", red: 0.27, green: 0.27, blue: 0.28, share: 0.4),
        Swatch(name: "Champagne", red: 0.89, green: 0.82, blue: 0.69, share: 0.3),
        Swatch(name: "Mink", red: 0.49, green: 0.39, blue: 0.33, share: 0.2),
        Swatch(name: "Pearl", red: 0.9, green: 0.88, blue: 0.84, share: 0.1),
    ]
}

extension Array where Element == Swatch {
    /// Predominantly black, white and grey.
    var isMonochrome: Bool {
        guard !isEmpty else { return false }
        let weighted = reduce(0.0) { $0 + $1.saturation * $1.share } / Swift.max(0.0001, reduce(0.0) { $0 + $1.share })
        return weighted < 0.16
    }
}
