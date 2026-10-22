import UIKit
import Vision

/// What Vision could say about whether the subject is a cat.
enum CatVerdict: Equatable {
    case cat(confidence: Double)
    case notCat
    /// The recogniser could not run (e.g. the Simulator lacks the model).
    case unverified

    var confidence: Double? {
        if case .cat(let c) = self { return c }
        return nil
    }
}

/// On-device perception: is it a cat, and where was it found?
enum Perception {

    static func verifyCat(in image: UIImage) async -> CatVerdict {
        #if targetEnvironment(simulator)
        // The Simulator ships without the animal recogniser; an empty answer
        // there means "couldn't look", not "no cat".
        return .unverified
        #else
        guard let cg = image.cgImage else { return .unverified }
        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try await Task.detached(priority: .userInitiated) { try handler.perform([request]) }.value
        } catch {
            return .unverified
        }
        guard let results = request.results else { return .unverified }
        let best = results
            .flatMap(\.labels)
            .filter { $0.identifier == VNAnimalIdentifier.cat.rawValue }
            .map(\.confidence)
            .max()
        if let best, best >= 0.3 { return .cat(confidence: Double(best)) }
        return .notCat
        #endif
    }

    /// Reads the scene into a salon-style setting name.
    static func setting(of image: UIImage) async -> String? {
        guard let cg = image.cgImage else { return nil }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try await Task.detached(priority: .userInitiated) { try handler.perform([request]) }.value
        } catch {
            return nil
        }
        let labels = (request.results ?? [])
            .filter { $0.confidence > 0.12 }
            .sorted { $0.confidence > $1.confidence }
            .map(\.identifier)
        return SettingLexicon.setting(for: labels)
    }
}

/// Maps Vision's scene taxonomy to the house's vocabulary of rooms and grounds.
enum SettingLexicon {
    private static let table: [(keys: [String], setting: String)] = [
        (["sofa", "couch", "living_room", "cushion", "pillow"], "Drawing Room"),
        (["bed", "bedroom", "blanket", "quilt", "bedding"], "Boudoir"),
        (["window", "windowsill", "curtain", "blinds"], "Window Seat"),
        (["kitchen", "countertop", "refrigerator", "stove", "food"], "Scullery"),
        (["desk", "computer", "keyboard", "laptop", "office", "book", "bookshelf"], "Library"),
        (["box", "cardboard", "carton", "package"], "Packing Room"),
        (["car", "vehicle", "automobile"], "Motor House"),
        (["snow", "winter", "ice"], "Winter Garden"),
        (["flower", "garden", "grass", "plant", "lawn", "tree", "foliage", "shrub"], "Garden"),
        (["street", "sidewalk", "road", "building", "urban", "alley"], "Boulevard"),
        (["beach", "sand", "sea", "ocean", "water"], "Riviera"),
        (["stairs", "staircase", "hallway", "door"], "Grand Staircase"),
        (["table", "chair", "dining_room", "furniture"], "Dining Hall"),
        (["bathroom", "bathtub", "sink", "toilet"], "Bath House"),
        (["sky", "roof", "rooftop"], "Rooftop"),
        (["painting", "illustrations", "art", "drawing", "cartoon"], "Atelier"),
    ]

    static func setting(for labels: [String]) -> String? {
        for label in labels {
            let lower = label.lowercased()
            if let hit = table.first(where: { $0.keys.contains { lower.contains($0) } }) {
                return hit.setting
            }
        }
        return nil
    }

    static let fallbacks = ["Private Residence", "Drawing Room", "Garden", "Window Seat", "Library"]
}

/// The hour of acquisition, named the way a photographer or sommelier might.
enum HourLexicon {
    static func label(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5: return "Blue Hour"
        case 6, 7: return "Golden Hour"
        case 8...11: return "Morning"
        case 12, 13: return "Noon"
        case 14...16: return "Afternoon"
        case 17, 18: return "Golden Hour"
        case 19: return "Blue Hour"
        case 20, 21: return "Evening"
        default: return "Nocturne"
        }
    }

    static func isNocturne(_ date: Date, calendar: Calendar = .current) -> Bool {
        label(for: date, calendar: calendar) == "Nocturne"
    }

    static func isGoldenHour(_ date: Date, calendar: Calendar = .current) -> Bool {
        label(for: date, calendar: calendar) == "Golden Hour"
    }
}
