import Foundation

import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

let curatorLog = Logger(subsystem: "com.marklumbay.catdex.maison", category: "Curator")

/// A live view of the dossier while it's being written.
struct DossierDraft: Equatable {
    var name: String?
    var epithet: String?
    var motto: String?
    var mottoTranslation: String?
    var signatureTrait: String?
    var curatorNote: String?
    var provenance: String?
    /// Being written by Apple Intelligence (vs. the house writer).
    var isAppleIntelligence = false
}

/// The curator: Apple Intelligence on device when available, the house writer otherwise.
enum Curator {

    static var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Writes the dossier, streaming partial drafts to `onDraft`. Falls back to
    /// the house writer on any unavailability, error or timeout.
    static func compose(
        _ brief: CuratorBrief,
        onDraft: @escaping @MainActor (DossierDraft) -> Void
    ) async -> (dossier: Dossier, aiAuthored: Bool) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAppleIntelligenceAvailable {
            if let dossier = await AppleIntelligenceCurator.compose(brief, onDraft: onDraft) {
                return (dossier, true)
            }
        }
        #endif
        let dossier = HouseCurator.write(brief)
        await typeOut(dossier, onDraft: onDraft)
        return (dossier, false)
    }

    /// The house writer still "writes" — streamed out word by word so the
    /// ceremony feels the same with or without Apple Intelligence.
    @MainActor
    private static func typeOut(_ dossier: Dossier, onDraft: @MainActor (DossierDraft) -> Void) async {
        var draft = DossierDraft(
            name: dossier.name, epithet: dossier.epithet, motto: dossier.motto,
            mottoTranslation: dossier.mottoTranslation, signatureTrait: dossier.signatureTrait,
            curatorNote: "", provenance: nil
        )
        let words = dossier.curatorNote.split(separator: " ")
        for (i, word) in words.enumerated() {
            draft.curatorNote = words[0...i].joined(separator: " ")
            onDraft(draft)
            try? await Task.sleep(for: .milliseconds(word.count > 6 ? 70 : 45))
        }
        draft.provenance = dossier.provenance
        onDraft(draft)
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
enum AppleIntelligenceCurator {

    @Generable
    struct Entry {
        @Guide(description: "The cat's given name, elegant and a little whimsical, e.g. 'Clementine' or 'Bartholomew'. One or two words. May include a noble title suited to its rarity tier, like 'Lady' or 'Count'.")
        var name: String
        @Guide(description: "An epithet that follows the name, like 'the Unbothered' or 'Keeper of the Mantelpiece'. 2 to 5 words.")
        var epithet: String
        @Guide(description: "A short family motto in playful Latin, 2 to 5 words, e.g. 'Somnus ante omnia'.")
        var motto: String
        @Guide(description: "The English translation of the motto, under 8 words.")
        var mottoTranslation: String
        @Guide(description: "One elegant adjective that sums up the cat, capitalised, e.g. 'Imperious'.")
        var signatureTrait: String
        @Guide(description: "A museum curator's note about this cat: two or three refined, witty sentences, 30 to 55 words total, in the voice of a luxury auction catalogue. Mention its coat colours and the setting.")
        var curatorNote: String
        @Guide(description: "One short provenance line in auction-catalogue style, e.g. 'Acquired in the drawing room at golden hour, by private arrangement.'")
        var provenance: String
    }

    static func compose(
        _ brief: CuratorBrief,
        onDraft: @escaping @MainActor (DossierDraft) -> Void,
        timeout: Duration = .seconds(14)
    ) async -> Dossier? {
        let session = LanguageModelSession(instructions: """
            You are the head curator of Maison CatDex, a private collection of extraordinary cats. \
            You write catalogue entries with the poise of a fine-art auction house — refined, witty, \
            affectionate, never crude. Everything is family-friendly.
            """)

        let colours = brief.palette.map(\.name).joined(separator: ", ")
        let traits = brief.temperament.ranked.prefix(2).map { "\($0.displayName.lowercased()) \(brief.temperament[$0])/100" }
        let prompt = """
            A new cat has been acquired for the collection. Write its catalogue entry.
            Rarity tier (marque): \(brief.marque.displayName) — rarer marques deserve grander titles and loftier prose.
            Coat colours: \(colours).
            Setting where it was found: \(brief.setting).
            Time of day: \(brief.hour).
            Strongest temperament traits: \(traits.joined(separator: ", ")).
            """

        let work = Task { @MainActor () async throws -> Dossier? in
            let stream = session.streamResponse(to: prompt, generating: Entry.self)
            var last: Entry.PartiallyGenerated?
            for try await snapshot in stream {
                let partial = snapshot.content
                last = partial
                onDraft(DossierDraft(
                    name: partial.name, epithet: partial.epithet, motto: partial.motto,
                    mottoTranslation: partial.mottoTranslation, signatureTrait: partial.signatureTrait,
                    curatorNote: partial.curatorNote, provenance: partial.provenance,
                    isAppleIntelligence: true
                ))
            }
            guard let last,
                  let name = last.name?.trimmed, !name.isEmpty,
                  let note = last.curatorNote?.trimmed, !note.isEmpty
            else { return nil }
            let fallback = HouseCurator.write(brief)
            return Dossier(
                name: name,
                epithet: last.epithet?.trimmed.nonEmpty ?? fallback.epithet,
                motto: last.motto?.trimmed.nonEmpty ?? fallback.motto,
                mottoTranslation: last.mottoTranslation?.trimmed.nonEmpty ?? fallback.mottoTranslation,
                signatureTrait: last.signatureTrait?.trimmed.nonEmpty ?? fallback.signatureTrait,
                curatorNote: note,
                provenance: last.provenance?.trimmed.nonEmpty ?? fallback.provenance
            )
        }
        let watchdog = Task {
            try? await Task.sleep(for: timeout)
            work.cancel()
        }
        defer { watchdog.cancel() }
        do {
            return try await work.value
        } catch {
            curatorLog.error("Apple Intelligence curator failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
#endif

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"“”")) }
    var nonEmpty: String? { isEmpty ? nil : self }
}
