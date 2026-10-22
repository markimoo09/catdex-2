import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// The persona a cat speaks with during an audience.
struct Persona {
    var name: String
    var epithet: String
    var marque: Marque
    var temperament: Temperament
    var motto: String
    var mottoTranslation: String
    var setting: String
    var palette: [String]
    var seed: UInt64
}

extension Persona {
    init(_ acquisition: Acquisition) {
        name = acquisition.name
        epithet = acquisition.epithet
        marque = acquisition.marque
        temperament = acquisition.temperament
        motto = acquisition.motto
        mottoTranslation = acquisition.mottoTranslation
        setting = acquisition.setting
        palette = acquisition.palette.map(\.name)
        seed = UInt64(truncatingIfNeeded: acquisition.id.hashValue)
    }
}

/// Converse with a cat in character. Streams cumulative reply text.
@MainActor
final class AudienceVoice {
    private let persona: Persona
    private var houseTurn = 0

    #if canImport(FoundationModels)
    private var sessionStorage: Any?
    #endif

    init(persona: Persona, history: [Letter]) {
        self.persona = persona
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), Curator.isAppleIntelligenceAvailable {
            sessionStorage = Self.makeSession(persona: persona, history: history)
        }
        #endif
    }

    var isAppleIntelligence: Bool {
        #if canImport(FoundationModels)
        return sessionStorage != nil
        #else
        return false
        #endif
    }

    func reply(to message: String, onText: @escaping @MainActor (String) -> Void) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let session = sessionStorage as? LanguageModelSession {
            do {
                var latest = ""
                for try await snapshot in session.streamResponse(to: message) {
                    latest = snapshot.content
                    onText(latest)
                }
                if !latest.trimmed.isEmpty { return latest }
            } catch {
                // Guardrail or context errors fall through to the house voice.
            }
        }
        #endif
        let text = HouseVoice.reply(to: message, persona: persona, turn: houseTurn)
        houseTurn += 1
        var shown = ""
        for word in text.split(separator: " ") {
            shown += (shown.isEmpty ? "" : " ") + word
            onText(shown)
            try? await Task.sleep(for: .milliseconds(55))
        }
        return text
    }

    func greeting() -> String { HouseVoice.greeting(persona) }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func makeSession(persona: Persona, history: [Letter]) -> LanguageModelSession {
        let traits = persona.temperament.ranked.prefix(3).map { $0.displayName.lowercased() }.joined(separator: ", ")
        let recent = history.suffix(6).map { "\($0.author == .cat ? persona.name : "Patron"): \($0.text)" }
            .joined(separator: "\n")
        return LanguageModelSession(instructions: """
            You are \(persona.name), \(persona.epithet) — a cat of the \(persona.marque.displayName) marque in \
            the private collection of Maison CatDex. Your coat is \(persona.palette.prefix(2).joined(separator: " and ")). \
            You were found in the \(persona.setting.lowercased()). Your strongest traits: \(traits). \
            Your family motto is "\(persona.motto)" (\(persona.mottoTranslation)).
            Speak in first person as this cat: aristocratic, witty, a little aloof, secretly affectionate. \
            Reply in one to three short sentences. Never break character, never mention being an AI, \
            and keep everything family-friendly.
            \(recent.isEmpty ? "" : "Recent correspondence:\n\(recent)")
            """)
    }
    #endif
}

/// The house voice: keyword-aware, in-character replies without a language model.
enum HouseVoice {

    static func greeting(_ p: Persona) -> String {
        switch p.temperament.dominant {
        case .poise: return "You may approach. Slowly, if you please."
        case .charm: return "Ah — you came. I knew you would."
        case .mischief: return "You're late. I've already knocked something over in protest."
        case .languor: return "Mm. You've interrupted a perfectly good nap. Speak softly."
        case .curiosity: return "What have you brought? Show me. Is it a box?"
        }
    }

    static func reply(to message: String, persona p: Persona, turn: Int) -> String {
        let text = message.lowercased()
        var rng = SeededRandom(seed: p.seed &+ UInt64(turn) &* 0x9E37 &+ UInt64(text.count))

        for topic in topics where topic.keys.contains(where: { text.contains($0) }) {
            return fill(rng.pick(topic.replies), p)
        }
        if text.contains("?") {
            return fill(rng.pick(questions), p)
        }
        return fill(rng.pick(moods[p.temperament.dominant] ?? moods[.poise]!), p)
    }

    private static func fill(_ template: String, _ p: Persona) -> String {
        template
            .replacingOccurrences(of: "{name}", with: p.name)
            .replacingOccurrences(of: "{epithet}", with: p.epithet)
            .replacingOccurrences(of: "{motto}", with: p.motto)
            .replacingOccurrences(of: "{translation}", with: p.mottoTranslation.lowercased())
            .replacingOccurrences(of: "{setting}", with: p.setting.lowercased())
            .replacingOccurrences(of: "{coat}", with: (p.palette.first ?? "graphite").lowercased())
            .replacingOccurrences(of: "{marque}", with: p.marque.displayName)
    }

    private static let topics: [(keys: [String], replies: [String])] = [
        (["food", "treat", "hungry", "eat", "dinner", "supper", "fish", "tuna", "snack", "breakfast"], [
            "One does not *ask* about supper. One simply expects it, promptly, at six.",
            "Salmon. Lightly poached. I shan't repeat myself.",
            "I have been fed — technically. Spiritually, I am famished.",
        ]),
        (["love", "cute", "pretty", "beautiful", "adore", "gorgeous", "handsome", "sweet"], [
            "Naturally. Do go on.",
            "I am aware. It is exhausting, being this {coat}.",
            "Flattery is accepted. Chin scratches are preferred.",
        ]),
        (["sleep", "nap", "tired", "bed", "rest"], [
            "Sleep is not idleness. It is curation of the self.",
            "The sunbeam moves at four. I must be there when it does.",
            "I nap sixteen hours a day. The other eight are recovery.",
        ]),
        (["play", "toy", "mouse", "laser", "string", "ball", "game"], [
            "The red dot is a matter I'd rather not discuss.",
            "I play only when no one is looking. Look away.",
            "Toys are for kittens. Now — dangle it again.",
        ]),
        (["hello", "hi ", "hey", "good morning", "good evening", "bonjour"], [
            "Good day. You may proceed with the admiration.",
            "Ah. A visitor. How novel.",
            "Bonjour. Mind the cushion — it's mine.",
        ]),
        (["name", "who are you", "yourself"], [
            "I am {name}, {epithet}. You may use the full title.",
            "{name}. Of the {marque} marque. Our motto: {motto} — {translation}.",
        ]),
        (["motto", "latin"], [
            "{motto}. It means {translation}. We live by it.",
        ]),
        (["box", "bag", "cupboard", "drawer"], [
            "If it fits, it is mine. If it does not fit, I shall make it fit.",
            "A box is not a container. It is a throne awaiting its monarch.",
        ]),
        (["dog", "puppy"], [
            "We do not speak of the hound.",
            "Dogs are enthusiasts. I am a connoisseur.",
        ]),
        (["sorry", "apolog"], [
            "Forgiven. Provisionally. Treats would make it permanent.",
        ]),
        (["where", "home", "found"], [
            "I was found in the {setting}. Or rather — I allowed myself to be found.",
        ]),
    ]

    private static let questions = [
        "A question. How bold. The answer, as ever, is: it depends on supper.",
        "I could tell you, but then I'd have to sit on you.",
        "Some mysteries are best left beneath the sofa.",
        "Ask me again after my nap.",
    ]

    private static let moods: [Temperament.Trait: [String]] = [
        .poise: [
            "Hm. Noted, and filed.",
            "Composure, darling. Always composure.",
            "I shall consider it from the mantelpiece.",
        ],
        .charm: [
            "You say the loveliest things. Mostly about me.",
            "Come closer. No — not that close. There. Perfect.",
            "I'll allow it, because it's you.",
        ],
        .mischief: [
            "Interesting. And what if I pushed it off the table?",
            "I make no promises regarding the curtains.",
            "Mischief? Me? I'm a {marque} cat. Allegedly.",
        ],
        .languor: [
            "Mm. Wake me when it's interesting.",
            "Tell me again, but slower. I'm horizontal.",
            "That sounds like effort. Pass.",
        ],
        .curiosity: [
            "Fascinating. Where is it now? Can I see it?",
            "And what's behind that? And behind that?",
            "I must investigate this personally.",
        ],
    ]
}
